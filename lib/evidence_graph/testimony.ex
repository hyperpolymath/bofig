# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
defmodule EvidenceGraph.Testimony do
  @moduledoc """
  Context for witness testimony analysis and cross-referencing.

  Provides functions for cross-referencing claims made by witness entities,
  calculating witness reliability, detecting self-contradictions (impeachment),
  and building chronological testimony timelines.

  Works by traversing the ArangoDB graph: entities are linked to claims via
  `relationships` edges with `relationship_type == "authored"` or `"testified"`.
  Contradictions are detected via `"contradicts"` edges between claims.
  """

  alias EvidenceGraph.ArangoDB
  alias EvidenceGraph.Claims.Claim
  alias EvidenceGraph.PromptScores

  # ---------------------------------------------------------------------------
  # Cross-reference
  # ---------------------------------------------------------------------------

  @doc """
  Find all claims made by a witness entity, then for each claim find
  corroborating and contradicting claims from other witnesses.

  Returns a list of maps:

      %{
        claim: %Claim{},
        corroborating: [%Claim{}],
        contradicting: [%Claim{}],
        consistency_score: float()
      }

  The `consistency_score` for each claim is:

      corroborating_count / (corroborating_count + contradicting_count)

  or 1.0 if there are no related claims at all.
  """
  def cross_reference_claims(investigation_id, entity_id) do
    aql = """
    LET witness_claims = (
      FOR entity IN entities
        FILTER entity._key == @entity_id
        FOR v, e IN 1..1 OUTBOUND entity relationships
          FILTER IS_SAME_COLLECTION("claims", v)
          FILTER e.relationship_type IN ["authored", "testified"]
          FILTER v.investigation_id == @investigation_id
          RETURN v
    )

    FOR wc IN witness_claims
      LET corroborating = (
        FOR v, e IN 1..1 ANY wc relationships
          FILTER IS_SAME_COLLECTION("claims", v)
          FILTER e.relationship_type == "corroborates"
          FILTER v._key != wc._key
          LET other_authors = (
            FOR a, ae IN 1..1 INBOUND v relationships
              FILTER IS_SAME_COLLECTION("entities", a)
              FILTER ae.relationship_type IN ["authored", "testified"]
              FILTER a._key != @entity_id
              RETURN a._key
          )
          FILTER LENGTH(other_authors) > 0
          RETURN v
      )

      LET contradicting = (
        FOR v, e IN 1..1 ANY wc relationships
          FILTER IS_SAME_COLLECTION("claims", v)
          FILTER e.relationship_type == "contradicts"
          FILTER v._key != wc._key
          LET other_authors = (
            FOR a, ae IN 1..1 INBOUND v relationships
              FILTER IS_SAME_COLLECTION("entities", a)
              FILTER ae.relationship_type IN ["authored", "testified"]
              FILTER a._key != @entity_id
              RETURN a._key
          )
          FILTER LENGTH(other_authors) > 0
          RETURN v
      )

      RETURN {
        claim: wc,
        corroborating: corroborating,
        contradicting: contradicting
      }
    """

    case ArangoDB.query_read(aql, %{
           investigation_id: investigation_id,
           entity_id: entity_id
         }) do
      {:ok, results} ->
        parsed =
          Enum.map(results, fn r ->
            corr = Enum.map(r["corroborating"] || [], &Claim.from_arango_doc/1)
            cont = Enum.map(r["contradicting"] || [], &Claim.from_arango_doc/1)

            score = consistency_score(length(corr), length(cont))

            %{
              claim: Claim.from_arango_doc(r["claim"]),
              corroborating: corr,
              contradicting: cont,
              consistency_score: score
            }
          end)

        {:ok, parsed}

      error ->
        error
    end
  end

  # ---------------------------------------------------------------------------
  # Witness reliability
  # ---------------------------------------------------------------------------

  @doc """
  Calculate witness reliability based on self-contradiction rate,
  corroboration rate, and average PROMPT score across their testimony.

  Returns:

      %{
        reliability: float(),          # 0.0 - 1.0 composite score
        self_contradictions: integer(), # count of self-contradictions
        corroboration_rate: float(),    # 0.0 - 1.0
        total_claims: integer()
      }

  Reliability is computed as a weighted average:

      0.4 * (1 - self_contradiction_rate) +
      0.3 * corroboration_rate +
      0.3 * (avg_prompt_score / 100)
  """
  def witness_reliability(entity_id) do
    # Get all claims by this witness
    claims_aql = """
    FOR entity IN entities
      FILTER entity._key == @entity_id
      FOR v, e IN 1..1 OUTBOUND entity relationships
        FILTER IS_SAME_COLLECTION("claims", v)
        FILTER e.relationship_type IN ["authored", "testified"]
        RETURN v
    """

    with {:ok, claim_docs} <- ArangoDB.query_read(claims_aql, %{entity_id: entity_id}) do
      claims = Enum.map(claim_docs, &Claim.from_arango_doc/1)
      total = length(claims)

      if total == 0 do
        {:ok,
         %{
           reliability: 0.0,
           self_contradictions: 0,
           corroboration_rate: 0.0,
           total_claims: 0
         }}
      else
        # Count self-contradictions
        {:ok, impeachments} = impeachment_check(entity_id)
        self_contradiction_count = length(impeachments)

        # Count corroborated claims (claims that have at least one corroboration)
        corroborated_count = count_corroborated_claims(claims)

        # Average PROMPT score across all testimony
        avg_prompt =
          claims
          |> Enum.map(fn c -> PromptScores.calculate_overall(c.prompt_scores) end)
          |> then(fn scores ->
            if length(scores) > 0, do: Enum.sum(scores) / length(scores), else: 50.0
          end)

        self_contradiction_rate = min(self_contradiction_count / max(total, 1), 1.0)
        corroboration_rate = corroborated_count / max(total, 1)

        reliability =
          0.4 * (1.0 - self_contradiction_rate) +
            0.3 * corroboration_rate +
            0.3 * (avg_prompt / 100.0)

        {:ok,
         %{
           reliability: Float.round(reliability, 4),
           self_contradictions: self_contradiction_count,
           corroboration_rate: Float.round(corroboration_rate, 4),
           total_claims: total
         }}
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Impeachment check
  # ---------------------------------------------------------------------------

  @doc """
  Find all self-contradictions by a witness: claims where the same entity
  made contradictory statements (linked by a `"contradicts"` edge).

  Returns a list of:

      %{
        claim_a: %Claim{},
        claim_b: %Claim{},
        contradiction_type: :self_contradiction
      }
  """
  def impeachment_check(entity_id) do
    aql = """
    LET witness_claim_keys = (
      FOR entity IN entities
        FILTER entity._key == @entity_id
        FOR v, e IN 1..1 OUTBOUND entity relationships
          FILTER IS_SAME_COLLECTION("claims", v)
          FILTER e.relationship_type IN ["authored", "testified"]
          RETURN v._key
    )

    FOR claim_a_key IN witness_claim_keys
      LET claim_a = DOCUMENT("claims", claim_a_key)
      FOR v, e IN 1..1 ANY claim_a relationships
        FILTER IS_SAME_COLLECTION("claims", v)
        FILTER e.relationship_type == "contradicts"
        FILTER v._key IN witness_claim_keys
        FILTER v._key > claim_a._key
        RETURN {
          claim_a: claim_a,
          claim_b: v
        }
    """

    case ArangoDB.query_read(aql, %{entity_id: entity_id}) do
      {:ok, results} ->
        parsed =
          Enum.map(results, fn r ->
            %{
              claim_a: Claim.from_arango_doc(r["claim_a"]),
              claim_b: Claim.from_arango_doc(r["claim_b"]),
              contradiction_type: :self_contradiction
            }
          end)

        {:ok, parsed}

      error ->
        error
    end
  end

  # ---------------------------------------------------------------------------
  # Testimony timeline
  # ---------------------------------------------------------------------------

  @doc """
  All testimony from a witness ordered chronologically, with markers for
  contradictions and corroborations.

  Returns a list of:

      %{
        claim: %Claim{},
        timestamp: DateTime.t(),
        has_contradiction: boolean(),
        has_corroboration: boolean(),
        contradiction_ids: [String.t()],
        corroboration_ids: [String.t()]
      }
  """
  def testimony_timeline(entity_id) do
    aql = """
    FOR entity IN entities
      FILTER entity._key == @entity_id
      FOR v, e IN 1..1 OUTBOUND entity relationships
        FILTER IS_SAME_COLLECTION("claims", v)
        FILTER e.relationship_type IN ["authored", "testified"]
        LET contradictions = (
          FOR c, ce IN 1..1 ANY v relationships
            FILTER IS_SAME_COLLECTION("claims", c)
            FILTER ce.relationship_type == "contradicts"
            RETURN c._key
        )
        LET corroborations = (
          FOR c, ce IN 1..1 ANY v relationships
            FILTER IS_SAME_COLLECTION("claims", c)
            FILTER ce.relationship_type == "corroborates"
            RETURN c._key
        )
        SORT v.inserted_at ASC
        RETURN {
          claim: v,
          contradiction_ids: contradictions,
          corroboration_ids: corroborations
        }
    """

    case ArangoDB.query_read(aql, %{entity_id: entity_id}) do
      {:ok, results} ->
        timeline =
          Enum.map(results, fn r ->
            claim = Claim.from_arango_doc(r["claim"])
            contradiction_ids = r["contradiction_ids"] || []
            corroboration_ids = r["corroboration_ids"] || []

            %{
              claim: claim,
              timestamp: claim.inserted_at,
              has_contradiction: length(contradiction_ids) > 0,
              has_corroboration: length(corroboration_ids) > 0,
              contradiction_ids: contradiction_ids,
              corroboration_ids: corroboration_ids
            }
          end)

        {:ok, timeline}

      error ->
        error
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp consistency_score(corroborating, contradicting) do
    total = corroborating + contradicting

    if total == 0 do
      1.0
    else
      Float.round(corroborating / total, 4)
    end
  end

  defp count_corroborated_claims(claims) do
    claim_keys = Enum.map(claims, & &1.id)

    if length(claim_keys) == 0 do
      0
    else
      aql = """
      FOR claim_key IN @claim_keys
        LET claim = DOCUMENT("claims", claim_key)
        LET corr_count = LENGTH(
          FOR v, e IN 1..1 ANY claim relationships
            FILTER IS_SAME_COLLECTION("claims", v)
            FILTER e.relationship_type == "corroborates"
            LIMIT 1
            RETURN 1
        )
        FILTER corr_count > 0
        RETURN 1
      """

      case ArangoDB.query_read(aql, %{claim_keys: claim_keys}) do
        {:ok, results} -> length(results)
        _ -> 0
      end
    end
  end
end

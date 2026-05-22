# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
defmodule EvidenceGraph.Contradictions do
  @moduledoc """
  Context for finding, scoring, and resolving contradictions within an investigation.

  Scans the graph for explicit `"contradicts"` edges between claims and produces
  dashboard-ready aggregate statistics.  Contradiction resolution is tracked in
  a `resolution` sub-document on the relationship edge.
  """

  alias EvidenceGraph.ArangoDB
  alias EvidenceGraph.Claims.Claim

  @valid_resolutions ~w(confirmed dismissed partial requires_investigation)a

  # ---------------------------------------------------------------------------
  # Find contradictions
  # ---------------------------------------------------------------------------

  @doc """
  Scan all claims in an investigation for contradictions.

  Detection methods:
  - **explicit**: `"contradicts"` relationship edges in the graph
  - **same_entity_opposing**: Claims by the same entity with contradicting content
    (flagged for manual review)

  Returns a list of:

      %{
        id: String.t(),
        claim_a: %Claim{},
        claim_b: %Claim{},
        type: :explicit | :same_entity_opposing,
        severity: float(),
        detected_by: :graph_edge | :heuristic,
        resolved: boolean(),
        resolution: map() | nil
      }
  """
  def find_contradictions(investigation_id) do
    # Explicit contradictions via graph edges
    explicit_aql = """
    FOR claim_a IN claims
      FILTER claim_a.investigation_id == @investigation_id
      FOR claim_b, edge IN 1..1 OUTBOUND claim_a relationships
        FILTER IS_SAME_COLLECTION("claims", claim_b)
        FILTER edge.relationship_type == "contradicts"
        FILTER claim_b.investigation_id == @investigation_id
        FILTER claim_a._key < claim_b._key
        RETURN {
          edge_key: edge._key,
          claim_a: claim_a,
          claim_b: claim_b,
          weight: edge.weight,
          resolution: edge.resolution
        }
    """

    with {:ok, explicit_results} <-
           ArangoDB.query_read(explicit_aql, %{investigation_id: investigation_id}) do
      explicit =
        Enum.map(explicit_results, fn r ->
          %{
            id: r["edge_key"],
            claim_a: Claim.from_arango_doc(r["claim_a"]),
            claim_b: Claim.from_arango_doc(r["claim_b"]),
            type: :explicit,
            severity: r["weight"] || 0.5,
            detected_by: :graph_edge,
            resolved: r["resolution"] != nil,
            resolution: r["resolution"]
          }
        end)

      # Same-entity opposing claims (heuristic: same author, different claim_type)
      heuristic_aql = """
      FOR entity IN entities
        FILTER entity.investigation_id == @investigation_id
        LET entity_claims = (
          FOR v, e IN 1..1 OUTBOUND entity relationships
            FILTER IS_SAME_COLLECTION("claims", v)
            FILTER e.relationship_type IN ["authored", "testified"]
            FILTER v.investigation_id == @investigation_id
            RETURN v
        )
        FILTER LENGTH(entity_claims) > 1
        FOR i IN 0..LENGTH(entity_claims)-2
          FOR j IN (i+1)..LENGTH(entity_claims)-1
            LET a = entity_claims[i]
            LET b = entity_claims[j]
            FILTER (a.claim_type == "primary" AND b.claim_type == "counter")
                OR (a.claim_type == "counter" AND b.claim_type == "primary")
            LET already_linked = LENGTH(
              FOR v, e IN 1..1 ANY a relationships
                FILTER v._key == b._key
                FILTER e.relationship_type == "contradicts"
                RETURN 1
            )
            FILTER already_linked == 0
            RETURN {
              claim_a: a,
              claim_b: b,
              entity_key: entity._key
            }
      """

      heuristic =
        case ArangoDB.query_read(heuristic_aql, %{investigation_id: investigation_id}) do
          {:ok, h_results} ->
            Enum.map(h_results, fn r ->
              %{
                id: "heuristic_#{r["claim_a"]["_key"]}_#{r["claim_b"]["_key"]}",
                claim_a: Claim.from_arango_doc(r["claim_a"]),
                claim_b: Claim.from_arango_doc(r["claim_b"]),
                type: :same_entity_opposing,
                severity: 0.3,
                detected_by: :heuristic,
                resolved: false,
                resolution: nil
              }
            end)

          _ ->
            []
        end

      {:ok, explicit ++ heuristic}
    end
  end

  # ---------------------------------------------------------------------------
  # Dashboard data
  # ---------------------------------------------------------------------------

  @doc """
  Aggregate statistics for a LiveView contradiction dashboard.

  Returns:

      %{
        total: integer(),
        unresolved: integer(),
        resolved: integer(),
        by_type: %{explicit: integer(), same_entity_opposing: integer()},
        by_entity: [%{entity_id: String.t(), entity_name: String.t(), count: integer()}],
        most_contradicted: [%{claim: %Claim{}, contradiction_count: integer()}],
        contradictions: [contradiction_map()]
      }
  """
  def contradiction_dashboard_data(investigation_id) do
    with {:ok, contradictions} <- find_contradictions(investigation_id) do
      total = length(contradictions)
      unresolved = Enum.count(contradictions, &(!&1.resolved))
      resolved = total - unresolved

      by_type =
        contradictions
        |> Enum.frequencies_by(& &1.type)
        |> Map.put_new(:explicit, 0)
        |> Map.put_new(:same_entity_opposing, 0)

      # Most-contradicted claims: count how many contradictions each claim appears in
      claim_counts =
        contradictions
        |> Enum.flat_map(fn c -> [c.claim_a, c.claim_b] end)
        |> Enum.frequencies_by(& &1.id)
        |> Enum.sort_by(fn {_id, count} -> count end, :desc)
        |> Enum.take(20)

      most_contradicted =
        Enum.map(claim_counts, fn {_id, count} ->
          claim =
            contradictions
            |> Enum.flat_map(fn c -> [c.claim_a, c.claim_b] end)
            |> Enum.find(fn c -> Enum.any?(claim_counts, fn {cid, _} -> cid == c.id end) end)

          %{claim: claim, contradiction_count: count}
        end)
        |> Enum.uniq_by(fn m -> m.claim.id end)

      # By-entity breakdown
      by_entity = build_entity_breakdown(investigation_id)

      {:ok,
       %{
         total: total,
         unresolved: unresolved,
         resolved: resolved,
         by_type: by_type,
         by_entity: by_entity,
         most_contradicted: most_contradicted,
         contradictions:
           contradictions
           |> Enum.sort_by(& &1.severity, :desc)
       }}
    end
  end

  # ---------------------------------------------------------------------------
  # Get a single contradiction
  # ---------------------------------------------------------------------------

  @doc """
  Look up a contradiction (relationship edge) by ID and return it with
  the investigation_id derived from its connected claims.

  Returns `{:ok, %{id: ..., investigation_id: ...}}` or `{:error, :not_found}`.
  """
  def get_contradiction(contradiction_id) do
    aql = """
    LET edge = DOCUMENT(CONCAT("relationships/", @id))
    FILTER edge != null
    FILTER edge.relationship_type == "contradicts"
    LET from_doc = DOCUMENT(edge._from)
    RETURN {
      id: edge._key,
      investigation_id: from_doc.investigation_id
    }
    """

    case ArangoDB.query_read(aql, %{id: contradiction_id}) do
      {:ok, [doc]} when is_map(doc) ->
        {:ok, %{id: doc["id"], investigation_id: doc["investigation_id"]}}

      {:ok, _} ->
        {:error, :not_found}

      error ->
        error
    end
  end

  # ---------------------------------------------------------------------------
  # Resolve contradiction
  # ---------------------------------------------------------------------------

  @doc """
  Mark a contradiction as resolved with reasoning.

  `resolution` must be one of: `:confirmed`, `:dismissed`, `:partial`,
  `:requires_investigation`.

  Stores the resolution on the relationship edge document as:

      %{
        "status" => "confirmed",
        "rationale" => "...",
        "resolved_by" => "user_id",
        "resolved_at" => "2026-03-13T..."
      }
  """
  def resolve_contradiction(contradiction_id, %{status: status} = resolution)
      when status in @valid_resolutions do
    resolution_doc = %{
      "status" => to_string(status),
      "rationale" => Map.get(resolution, :rationale, ""),
      "resolved_by" => Map.get(resolution, :resolved_by),
      "resolved_at" => DateTime.to_iso8601(DateTime.utc_now())
    }

    case ArangoDB.update("relationships", contradiction_id, %{resolution: resolution_doc}) do
      {:ok, _doc} -> :ok
      error -> error
    end
  end

  def resolve_contradiction(_id, _resolution), do: {:error, :invalid_resolution_status}

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp build_entity_breakdown(investigation_id) do
    aql = """
    FOR entity IN entities
      FILTER entity.investigation_id == @investigation_id
      LET contradiction_count = LENGTH(
        FOR v, e IN 1..1 OUTBOUND entity relationships
          FILTER IS_SAME_COLLECTION("claims", v)
          FILTER e.relationship_type IN ["authored", "testified"]
          FOR c, ce IN 1..1 ANY v relationships
            FILTER IS_SAME_COLLECTION("claims", c)
            FILTER ce.relationship_type == "contradicts"
            RETURN 1
      )
      FILTER contradiction_count > 0
      SORT contradiction_count DESC
      RETURN {
        entity_id: entity._key,
        entity_name: entity.primary_name,
        count: contradiction_count
      }
    """

    case ArangoDB.query_read(aql, %{investigation_id: investigation_id}) do
      {:ok, results} ->
        Enum.map(results, fn r ->
          %{
            entity_id: r["entity_id"],
            entity_name: r["entity_name"],
            count: r["count"]
          }
        end)

      _ ->
        []
    end
  end
end

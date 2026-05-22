# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
defmodule EvidenceGraph.Investigations do
  @moduledoc """
  Context for managing Investigations in the Evidence Graph.

  An investigation is the top-level container: all claims, evidence, entities,
  financial transactions, and relationships are scoped to an investigation via
  `investigation_id`.

  Also supports cross-investigation evidence sharing (by reference, not copy)
  and finding evidence common to multiple investigations.
  """

  alias EvidenceGraph.ArangoDB

  @statuses ~w(active archived closed)

  # ---------------------------------------------------------------------------
  # CRUD
  # ---------------------------------------------------------------------------

  @doc """
  Create a new investigation.

  ## Examples

      iex> create_investigation(%{title: "UK Inflation 2023", created_by: "user_1"})
      {:ok, %{...}}
  """
  def create_investigation(attrs) do
    now = DateTime.to_iso8601(DateTime.utc_now())

    doc = %{
      _key: "inv_" <> Ecto.UUID.generate(),
      title: Map.fetch!(attrs, :title),
      description: Map.get(attrs, :description, ""),
      created_by: Map.get(attrs, :created_by),
      status: Map.get(attrs, :status, "active") |> to_string(),
      metadata: Map.get(attrs, :metadata, %{}),
      shared_evidence_refs: [],
      inserted_at: now,
      updated_at: now
    }

    case ArangoDB.insert("investigations", doc) do
      {:ok, result} -> {:ok, format_investigation(result)}
      error -> error
    end
  end

  @doc """
  Get an investigation by ID.
  """
  def get_investigation(id) do
    case ArangoDB.get("investigations", id) do
      {:ok, doc} -> {:ok, format_investigation(doc)}
      error -> error
    end
  end

  @doc """
  List investigations with optional filtering by status.
  """
  def list_investigations(opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)
    offset = Keyword.get(opts, :offset, 0)
    status = Keyword.get(opts, :status)

    {filter_clause, vars} =
      if status do
        {"FILTER inv.status == @status",
         %{limit: limit, offset: offset, status: to_string(status)}}
      else
        {"", %{limit: limit, offset: offset}}
      end

    aql = """
    FOR inv IN investigations
      #{filter_clause}
      SORT inv.inserted_at DESC
      LIMIT @offset, @limit
      RETURN inv
    """

    case ArangoDB.query_read(aql, vars) do
      {:ok, docs} -> {:ok, Enum.map(docs, &format_investigation/1)}
      error -> error
    end
  end

  @doc """
  Update an investigation.
  """
  def update_investigation(id, attrs) do
    updates =
      attrs
      |> Map.take([:title, :description, :status, :metadata])
      |> Enum.into(%{}, fn
        {:status, v} -> {"status", to_string(v)}
        {k, v} -> {to_string(k), v}
      end)
      |> Map.put("updated_at", DateTime.to_iso8601(DateTime.utc_now()))

    case ArangoDB.update("investigations", id, updates) do
      {:ok, doc} -> {:ok, format_investigation(doc)}
      error -> error
    end
  end

  @doc """
  Archive an investigation (sets status to "archived").
  """
  def archive_investigation(id) do
    update_investigation(id, %{status: :archived})
  end

  # ---------------------------------------------------------------------------
  # Statistics
  # ---------------------------------------------------------------------------

  @doc """
  Aggregate statistics for an investigation.

  Returns:

      %{
        evidence_count: integer(),
        claim_count: integer(),
        entity_count: integer(),
        transaction_count: integer(),
        relationship_count: integer(),
        avg_prompt_score: float(),
        contradiction_count: integer()
      }
  """
  def investigation_stats(id) do
    aql = """
    LET evidence_count = LENGTH(
      FOR e IN evidence FILTER e.investigation_id == @id RETURN 1
    )
    LET claim_count = LENGTH(
      FOR c IN claims FILTER c.investigation_id == @id RETURN 1
    )
    LET entity_count = LENGTH(
      FOR ent IN entities FILTER ent.investigation_id == @id RETURN 1
    )
    LET transaction_count = LENGTH(
      FOR txn IN financial_transactions FILTER txn.investigation_id == @id RETURN 1
    )
    LET inv_claims = (
      FOR c IN claims FILTER c.investigation_id == @id RETURN c
    )
    LET relationship_count = LENGTH(
      FOR c IN inv_claims
        FOR v, edge IN 1..1 ANY c relationships
          RETURN DISTINCT edge._key
    )
    LET contradiction_count = LENGTH(
      FOR c IN inv_claims
        FOR v, edge IN 1..1 OUTBOUND c relationships
          FILTER edge.relationship_type == "contradicts"
          FILTER v._key > c._key
          RETURN 1
    )
    LET prompt_scores = (
      FOR c IN inv_claims
        FILTER c.prompt_scores != null
        LET overall = (
          (c.prompt_scores.provenance OR 50) * 0.20 +
          (c.prompt_scores.replicability OR 50) * 0.15 +
          (c.prompt_scores.objective OR 50) * 0.15 +
          (c.prompt_scores.methodology OR 50) * 0.20 +
          (c.prompt_scores.publication OR 50) * 0.15 +
          (c.prompt_scores.transparency OR 50) * 0.15
        )
        RETURN overall
    )
    LET avg_prompt = LENGTH(prompt_scores) > 0
      ? AVG(prompt_scores)
      : 50.0

    RETURN {
      evidence_count: evidence_count,
      claim_count: claim_count,
      entity_count: entity_count,
      transaction_count: transaction_count,
      relationship_count: relationship_count,
      avg_prompt_score: avg_prompt,
      contradiction_count: contradiction_count
    }
    """

    case ArangoDB.query_read(aql, %{id: id}) do
      {:ok, [result]} ->
        {:ok,
         %{
           evidence_count: result["evidence_count"] || 0,
           claim_count: result["claim_count"] || 0,
           entity_count: result["entity_count"] || 0,
           transaction_count: result["transaction_count"] || 0,
           relationship_count: result["relationship_count"] || 0,
           avg_prompt_score: result["avg_prompt_score"] || 50.0,
           contradiction_count: result["contradiction_count"] || 0
         }}

      {:ok, []} ->
        {:error, :not_found}

      error ->
        error
    end
  end

  # ---------------------------------------------------------------------------
  # Cross-investigation evidence sharing
  # ---------------------------------------------------------------------------

  @doc """
  Share evidence from one investigation to another by reference.

  Creates reference entries in the target investigation's
  `shared_evidence_refs` array. Does NOT copy documents.
  """
  def share_evidence(from_investigation_id, to_investigation_id, evidence_ids)
      when is_list(evidence_ids) do
    now = DateTime.to_iso8601(DateTime.utc_now())

    refs =
      Enum.map(evidence_ids, fn eid ->
        %{
          "evidence_id" => eid,
          "source_investigation_id" => from_investigation_id,
          "shared_at" => now
        }
      end)

    aql = """
    LET inv = DOCUMENT("investigations", @to_id)
    FILTER inv != null
    LET existing_ids = (
      FOR ref IN (inv.shared_evidence_refs || [])
        RETURN ref.evidence_id
    )
    LET new_refs = (
      FOR ref IN @refs
        FILTER ref.evidence_id NOT IN existing_ids
        RETURN ref
    )
    UPDATE inv WITH {
      shared_evidence_refs: APPEND(inv.shared_evidence_refs || [], new_refs),
      updated_at: @now
    } IN investigations
    RETURN NEW
    """

    case ArangoDB.query(aql, %{to_id: to_investigation_id, refs: refs, now: now}) do
      {:ok, [doc]} -> {:ok, format_investigation(doc)}
      {:ok, []} -> {:error, :not_found}
      error -> error
    end
  end

  @doc """
  Find evidence that appears in multiple investigations.

  Accepts a list of investigation IDs and returns evidence items
  (from the `evidence` collection) whose `investigation_id` matches one
  of the given IDs OR that are referenced as shared evidence in any of them.
  """
  def find_shared_evidence(investigation_ids) when is_list(investigation_ids) do
    aql = """
    LET shared_refs = (
      FOR inv IN investigations
        FILTER inv._key IN @ids
        FOR ref IN (inv.shared_evidence_refs || [])
          RETURN ref.evidence_id
    )

    LET native_evidence_ids = (
      FOR e IN evidence
        FILTER e.investigation_id IN @ids
        RETURN e._key
    )

    LET all_ids = UNION(shared_refs, native_evidence_ids)

    FOR eid IN all_ids
      COLLECT evidence_id = eid WITH COUNT INTO appearances
      FILTER appearances > 1
      LET doc = DOCUMENT("evidence", evidence_id)
      FILTER doc != null
      RETURN {
        evidence: doc,
        appears_in_count: appearances
      }
    """

    case ArangoDB.query_read(aql, %{ids: investigation_ids}) do
      {:ok, results} ->
        parsed =
          Enum.map(results, fn r ->
            %{
              evidence: EvidenceGraph.Evidence.Evidence.from_arango_doc(r["evidence"]),
              appears_in_count: r["appears_in_count"]
            }
          end)

        {:ok, parsed}

      error ->
        error
    end
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp format_investigation(doc) do
    %{
      id: doc["_key"],
      title: doc["title"],
      description: doc["description"],
      created_by: doc["created_by"],
      status: doc["status"],
      metadata: doc["metadata"] || %{},
      shared_evidence_refs: doc["shared_evidence_refs"] || [],
      inserted_at: doc["inserted_at"],
      updated_at: doc["updated_at"]
    }
  end

  @doc """
  Valid investigation statuses.
  """
  def valid_statuses, do: @statuses
end

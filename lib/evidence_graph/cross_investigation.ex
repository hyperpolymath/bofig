# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
defmodule EvidenceGraph.CrossInvestigation do
  @moduledoc """
  Cross-Investigation Linking for the Evidence Graph.

  Enables discovery and explicit linking of relationships between separate
  investigations.  Supports finding shared entities (by name or alias),
  shared evidence (by SHA-256 hash), creating investigation links, and
  searching across multiple investigations simultaneously.

  Investigation links are stored in the ArangoDB `investigation_links`
  document collection.
  """

  alias EvidenceGraph.ArangoDB

  @link_types [:shared_entity, :shared_evidence, :sequential, :parallel, :contradictory]

  @doc """
  Find entities that appear in multiple investigations.

  Matches by `primary_name` or alias overlap.  Returns a list of entity
  groups where each group contains entities from different investigations
  that refer to the same real-world actor/object.

  ## Parameters

  - `investigation_ids` - List of investigation IDs to search across

  ## Returns

  `{:ok, [%{name: string, entities: [entity_doc]}]}`
  """
  def find_shared_entities(investigation_ids) when is_list(investigation_ids) do
    aql = """
    LET all_entities = (
      FOR entity IN entities
        FILTER entity.investigation_id IN @investigation_ids
        RETURN entity
    )

    LET name_groups = (
      FOR entity IN all_entities
        LET all_names = APPEND([entity.primary_name], entity.aliases || [])
        FOR name IN all_names
          COLLECT lower_name = LOWER(name)
          INTO grouped = entity
          FILTER LENGTH(grouped) > 1
          LET unique_investigations = LENGTH(
            FOR e IN grouped
              RETURN DISTINCT e.investigation_id
          )
          FILTER unique_investigations > 1
          RETURN {
            name: lower_name,
            entities: grouped
          }
    )

    RETURN name_groups
    """

    case ArangoDB.query_read(aql, %{investigation_ids: investigation_ids}) do
      {:ok, [groups]} ->
        shared =
          Enum.map(groups, fn group ->
            %{
              name: group["name"],
              entities: group["entities"] || []
            }
          end)

        {:ok, shared}

      {:ok, []} ->
        {:ok, []}

      error ->
        error
    end
  end

  @doc """
  Find evidence items shared across multiple investigations by SHA-256 hash.

  Returns groups of evidence that have the same content hash but belong to
  different investigations.

  ## Returns

  `{:ok, [%{sha256_hash: string, evidence: [evidence_doc]}]}`
  """
  def find_shared_evidence(investigation_ids) when is_list(investigation_ids) do
    aql = """
    FOR ev IN evidence
      FILTER ev.investigation_id IN @investigation_ids
      FILTER ev.sha256_hash != null AND ev.sha256_hash != ""
      COLLECT hash = ev.sha256_hash INTO grouped = ev
      LET unique_investigations = LENGTH(
        FOR e IN grouped
          RETURN DISTINCT e.investigation_id
      )
      FILTER unique_investigations > 1
      RETURN {
        sha256_hash: hash,
        evidence: grouped
      }
    """

    case ArangoDB.query_read(aql, %{investigation_ids: investigation_ids}) do
      {:ok, results} ->
        shared =
          Enum.map(results, fn group ->
            %{
              sha256_hash: group["sha256_hash"],
              evidence: group["evidence"] || []
            }
          end)

        {:ok, shared}

      error ->
        error
    end
  end

  @doc """
  Create an explicit link between two investigations.

  ## Parameters

  - `inv_a_id` - First investigation ID
  - `inv_b_id` - Second investigation ID
  - `link_type` - One of #{inspect(@link_types)}
  - `reason` - Human-readable justification for the link

  ## Returns

  `{:ok, link_doc}` or `{:error, reason}`
  """
  def link_investigations(inv_a_id, inv_b_id, link_type, reason)
      when link_type in @link_types do
    # Canonical ordering: always store the lesser ID as inv_a to avoid duplicates
    {canonical_a, canonical_b} =
      if inv_a_id <= inv_b_id, do: {inv_a_id, inv_b_id}, else: {inv_b_id, inv_a_id}

    document = %{
      _key: "link_#{canonical_a}_#{canonical_b}_#{to_string(link_type)}",
      investigation_a_id: canonical_a,
      investigation_b_id: canonical_b,
      link_type: to_string(link_type),
      reason: reason,
      created_at: DateTime.to_iso8601(DateTime.utc_now()),
      updated_at: DateTime.to_iso8601(DateTime.utc_now())
    }

    # Upsert: if link already exists, update the reason and timestamp
    aql = """
    UPSERT {_key: @key}
    INSERT @document
    UPDATE {
      reason: @document.reason,
      updated_at: DATE_ISO8601(DATE_NOW())
    } IN investigation_links
    RETURN NEW
    """

    case ArangoDB.query(aql, %{key: document._key, document: document}) do
      {:ok, [doc]} -> {:ok, doc}
      {:ok, []} -> {:error, :insert_failed}
      error -> error
    end
  end

  def link_investigations(_inv_a_id, _inv_b_id, link_type, _reason) do
    {:error, {:invalid_link_type, link_type, @link_types}}
  end

  @doc """
  Get all investigations linked to a given investigation, as a network graph.

  Returns `{:ok, %{nodes: [investigation_doc], links: [link_doc]}}`.
  """
  def investigation_network(investigation_id) do
    # Find all links involving this investigation
    links_aql = """
    FOR link IN investigation_links
      FILTER link.investigation_a_id == @investigation_id
          OR link.investigation_b_id == @investigation_id
      RETURN link
    """

    case ArangoDB.query_read(links_aql, %{investigation_id: investigation_id}) do
      {:ok, links} ->
        # Collect all unique investigation IDs from the links
        linked_ids =
          links
          |> Enum.flat_map(fn link ->
            [link["investigation_a_id"], link["investigation_b_id"]]
          end)
          |> Enum.uniq()
          |> Enum.reject(&is_nil/1)

        # Ensure the root investigation is always included
        all_ids = Enum.uniq([investigation_id | linked_ids])

        # Fetch investigation documents
        nodes_aql = """
        FOR inv IN investigations
          FILTER inv._key IN @ids
          RETURN inv
        """

        case ArangoDB.query_read(nodes_aql, %{ids: all_ids}) do
          {:ok, nodes} ->
            {:ok, %{nodes: nodes, links: links}}

          error ->
            error
        end

      error ->
        error
    end
  end

  @doc """
  Search across multiple investigations simultaneously.

  Performs a text search on claims and evidence within the specified
  investigations.  Returns results grouped by investigation.

  ## Parameters

  - `query` - Search query text
  - `investigation_ids` - List of investigation IDs to search within

  ## Returns

  `{:ok, %{claims: [claim_doc], evidence: [evidence_doc]}}`
  """
  def cross_investigation_search(query, investigation_ids)
      when is_binary(query) and is_list(investigation_ids) do
    claims_aql = """
    FOR claim IN claims
      FILTER claim.investigation_id IN @investigation_ids
      FILTER CONTAINS(LOWER(claim.text), LOWER(@query))
      SORT claim.inserted_at DESC
      LIMIT 100
      RETURN claim
    """

    evidence_aql = """
    FOR ev IN evidence
      FILTER ev.investigation_id IN @investigation_ids
      FILTER CONTAINS(LOWER(ev.title), LOWER(@query))
      SORT ev.inserted_at DESC
      LIMIT 100
      RETURN ev
    """

    vars = %{query: query, investigation_ids: investigation_ids}

    with {:ok, claims} <- ArangoDB.query_read(claims_aql, vars),
         {:ok, evidence} <- ArangoDB.query_read(evidence_aql, vars) do
      {:ok, %{claims: claims, evidence: evidence}}
    end
  end

  @doc """
  Returns the list of valid link types for investigation linking.
  """
  def link_types, do: @link_types
end

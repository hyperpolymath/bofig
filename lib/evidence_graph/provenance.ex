# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
defmodule EvidenceGraph.Provenance do
  @moduledoc """
  Lithoglyph Provenance Layer for the Evidence Graph.

  Records every action taken within the system with full provenance metadata,
  enabling time-travel queries and audit reconstruction.  Actions are stored
  in the ArangoDB `provenance_log` collection.

  This module implements the provenance principles from the Lithoglyph
  narrative-first database: every mutation is a logged, timestamped event
  with actor attribution and rationale.

  ## Action Types

  Common action types (extensible):
  - `"evidence_created"`, `"evidence_updated"`, `"evidence_deleted"`
  - `"claim_created"`, `"claim_updated"`, `"claim_deleted"`
  - `"entity_created"`, `"entity_merged"`, `"entity_unmerged"`
  - `"relationship_created"`, `"relationship_deleted"`
  - `"retraction_applied"`, `"redaction_recorded"`
  - `"investigation_linked"`, `"annotation_created"`
  """

  alias EvidenceGraph.ArangoDB

  @doc """
  Record an action in the provenance log.

  ## Parameters

  - `action_type` - A string describing the action (see module doc for common types)
  - `actor` - The user ID or system identifier performing the action
  - `target_id` - The `_key` of the document being acted upon
  - `target_type` - The collection name of the target (e.g. "evidence", "claims")
  - `rationale` - Human-readable reason for the action
  - `metadata` - Additional context (before/after snapshots, parameters, etc.)

  ## Returns

  `{:ok, provenance_entry}` or `{:error, reason}`
  """
  def record_action(action_type, actor, target_id, target_type, rationale, metadata \\ %{}) do
    entry = %{
      _key: "prov_" <> Ecto.UUID.generate(),
      action_type: action_type,
      actor: actor,
      target_id: target_id,
      target_type: target_type,
      rationale: rationale,
      metadata: metadata,
      timestamp: DateTime.to_iso8601(DateTime.utc_now())
    }

    ArangoDB.insert("provenance_log", entry)
  end

  @doc """
  Get the full action history for a given target document.

  Returns all provenance entries for `target_id`, ordered chronologically
  (oldest first).

  ## Returns

  `{:ok, [provenance_entry]}` or `{:error, reason}`
  """
  def action_history(target_id) do
    aql = """
    FOR entry IN provenance_log
      FILTER entry.target_id == @target_id
      SORT entry.timestamp ASC
      RETURN entry
    """

    ArangoDB.query_read(aql, %{target_id: target_id})
  end

  @doc """
  Get all actions performed by a given actor.

  Returns provenance entries ordered by most recent first.

  ## Options

  - `:limit` - Maximum entries to return (default: 100)
  - `:offset` - Pagination offset (default: 0)

  ## Returns

  `{:ok, [provenance_entry]}` or `{:error, reason}`
  """
  def actor_history(actor_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 100)
    offset = Keyword.get(opts, :offset, 0)

    aql = """
    FOR entry IN provenance_log
      FILTER entry.actor == @actor_id
      SORT entry.timestamp DESC
      LIMIT @offset, @limit
      RETURN entry
    """

    ArangoDB.query_read(aql, %{actor_id: actor_id, limit: limit, offset: offset})
  end

  @doc """
  Reconstruct the state of an investigation at a given point in time.

  Queries the provenance log for all actions within the investigation scope
  that occurred before `as_of_date`, then summarises what existed at that time.

  This is a read-only reconstruction — it does not modify any data.

  ## Returns

  `{:ok, %{as_of: date, entities: [map], evidence: [map], claims: [map], relationships: [map]}}`
  """
  def time_travel_query(investigation_id, %Date{} = as_of_date) do
    as_of_str = Date.to_iso8601(as_of_date) <> "T23:59:59Z"

    # Gather all provenance entries for this investigation's targets up to the date.
    # We identify investigation-scoped targets by querying each collection.
    entities_aql = """
    LET entity_keys = (
      FOR e IN entities
        FILTER e.investigation_id == @investigation_id
        RETURN e._key
    )

    LET entity_actions = (
      FOR entry IN provenance_log
        FILTER entry.target_type == "entities"
        FILTER entry.target_id IN entity_keys
        FILTER entry.timestamp <= @as_of
        SORT entry.timestamp ASC
        RETURN entry
    )

    RETURN entity_actions
    """

    evidence_aql = """
    LET ev_keys = (
      FOR ev IN evidence
        FILTER ev.investigation_id == @investigation_id
        RETURN ev._key
    )

    LET evidence_actions = (
      FOR entry IN provenance_log
        FILTER entry.target_type == "evidence"
        FILTER entry.target_id IN ev_keys
        FILTER entry.timestamp <= @as_of
        SORT entry.timestamp ASC
        RETURN entry
    )

    RETURN evidence_actions
    """

    claims_aql = """
    LET claim_keys = (
      FOR c IN claims
        FILTER c.investigation_id == @investigation_id
        RETURN c._key
    )

    LET claim_actions = (
      FOR entry IN provenance_log
        FILTER entry.target_type == "claims"
        FILTER entry.target_id IN claim_keys
        FILTER entry.timestamp <= @as_of
        SORT entry.timestamp ASC
        RETURN entry
    )

    RETURN claim_actions
    """

    vars = %{investigation_id: investigation_id, as_of: as_of_str}

    with {:ok, [entity_actions]} <- ArangoDB.query_read(entities_aql, vars),
         {:ok, [evidence_actions]} <- ArangoDB.query_read(evidence_aql, vars),
         {:ok, [claim_actions]} <- ArangoDB.query_read(claims_aql, vars) do
      # Replay actions to determine what existed at that point:
      # - "created" actions add an item
      # - "deleted" actions remove it
      # - "updated"/"merged" actions modify it
      entities_state = replay_to_existence(entity_actions)
      evidence_state = replay_to_existence(evidence_actions)
      claims_state = replay_to_existence(claim_actions)

      {:ok,
       %{
         as_of: as_of_date,
         investigation_id: investigation_id,
         entities: entities_state,
         evidence: evidence_state,
         claims: claims_state,
         action_counts: %{
           entity_actions: length(entity_actions),
           evidence_actions: length(evidence_actions),
           claim_actions: length(claim_actions)
         }
       }}
    end
  end

  @doc """
  Compute the diff of actions between two dates for an investigation.

  Returns all provenance entries that occurred in the `(date_a, date_b]` range.

  ## Returns

  `{:ok, %{from: date_a, to: date_b, actions: [provenance_entry], summary: map}}`
  """
  def diff_between_dates(investigation_id, %Date{} = date_a, %Date{} = date_b) do
    from_str = Date.to_iso8601(date_a) <> "T00:00:00Z"
    to_str = Date.to_iso8601(date_b) <> "T23:59:59Z"

    # Get all target IDs for this investigation across all collections
    aql = """
    LET all_targets = UNION(
      (FOR e IN entities FILTER e.investigation_id == @investigation_id RETURN e._key),
      (FOR ev IN evidence FILTER ev.investigation_id == @investigation_id RETURN ev._key),
      (FOR c IN claims FILTER c.investigation_id == @investigation_id RETURN c._key)
    )

    FOR entry IN provenance_log
      FILTER entry.target_id IN all_targets
      FILTER entry.timestamp > @from_date
      FILTER entry.timestamp <= @to_date
      SORT entry.timestamp ASC
      RETURN entry
    """

    vars = %{
      investigation_id: investigation_id,
      from_date: from_str,
      to_date: to_str
    }

    case ArangoDB.query_read(aql, vars) do
      {:ok, actions} ->
        # Build summary by action type
        summary =
          actions
          |> Enum.group_by(& &1["action_type"])
          |> Enum.map(fn {type, entries} -> {type, length(entries)} end)
          |> Map.new()

        {:ok,
         %{
           from: date_a,
           to: date_b,
           investigation_id: investigation_id,
           actions: actions,
           total_actions: length(actions),
           summary: summary
         }}

      error ->
        error
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  # Replay a list of provenance actions to determine which target IDs
  # exist (were created and not subsequently deleted).
  defp replay_to_existence(actions) do
    actions
    |> Enum.reduce(%{}, fn action, acc ->
      target_id = action["target_id"]
      action_type = action["action_type"] || ""

      cond do
        String.contains?(action_type, "deleted") ->
          Map.delete(acc, target_id)

        String.contains?(action_type, "created") ->
          Map.put(acc, target_id, %{
            id: target_id,
            action_type: action_type,
            first_seen: action["timestamp"],
            last_action: action["timestamp"],
            actor: action["actor"]
          })

        true ->
          # Update / merge / other — mark as still existing
          Map.update(acc, target_id, %{
            id: target_id,
            action_type: action_type,
            first_seen: action["timestamp"],
            last_action: action["timestamp"],
            actor: action["actor"]
          }, fn existing ->
            %{existing | last_action: action["timestamp"]}
          end)
      end
    end)
    |> Map.values()
  end
end

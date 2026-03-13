# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
defmodule EvidenceGraph.TemporalCredibility do
  @moduledoc """
  Temporal Credibility Model for the Evidence Graph.

  Calculates entity credibility at any point in time by replaying events
  (retractions, corroborations, contradictions, new testimony) up to a given
  date.  Provides full credibility timelines, retraction handling, and
  source reputation scoring.

  All credibility scores are floats in the range 0.0..100.0.
  """

  alias EvidenceGraph.ArangoDB

  @doc """
  Calculate an entity's credibility score as it would have been on a given date.

  Factors in:
  - Retractions of evidence mentioning the entity before `date`
  - Contradictions known at that time
  - Corroboration count at that time

  Returns `{:ok, float}` or `{:error, reason}`.
  """
  def credibility_at(entity_id, %Date{} = date) do
    date_str = Date.to_iso8601(date)

    # Count corroborations (supporting relationships created before the date)
    corroboration_aql = """
    FOR v, e IN 1..1 ANY CONCAT("entities/", @entity_id) relationships
      FILTER e.relationship_type == "supports"
      FILTER e.inserted_at != null AND e.inserted_at <= @date
      COLLECT WITH COUNT INTO cnt
      RETURN cnt
    """

    # Count contradictions before the date
    contradiction_aql = """
    FOR v, e IN 1..1 ANY CONCAT("entities/", @entity_id) relationships
      FILTER e.relationship_type == "contradicts"
      FILTER e.inserted_at != null AND e.inserted_at <= @date
      COLLECT WITH COUNT INTO cnt
      RETURN cnt
    """

    # Count retractions of evidence linked to this entity before the date
    retraction_aql = """
    FOR v, e IN 1..1 ANY CONCAT("entities/", @entity_id) relationships
      FILTER IS_SAME_COLLECTION("evidence", v)
      FILTER v.metadata.retracted == true
      FILTER v.metadata.retraction_date != null AND v.metadata.retraction_date <= @date
      COLLECT WITH COUNT INTO cnt
      RETURN cnt
    """

    # Total evidence linked to entity (for baseline)
    total_evidence_aql = """
    FOR v, e IN 1..1 ANY CONCAT("entities/", @entity_id) relationships
      FILTER IS_SAME_COLLECTION("evidence", v)
      FILTER v.inserted_at != null AND v.inserted_at <= @date
      COLLECT WITH COUNT INTO cnt
      RETURN cnt
    """

    vars = %{entity_id: entity_id, date: date_str}

    with {:ok, [corroborations]} <- ArangoDB.query_read(corroboration_aql, vars),
         {:ok, [contradictions]} <- ArangoDB.query_read(contradiction_aql, vars),
         {:ok, [retractions]} <- ArangoDB.query_read(retraction_aql, vars),
         {:ok, [total_evidence]} <- ArangoDB.query_read(total_evidence_aql, vars) do
      score = compute_credibility(corroborations, contradictions, retractions, total_evidence)
      {:ok, score}
    end
  end

  @doc """
  Generate a full credibility timeline for an entity.

  Returns `{:ok, [%{date: date, credibility: float, event: string, delta: float}]}`
  sorted chronologically.  Each entry represents a credibility-affecting event.
  """
  def credibility_timeline(entity_id) do
    # Gather all credibility-affecting events for this entity
    events_aql = """
    LET corroborations = (
      FOR v, e IN 1..1 ANY CONCAT("entities/", @entity_id) relationships
        FILTER e.relationship_type == "supports"
        FILTER e.inserted_at != null
        RETURN {date: e.inserted_at, event: "corroboration", detail: e._key}
    )

    LET contradictions = (
      FOR v, e IN 1..1 ANY CONCAT("entities/", @entity_id) relationships
        FILTER e.relationship_type == "contradicts"
        FILTER e.inserted_at != null
        RETURN {date: e.inserted_at, event: "contradiction", detail: e._key}
    )

    LET retractions = (
      FOR v, e IN 1..1 ANY CONCAT("entities/", @entity_id) relationships
        FILTER IS_SAME_COLLECTION("evidence", v)
        FILTER v.metadata.retracted == true
        FILTER v.metadata.retraction_date != null
        RETURN {date: v.metadata.retraction_date, event: "retraction", detail: v._key}
    )

    LET new_testimony = (
      FOR v, e IN 1..1 ANY CONCAT("entities/", @entity_id) relationships
        FILTER IS_SAME_COLLECTION("evidence", v)
        FILTER v.evidence_type == "interview"
        FILTER v.inserted_at != null
        RETURN {date: v.inserted_at, event: "new_testimony", detail: v._key}
    )

    FOR event IN UNION(corroborations, contradictions, retractions, new_testimony)
      SORT event.date ASC
      RETURN event
    """

    case ArangoDB.query_read(events_aql, %{entity_id: entity_id}) do
      {:ok, events} ->
        timeline = build_timeline(events)
        {:ok, timeline}

      error ->
        error
    end
  end

  @doc """
  Mark an evidence item as retracted and recalculate affected entity credibilities.

  Stores the retraction in the evidence metadata and returns the list of
  entity IDs whose credibility was affected.

  ## Parameters

  - `evidence_id` - The evidence item to retract
  - `retraction_date` - The date the retraction was issued
  - `reason` - A human-readable reason for the retraction
  """
  def apply_retraction(evidence_id, %Date{} = retraction_date, reason) do
    retraction_date_str = Date.to_iso8601(retraction_date)

    # Mark the evidence as retracted
    update_aql = """
    FOR ev IN evidence
      FILTER ev._key == @evidence_id
      UPDATE ev WITH {
        metadata: MERGE(ev.metadata, {
          retracted: true,
          retraction_date: @retraction_date,
          retraction_reason: @reason,
          retracted_at: DATE_ISO8601(DATE_NOW())
        }),
        updated_at: DATE_ISO8601(DATE_NOW())
      } IN evidence
      RETURN NEW
    """

    # Find all entities linked to this evidence
    affected_entities_aql = """
    FOR v, e IN 1..1 ANY CONCAT("evidence/", @evidence_id) relationships
      FILTER IS_SAME_COLLECTION("entities", v)
      RETURN DISTINCT v._key
    """

    with {:ok, [_updated]} <-
           ArangoDB.query(update_aql, %{
             evidence_id: evidence_id,
             retraction_date: retraction_date_str,
             reason: reason
           }),
         {:ok, entity_ids} <-
           ArangoDB.query_read(affected_entities_aql, %{evidence_id: evidence_id}) do
      # Recalculate credibility for each affected entity
      results =
        Enum.map(entity_ids, fn eid ->
          case credibility_at(eid, retraction_date) do
            {:ok, score} ->
              # Update the entity's credibility_score field
              ArangoDB.update("entities", eid, %{
                credibility_score: round(score),
                updated_at: DateTime.to_iso8601(DateTime.utc_now())
              })

              {eid, score}

            _ ->
              {eid, nil}
          end
        end)

      {:ok, %{evidence_id: evidence_id, affected_entities: results}}
    end
  end

  @doc """
  Calculate the current source reputation for an entity based on its full
  history of events.

  Reputation is a weighted credibility score factoring in:
  - Longevity (how long the entity has been in the system)
  - Consistency (ratio of corroborations to contradictions over time)
  - Retraction impact (how many retractions affected this entity)

  Returns `{:ok, %{score: float, factors: map}}`.
  """
  def source_reputation(entity_id) do
    stats_aql = """
    LET entity = FIRST(
      FOR e IN entities FILTER e._key == @entity_id RETURN e
    )

    LET corroborations = LENGTH(
      FOR v, e IN 1..1 ANY CONCAT("entities/", @entity_id) relationships
        FILTER e.relationship_type == "supports"
        RETURN 1
    )

    LET contradictions = LENGTH(
      FOR v, e IN 1..1 ANY CONCAT("entities/", @entity_id) relationships
        FILTER e.relationship_type == "contradicts"
        RETURN 1
    )

    LET retractions = LENGTH(
      FOR v, e IN 1..1 ANY CONCAT("entities/", @entity_id) relationships
        FILTER IS_SAME_COLLECTION("evidence", v)
        FILTER v.metadata.retracted == true
        RETURN 1
    )

    LET total_evidence = LENGTH(
      FOR v, e IN 1..1 ANY CONCAT("entities/", @entity_id) relationships
        FILTER IS_SAME_COLLECTION("evidence", v)
        RETURN 1
    )

    RETURN {
      entity: entity,
      corroborations: corroborations,
      contradictions: contradictions,
      retractions: retractions,
      total_evidence: total_evidence
    }
    """

    case ArangoDB.query_read(stats_aql, %{entity_id: entity_id}) do
      {:ok, [stats]} ->
        entity = stats["entity"]
        corroborations = stats["corroborations"] || 0
        contradictions = stats["contradictions"] || 0
        retractions = stats["retractions"] || 0
        total_evidence = stats["total_evidence"] || 0

        # Longevity factor: days since first appearance (capped at 365 for normalisation)
        longevity_days =
          case entity["first_appearance_date"] do
            nil -> 0
            date_str -> max(0, Date.diff(Date.utc_today(), Date.from_iso8601!(date_str)))
          end

        longevity_factor = min(longevity_days / 365.0, 1.0)

        # Consistency factor: corroborations vs contradictions
        total_relations = corroborations + contradictions
        consistency_factor =
          if total_relations > 0 do
            corroborations / total_relations
          else
            0.5
          end

        # Retraction impact: proportion of evidence retracted
        retraction_factor =
          if total_evidence > 0 do
            1.0 - retractions / total_evidence
          else
            1.0
          end

        # Weighted composite score
        score =
          (consistency_factor * 50.0 + retraction_factor * 30.0 + longevity_factor * 20.0)
          |> Float.round(2)
          |> max(0.0)
          |> min(100.0)

        {:ok,
         %{
           score: score,
           factors: %{
             longevity_days: longevity_days,
             longevity_factor: Float.round(longevity_factor, 3),
             consistency_factor: Float.round(consistency_factor, 3),
             retraction_factor: Float.round(retraction_factor, 3),
             corroborations: corroborations,
             contradictions: contradictions,
             retractions: retractions,
             total_evidence: total_evidence
           }
         }}

      {:ok, []} ->
        {:error, :not_found}

      error ->
        error
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  # Compute a credibility score from raw counts.
  #
  # Base score: 50.0
  # +5 per corroboration (capped at +30)
  # -10 per contradiction (capped at -30)
  # -15 per retraction (capped at -45)
  # +5 bonus if total_evidence > 5 (breadth of evidence)
  defp compute_credibility(corroborations, contradictions, retractions, total_evidence) do
    base = 50.0
    corroboration_bonus = min(corroborations * 5.0, 30.0)
    contradiction_penalty = min(contradictions * 10.0, 30.0)
    retraction_penalty = min(retractions * 15.0, 45.0)
    breadth_bonus = if total_evidence > 5, do: 5.0, else: 0.0

    (base + corroboration_bonus - contradiction_penalty - retraction_penalty + breadth_bonus)
    |> max(0.0)
    |> min(100.0)
    |> Float.round(2)
  end

  # Build a timeline from raw event maps, computing running credibility at each step.
  defp build_timeline(events) do
    {timeline, _state} =
      Enum.reduce(events, {[], %{corroborations: 0, contradictions: 0, retractions: 0, total: 0}},
        fn event, {acc, state} ->
          event_type = event["event"]

          new_state =
            case event_type do
              "corroboration" ->
                %{state | corroborations: state.corroborations + 1, total: state.total + 1}

              "contradiction" ->
                %{state | contradictions: state.contradictions + 1}

              "retraction" ->
                %{state | retractions: state.retractions + 1}

              "new_testimony" ->
                %{state | total: state.total + 1}

              _ ->
                state
            end

          current_score =
            compute_credibility(
              new_state.corroborations,
              new_state.contradictions,
              new_state.retractions,
              new_state.total
            )

          prev_score =
            case acc do
              [] -> 50.0
              [last | _] -> last.credibility
            end

          entry = %{
            date: event["date"],
            credibility: current_score,
            event: event_type,
            delta: Float.round(current_score - prev_score, 2)
          }

          {[entry | acc], new_state}
        end
      )

    Enum.reverse(timeline)
  end
end

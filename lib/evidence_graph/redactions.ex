# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
defmodule EvidenceGraph.Redactions do
  @moduledoc """
  Redaction Audit Trail for the Evidence Graph.

  Tracks redactions found in evidence documents (e.g. blacked-out text in
  government releases, censored interview transcripts).  Records the location,
  suspected content type, and any recovery attempts for each redaction.

  Redactions are stored in the ArangoDB `redactions` collection.

  ## Content Types

  Common suspected content types for redacted material:
  - `"name"` - A person or organisation name
  - `"date"` - A date or time reference
  - `"amount"` - A financial figure
  - `"location"` - A place name or address
  - `"classification"` - A security classification marking
  - `"other"` - Unclassified redacted content

  ## Recovery Methods

  - `"context_inference"` - Inferred from surrounding text
  - `"cross_reference"` - Recovered by cross-referencing other documents
  - `"foia_request"` - Obtained via a follow-up FOIA request
  - `"whistleblower"` - Provided by a source
  - `"none"` - No recovery attempted or possible
  """

  alias EvidenceGraph.ArangoDB

  @doc """
  Record a redaction found in an evidence item.

  ## Parameters

  - `evidence_id` - The `_key` of the evidence document containing the redaction
  - `redaction_info` - A map with the following keys:
    - `:page` (integer) - Page number where the redaction appears
    - `:position` (string) - Description or coordinates of the redaction location
    - `:suspected_content_type` (string) - What kind of content was redacted
    - `:recovery_method` (string, optional) - How the content was recovered
    - `:recovery_confidence` (float, optional) - Confidence in recovery (0.0..1.0)
    - `:recovered_text` (string, optional) - The recovered text, if any
    - `:notes` (string, optional) - Additional notes

  ## Returns

  `{:ok, redaction_doc}` or `{:error, reason}`
  """
  def record_redaction(evidence_id, redaction_info) when is_map(redaction_info) do
    document = %{
      _key: "red_" <> Ecto.UUID.generate(),
      evidence_id: evidence_id,
      page: redaction_info[:page] || redaction_info["page"],
      position: redaction_info[:position] || redaction_info["position"],
      suspected_content_type:
        redaction_info[:suspected_content_type] || redaction_info["suspected_content_type"],
      recovery_method:
        redaction_info[:recovery_method] || redaction_info["recovery_method"] || "none",
      recovery_confidence:
        redaction_info[:recovery_confidence] || redaction_info["recovery_confidence"] || 0.0,
      recovered_text:
        redaction_info[:recovered_text] || redaction_info["recovered_text"],
      notes: redaction_info[:notes] || redaction_info["notes"],
      created_at: DateTime.to_iso8601(DateTime.utc_now()),
      updated_at: DateTime.to_iso8601(DateTime.utc_now())
    }

    ArangoDB.insert("redactions", document)
  end

  @doc """
  List all redactions for a given evidence item, ordered by page then position.

  ## Returns

  `{:ok, [redaction_doc]}` or `{:error, reason}`
  """
  def list_redactions(evidence_id) do
    aql = """
    FOR red IN redactions
      FILTER red.evidence_id == @evidence_id
      SORT red.page ASC, red.position ASC
      RETURN red
    """

    ArangoDB.query_read(aql, %{evidence_id: evidence_id})
  end

  @doc """
  Aggregate redaction statistics for an entire investigation.

  ## Returns

  `{:ok, %{total: integer, by_type: map, recovery_rate: float, by_evidence: [map]}}`
  """
  def redaction_stats(investigation_id) do
    aql = """
    LET evidence_ids = (
      FOR ev IN evidence
        FILTER ev.investigation_id == @investigation_id
        RETURN ev._key
    )

    LET all_redactions = (
      FOR red IN redactions
        FILTER red.evidence_id IN evidence_ids
        RETURN red
    )

    LET total = LENGTH(all_redactions)

    LET by_type = (
      FOR red IN all_redactions
        COLLECT content_type = red.suspected_content_type
        WITH COUNT INTO cnt
        RETURN {type: content_type, count: cnt}
    )

    LET recovered = LENGTH(
      FOR red IN all_redactions
        FILTER red.recovery_method != "none"
        FILTER red.recovery_method != null
        RETURN 1
    )

    LET by_evidence = (
      FOR red IN all_redactions
        COLLECT eid = red.evidence_id
        WITH COUNT INTO cnt
        SORT cnt DESC
        RETURN {evidence_id: eid, redaction_count: cnt}
    )

    RETURN {
      total: total,
      by_type: by_type,
      recovered: recovered,
      by_evidence: by_evidence
    }
    """

    case ArangoDB.query_read(aql, %{investigation_id: investigation_id}) do
      {:ok, [result]} ->
        total = result["total"] || 0
        recovered = result["recovered"] || 0

        recovery_rate =
          if total > 0, do: Float.round(recovered / total, 3), else: 0.0

        {:ok,
         %{
           total: total,
           by_type: result["by_type"] || [],
           recovery_rate: recovery_rate,
           recovered_count: recovered,
           by_evidence: result["by_evidence"] || []
         }}

      {:ok, []} ->
        {:ok, %{total: 0, by_type: [], recovery_rate: 0.0, recovered_count: 0, by_evidence: []}}

      error ->
        error
    end
  end

  @doc """
  Plot redactions on a timeline by the date of the source document.

  Returns redaction counts grouped by document date, useful for
  visualising when redacted documents cluster in time.

  ## Returns

  `{:ok, [%{date: string, redaction_count: integer, evidence_ids: [string]}]}`
  """
  def redaction_timeline(investigation_id) do
    aql = """
    LET evidence_ids = (
      FOR ev IN evidence
        FILTER ev.investigation_id == @investigation_id
        RETURN ev._key
    )

    FOR red IN redactions
      FILTER red.evidence_id IN evidence_ids
      LET ev = FIRST(
        FOR e IN evidence
          FILTER e._key == red.evidence_id
          RETURN e
      )
      LET doc_date = ev.dublin_core.date != null ? ev.dublin_core.date : ev.inserted_at
      COLLECT date = doc_date INTO grouped
      SORT date ASC
      RETURN {
        date: date,
        redaction_count: LENGTH(grouped),
        evidence_ids: UNIQUE(grouped[*].red.evidence_id)
      }
    """

    ArangoDB.query_read(aql, %{investigation_id: investigation_id})
  end
end

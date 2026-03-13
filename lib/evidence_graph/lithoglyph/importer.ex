# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
defmodule EvidenceGraph.Lithoglyph.Importer do
  @moduledoc """
  GenServer for batch-importing evidence from Lithoglyph into the Bofig
  evidence graph (ArangoDB).

  This is the Bofig side of integration point B5 in the pipeline:

      Docudactyl → Lithoglyph → [this module] → ArangoDB evidence graph

  The importer:
  1. Queries Lithoglyph for new/updated evidence records
  2. Deduplicates by SHA-256 hash against existing ArangoDB records
  3. Maps Lithoglyph evidence to Bofig Evidence schema
  4. Inserts into ArangoDB with PROMPT scores preserved
  5. Broadcasts progress via PubSub for LiveView UI updates

  ## Starting

      # In application.ex children list:
      {EvidenceGraph.Lithoglyph.Importer, investigation_id: "epstein_files_2024"}

  ## Manual trigger

      EvidenceGraph.Lithoglyph.Importer.run_import("epstein_files_2024")
  """

  use GenServer
  require Logger

  alias EvidenceGraph.Lithoglyph.Client, as: LithClient
  alias EvidenceGraph.ArangoDB
  alias EvidenceGraph.Evidence

  @batch_size 100
  @progress_interval 50

  # -- Public API --

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Trigger an import run for the given investigation.

  Returns immediately. Progress is broadcast via PubSub on
  topic `"lithoglyph:import:<investigation_id>"`.
  """
  def run_import(investigation_id, opts \\ []) do
    GenServer.cast(__MODULE__, {:run_import, investigation_id, opts})
  end

  @doc """
  Get current import status.
  """
  def status do
    GenServer.call(__MODULE__, :status)
  end

  # -- GenServer callbacks --

  @impl true
  def init(opts) do
    state = %{
      status: :idle,
      investigation_id: Keyword.get(opts, :investigation_id),
      imported: 0,
      skipped: 0,
      failed: 0,
      total: 0,
      errors: [],
      started_at: nil
    }

    Logger.info("Lithoglyph Importer started")
    {:ok, state}
  end

  @impl true
  def handle_cast({:run_import, investigation_id, opts}, state) do
    if state.status == :importing do
      Logger.warning("Import already in progress, ignoring request")
      {:noreply, state}
    else
      new_state = %{
        state
        | status: :importing,
          investigation_id: investigation_id,
          imported: 0,
          skipped: 0,
          failed: 0,
          total: 0,
          errors: [],
          started_at: DateTime.utc_now()
      }

      # Run import in a Task to avoid blocking the GenServer
      run_id = Keyword.get(opts, :run_id, "import-#{System.unique_integer([:positive])}")
      send(self(), {:do_import, investigation_id, run_id})
      {:noreply, new_state}
    end
  end

  @impl true
  def handle_call(:status, _from, state) do
    {:reply, Map.take(state, [:status, :investigation_id, :imported, :skipped, :failed, :total, :started_at]), state}
  end

  @impl true
  def handle_info({:do_import, investigation_id, run_id}, state) do
    Logger.info("Starting Lithoglyph import for investigation=#{investigation_id} run=#{run_id}")

    new_state =
      case do_import(investigation_id, run_id, state) do
        {:ok, final_state} ->
          duration =
            DateTime.diff(DateTime.utc_now(), final_state.started_at, :second)

          Logger.info(
            "Import complete: #{final_state.imported} imported, #{final_state.skipped} skipped, " <>
              "#{final_state.failed} failed (#{duration}s)"
          )

          broadcast_progress(investigation_id, final_state, :complete)
          %{final_state | status: :idle}

        {:error, reason, partial_state} ->
          Logger.error("Import failed: #{inspect(reason)}")
          broadcast_progress(investigation_id, partial_state, :error)
          %{partial_state | status: :error}
      end

    {:noreply, new_state}
  end

  def handle_info(_msg, state), do: {:noreply, state}

  # -- Import logic --

  defp do_import(investigation_id, run_id, state) do
    # Step 1: Query Lithoglyph for evidence records
    fql = """
    SELECT * FROM bofig_evidence
    WHERE investigation_id = @investigation_id
    ORDER BY inserted_at ASC
    """

    case LithClient.query(fql, %{investigation_id: investigation_id}) do
      {:ok, records} when is_list(records) ->
        total = length(records)
        Logger.info("Found #{total} records in Lithoglyph for #{investigation_id}")

        state = %{state | total: total}
        broadcast_progress(investigation_id, state, :started)

        # Step 2: Process in batches
        final_state =
          records
          |> Enum.chunk_every(@batch_size)
          |> Enum.reduce(state, fn batch, acc ->
            process_batch(batch, investigation_id, run_id, acc)
          end)

        {:ok, final_state}

      {:ok, other} ->
        {:error, {:unexpected_response, other}, state}

      {:error, reason} ->
        {:error, reason, state}
    end
  end

  defp process_batch(records, investigation_id, run_id, state) do
    Enum.reduce(records, state, fn record, acc ->
      result = import_single_record(record, investigation_id, run_id)
      new_acc = update_counts(acc, result)

      # Broadcast progress periodically
      processed = new_acc.imported + new_acc.skipped + new_acc.failed

      if rem(processed, @progress_interval) == 0 do
        broadcast_progress(investigation_id, new_acc, :in_progress)
      end

      new_acc
    end)
  end

  defp import_single_record(record, investigation_id, _run_id) do
    sha256 = record["sha256_hash"]

    # Step 1: Dedup check against existing ArangoDB evidence
    case check_duplicate(sha256) do
      {:ok, :duplicate} ->
        {:skipped, sha256}

      {:ok, :new} ->
        # Step 2: Map Lithoglyph record to Bofig Evidence attrs
        attrs = map_lithoglyph_to_evidence(record, investigation_id)

        # Step 3: Create evidence in ArangoDB
        case Evidence.create_evidence(attrs) do
          {:ok, evidence} ->
            {:imported, evidence.id}

          {:error, reason} ->
            {:failed, sha256, reason}
        end

      {:error, reason} ->
        {:failed, sha256, reason}
    end
  end

  defp check_duplicate(nil), do: {:ok, :new}

  defp check_duplicate(sha256) do
    aql = """
    FOR e IN evidence
      FILTER e.sha256_hash == @hash
      LIMIT 1
      RETURN 1
    """

    case ArangoDB.query_read(aql, %{hash: sha256}) do
      {:ok, [_ | _]} -> {:ok, :duplicate}
      {:ok, []} -> {:ok, :new}
      error -> error
    end
  end

  defp map_lithoglyph_to_evidence(record, investigation_id) do
    # Map Lithoglyph evidence_type to Bofig evidence_type atom
    evidence_type = map_evidence_type(record["evidence_type"])

    %{
      investigation_id: investigation_id,
      title: record["title"] || "Untitled Evidence",
      evidence_type: evidence_type,
      source_url: record["url_source"],
      metadata: %{
        sha256_hash: record["sha256_hash"],
        perceptual_hash: record["perceptual_hash"],
        ocr_confidence: record["ocr_confidence"],
        language: record["language"],
        document_date: record["document_date"],
        redaction_status: record["redaction_status"],
        redaction_count: record["redaction_count"],
        extraction_run_id: record["extraction_run_id"],
        content_text: record["content_text"],
        sensitivity_level: record["sensitivity_level"],
        lithoglyph_id: record["_id"],
        imported_from: "lithoglyph"
      },
      dublin_core: record["dublin_core_metadata"] || %{},
      tags: record["keywords"] || [],
      prompt_scores: extract_prompt_scores(record)
    }
  end

  # Extract PROMPT scores from either nested promptScores object (Docudactyl format)
  # or flat prompt_* keys (legacy/direct Lithoglyph format), with defaults.
  defp extract_prompt_scores(record) do
    scores = record["promptScores"] || %{}

    %{
      provenance: scores["provenance"] || record["prompt_provenance"] || 50,
      replicability: scores["replicability"] || record["prompt_replicability"] || 50,
      objective: scores["objective"] || record["prompt_objective"] || 50,
      methodology: scores["methodology"] || record["prompt_methodology"] || 50,
      publication: scores["publication"] || record["prompt_publication"] || 50,
      transparency: scores["transparency"] || record["prompt_transparency"] || 50
    }
  end

  defp map_evidence_type("court_filing"), do: :document
  defp map_evidence_type("deposition"), do: :interview
  defp map_evidence_type("testimony"), do: :interview
  defp map_evidence_type("flight_log"), do: :document
  defp map_evidence_type("financial_record"), do: :dataset
  defp map_evidence_type("communication"), do: :document
  defp map_evidence_type("photograph"), do: :media
  defp map_evidence_type("video"), do: :media
  defp map_evidence_type("official_statistics"), do: :dataset
  defp map_evidence_type("news_report"), do: :document
  defp map_evidence_type("document"), do: :document
  defp map_evidence_type("dataset"), do: :dataset
  defp map_evidence_type("interview"), do: :interview
  defp map_evidence_type("affidavit"), do: :document
  defp map_evidence_type("subpoena"), do: :document
  defp map_evidence_type(_), do: :other

  defp update_counts(state, {:imported, _id}) do
    %{state | imported: state.imported + 1}
  end

  defp update_counts(state, {:skipped, _hash}) do
    %{state | skipped: state.skipped + 1}
  end

  defp update_counts(state, {:failed, hash, reason}) do
    error = %{sha256: hash, reason: inspect(reason)}
    %{state | failed: state.failed + 1, errors: [error | state.errors]}
  end

  defp broadcast_progress(investigation_id, state, phase) do
    Phoenix.PubSub.broadcast(
      EvidenceGraph.PubSub,
      "lithoglyph:import:#{investigation_id}",
      {:import_progress, %{
        phase: phase,
        imported: state.imported,
        skipped: state.skipped,
        failed: state.failed,
        total: state.total
      }}
    )
  end
end

# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
defmodule EvidenceGraph.Workers.ZoteroSync do
  @moduledoc """
  Oban worker for periodic Zotero synchronisation.

  Runs every 15 minutes (configured in `config/config.exs`) and performs
  incremental sync for all investigations that have Zotero-linked evidence.

  Can also be triggered manually:

      %{investigation_id: "inv_123"}
      |> EvidenceGraph.Workers.ZoteroSync.new()
      |> Oban.insert()

  When no `investigation_id` is provided, syncs all investigations that
  contain evidence with `zotero_key` fields.
  """

  use Oban.Worker, queue: :sync, max_attempts: 3

  require Logger

  alias EvidenceGraph.ArangoDB
  alias EvidenceGraph.Zotero.Sync

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"investigation_id" => investigation_id}}) do
    Logger.info("Zotero sync started for investigation #{investigation_id}")

    case Sync.incremental_sync(investigation_id) do
      {:ok, results} ->
        Logger.info("Zotero sync completed: #{inspect(results)}")
        :ok

      {:error, reason} ->
        Logger.error("Zotero sync failed for #{investigation_id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    Logger.info("Zotero sync started for all investigations")

    case list_investigations_with_zotero() do
      {:ok, investigation_ids} ->
        results =
          Enum.map(investigation_ids, fn inv_id ->
            case Sync.incremental_sync(inv_id) do
              {:ok, result} -> {:ok, inv_id, result}
              {:error, reason} -> {:error, inv_id, reason}
            end
          end)

        failed = Enum.filter(results, &match?({:error, _, _}, &1))

        if Enum.empty?(failed) do
          Logger.info("Zotero sync completed for #{length(investigation_ids)} investigations")
          :ok
        else
          Logger.warning("Zotero sync: #{length(failed)}/#{length(investigation_ids)} failed")
          :ok
        end

      {:error, reason} ->
        Logger.error("Failed to list investigations for Zotero sync: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp list_investigations_with_zotero do
    aql = """
    FOR evidence IN evidence
      FILTER evidence.zotero_key != null
      COLLECT investigation_id = evidence.investigation_id
      RETURN investigation_id
    """

    ArangoDB.query_read(aql, %{})
  end
end

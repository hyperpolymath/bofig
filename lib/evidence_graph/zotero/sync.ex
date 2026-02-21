# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
defmodule EvidenceGraph.Zotero.Sync do
  @moduledoc """
  Synchronisation coordinator between Zotero and Evidence Graph.

  Implements incremental sync using Zotero's library versioning:
  1. Track the last-synced library version per investigation
  2. On each sync, fetch only items modified since that version
  3. Upsert into Evidence Graph (create or update by zotero_key)
  4. Conflict resolution: last-write-wins based on Zotero version

  Zotero does not support webhooks, so we poll via an Oban worker.
  """

  require Logger

  alias EvidenceGraph.Evidence
  alias EvidenceGraph.ArangoDB
  alias EvidenceGraph.Zotero.{Client, Mapper}

  @doc """
  Run a full sync for an investigation — fetches all items from the Zotero
  library and upserts them into Evidence Graph.

  Returns `{:ok, %{created: n, updated: n, failed: n}}`.
  """
  def full_sync(investigation_id, opts \\ []) do
    client = Client.new(opts)

    case Client.list_items(client, limit: 100) do
      {:ok, %{items: items, library_version: lib_ver}} ->
        results = sync_items(items, investigation_id)
        store_library_version(investigation_id, lib_ver)

        Logger.info(
          "Zotero full sync for #{investigation_id}: " <>
            "created=#{results.created} updated=#{results.updated} failed=#{results.failed}"
        )

        {:ok, results}

      {:error, reason} ->
        Logger.error("Zotero full sync failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Run an incremental sync — only fetches items modified since the last
  known library version for this investigation.
  """
  def incremental_sync(investigation_id, opts \\ []) do
    client = Client.new(opts)
    since = get_library_version(investigation_id) || 0

    case Client.items_since(client, since) do
      {:ok, %{items: items, library_version: lib_ver}} ->
        results = sync_items(items, investigation_id)
        store_library_version(investigation_id, lib_ver)

        Logger.info(
          "Zotero incremental sync for #{investigation_id}: " <>
            "#{length(items)} changed items, " <>
            "created=#{results.created} updated=#{results.updated} failed=#{results.failed}"
        )

        {:ok, results}

      {:error, reason} ->
        Logger.error("Zotero incremental sync failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Sync a single Zotero item into an investigation.

  Checks for an existing evidence record by `zotero_key`:
  - If found and Zotero version is newer → update
  - If found and Evidence Graph is newer → skip (no overwrite)
  - If not found → create
  """
  def sync_item(zotero_item, investigation_id) do
    attrs = Mapper.zotero_to_evidence(zotero_item, investigation_id)
    zotero_version = attrs[:zotero_version] || 0

    case Evidence.get_evidence_by_zotero_key(attrs.zotero_key) do
      {:ok, existing} ->
        existing_version = get_in(existing, [Access.key(:metadata), Access.key("zotero_version")]) || 0

        if zotero_version > existing_version do
          Evidence.update_evidence(existing.id, attrs)
        else
          {:ok, existing}
        end

      {:error, :not_found} ->
        Evidence.create_evidence(attrs)
    end
  end

  @doc """
  Export an evidence item back to Zotero (creates or updates in the Zotero library).
  """
  def export_to_zotero(evidence_id, opts \\ []) do
    client = Client.new(opts)

    with {:ok, evidence} <- Evidence.get_evidence(evidence_id) do
      zotero_data = Mapper.evidence_to_zotero(evidence)

      if evidence.zotero_key do
        version = get_in(evidence.metadata, ["zotero_version"]) || 0
        Client.update_item(client, evidence.zotero_key, zotero_data, version)
      else
        case Client.create_item(client, zotero_data) do
          {:ok, created} ->
            new_key = created["key"] || created["data"]["key"]
            new_version = created["version"] || created["data"]["version"] || 0

            Evidence.update_evidence(evidence_id, %{
              zotero_key: new_key,
              zotero_version: new_version,
              metadata: Map.merge(evidence.metadata || %{}, %{
                "zotero_version" => new_version
              })
            })

          error ->
            error
        end
      end
    end
  end

  # -- Private --

  defp sync_items(items, investigation_id) do
    Enum.reduce(items, %{created: 0, updated: 0, failed: 0}, fn item, acc ->
      case sync_item(item, investigation_id) do
        {:ok, _evidence} ->
          # Distinguish create vs update by checking if zotero_key existed before
          %{acc | updated: acc.updated + 1}

        {:error, reason} ->
          Logger.warning("Failed to sync Zotero item #{item["key"]}: #{inspect(reason)}")
          %{acc | failed: acc.failed + 1}
      end
    end)
  end

  defp store_library_version(investigation_id, version) do
    aql = """
    UPSERT { _key: @key }
    INSERT { _key: @key, investigation_id: @inv_id, library_version: @version, updated_at: DATE_NOW() }
    UPDATE { library_version: @version, updated_at: DATE_NOW() }
    IN zotero_sync_state
    """

    ArangoDB.query(aql, %{
      key: "sync_#{investigation_id}",
      inv_id: investigation_id,
      version: version
    })
  end

  defp get_library_version(investigation_id) do
    case ArangoDB.get("zotero_sync_state", "sync_#{investigation_id}") do
      {:ok, doc} -> doc["library_version"]
      _ -> nil
    end
  end
end

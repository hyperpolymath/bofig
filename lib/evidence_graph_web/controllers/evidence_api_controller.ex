# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
defmodule EvidenceGraphWeb.EvidenceApiController do
  @moduledoc """
  REST API controller for Zotero evidence import/export.

  Provides endpoints for:
  - Importing single or batched Zotero items into the Evidence Graph
  - Exporting evidence back to Zotero-compatible JSON
  - Querying sync state for an investigation

  Authentication is via the `x-api-key` header. When `Application.get_env(:evidence_graph,
  :api_key)` is nil (i.e. not configured), API key validation is skipped — this is intended
  for development mode only.
  """

  use EvidenceGraphWeb, :controller

  alias EvidenceGraph.Evidence
  alias EvidenceGraph.ArangoDB
  alias EvidenceGraph.Zotero.Sync

  action_fallback :handle_fallback

  # -- Plugs --

  plug :validate_api_key when action in [:import, :batch_import, :lithoglyph_import]

  # -- Actions --

  @doc """
  POST /api/evidence/import

  Accepts a single Zotero item JSON in the request body, syncs it into the
  Evidence Graph for the given investigation, and returns the created/updated
  evidence record.

  ## Request

      POST /api/evidence/import
      Content-Type: application/json
      x-api-key: <configured API key>

      {
        "investigation_id": "inv_uk_inflation_2023",
        "item": { <Zotero item JSON> }
      }

  ## Response (201 Created)

      {
        "data": { <evidence record> }
      }
  """
  def import(conn, %{"investigation_id" => investigation_id, "item" => zotero_item}) do
    case Sync.sync_item(zotero_item, investigation_id) do
      {:ok, evidence} ->
        conn
        |> put_status(:created)
        |> json(%{data: serialize_evidence(evidence)})

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: format_changeset_errors(changeset)})

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: %{detail: inspect(reason)}})
    end
  end

  def import(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{errors: %{detail: "Missing required fields: investigation_id, item"}})
  end

  @doc """
  GET /api/evidence/:id/export

  Fetches a single evidence record by ID and returns it in Zotero-compatible
  JSON format.

  ## Response (200 OK)

      {
        "data": { <Zotero-format JSON> }
      }
  """
  def export(conn, %{"id" => id}) do
    case Evidence.export_to_zotero(id) do
      {:ok, zotero_json} ->
        conn
        |> put_status(:ok)
        |> json(%{data: zotero_json})

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{errors: %{detail: "Evidence not found"}})

      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{errors: %{detail: inspect(reason)}})
    end
  end

  @doc """
  POST /api/evidence/batch-import

  Accepts an array of Zotero items and imports them all into the Evidence Graph.

  ## Request

      POST /api/evidence/batch-import
      Content-Type: application/json
      x-api-key: <configured API key>

      {
        "investigation_id": "inv_uk_inflation_2023",
        "items": [ { <Zotero item> }, ... ]
      }

  ## Response (200 OK)

      {
        "data": {
          "total": 5,
          "succeeded": 4,
          "failed": 1,
          "results": [ { "key": "ZKEY1", "status": "ok", "id": "evidence_..." }, ... ],
          "errors": [ { "key": "ZKEY2", "status": "error", "reason": "..." } ]
        }
      }
  """
  def batch_import(conn, %{"investigation_id" => investigation_id, "items" => items})
      when is_list(items) do
    {results, errors} =
      items
      |> Enum.map(fn item ->
        item_key = item["key"] || item["data"]["key"] || "unknown"

        case Sync.sync_item(item, investigation_id) do
          {:ok, evidence} ->
            {:ok, %{key: item_key, status: "ok", id: evidence.id}}

          {:error, reason} ->
            {:error, %{key: item_key, status: "error", reason: inspect(reason)}}
        end
      end)
      |> Enum.split_with(fn
        {:ok, _} -> true
        {:error, _} -> false
      end)

    succeeded = Enum.map(results, fn {:ok, r} -> r end)
    failed = Enum.map(errors, fn {:error, e} -> e end)

    conn
    |> put_status(:ok)
    |> json(%{
      data: %{
        total: length(items),
        succeeded: length(succeeded),
        failed: length(failed),
        results: succeeded,
        errors: failed
      }
    })
  end

  def batch_import(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{errors: %{detail: "Missing required fields: investigation_id, items (array)"}})
  end

  @doc """
  GET /api/investigations/:id/sync-status

  Returns the Zotero sync state for an investigation, including the last
  synced library version and timestamp.

  ## Response (200 OK)

      {
        "data": {
          "investigation_id": "inv_uk_inflation_2023",
          "library_version": 42,
          "updated_at": "2026-02-21T10:30:00Z",
          "evidence_count": 30
        }
      }
  """
  def sync_status(conn, %{"id" => investigation_id}) do
    sync_state = get_sync_state(investigation_id)
    evidence_count = get_evidence_count(investigation_id)

    conn
    |> put_status(:ok)
    |> json(%{
      data: %{
        investigation_id: investigation_id,
        library_version: sync_state[:library_version],
        updated_at: sync_state[:updated_at],
        evidence_count: evidence_count
      }
    })
  end

  @doc """
  POST /api/evidence/lithoglyph-import

  Triggers a batch import of evidence from Lithoglyph into the Bofig evidence
  graph. Returns immediately — progress is broadcast via PubSub.

  ## Request

      POST /api/evidence/lithoglyph-import
      Content-Type: application/json
      x-api-key: <configured API key>

      {
        "investigation_id": "epstein_files_2024",
        "run_id": "import-2026-03-13"
      }

  ## Response (202 Accepted)

      {
        "data": {
          "status": "started",
          "investigation_id": "epstein_files_2024",
          "run_id": "import-2026-03-13"
        }
      }
  """
  def lithoglyph_import(conn, %{"investigation_id" => investigation_id} = params) do
    run_id = params["run_id"] || "import-#{System.unique_integer([:positive])}"

    EvidenceGraph.Lithoglyph.Importer.run_import(investigation_id, run_id: run_id)

    conn
    |> put_status(:accepted)
    |> json(%{
      data: %{
        status: "started",
        investigation_id: investigation_id,
        run_id: run_id
      }
    })
  end

  def lithoglyph_import(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{errors: %{detail: "Missing required field: investigation_id"}})
  end

  @doc """
  GET /api/evidence/lithoglyph-import/status

  Returns the current status of the Lithoglyph importer.

  ## Response (200 OK)

      {
        "data": {
          "status": "importing",
          "investigation_id": "epstein_files_2024",
          "imported": 5000,
          "skipped": 200,
          "failed": 3,
          "total": 10000,
          "started_at": "2026-03-13T10:30:00Z"
        }
      }
  """
  def lithoglyph_import_status(conn, _params) do
    status = EvidenceGraph.Lithoglyph.Importer.status()

    conn
    |> put_status(:ok)
    |> json(%{data: status})
  end

  # -- Private helpers --

  defp validate_api_key(conn, _opts) do
    configured_key = Application.get_env(:evidence_graph, :api_key)

    cond do
      # Dev mode: no API key configured, skip validation
      is_nil(configured_key) ->
        conn

      # API key present and matches
      get_req_header(conn, "x-api-key") == [configured_key] ->
        conn

      # API key missing or invalid
      true ->
        conn
        |> put_status(:unauthorized)
        |> json(%{errors: %{detail: "Invalid or missing API key"}})
        |> halt()
    end
  end

  defp serialize_evidence(evidence) do
    %{
      id: evidence.id,
      investigation_id: evidence.investigation_id,
      title: evidence.title,
      evidence_type: to_string(evidence.evidence_type),
      source_url: evidence.source_url,
      sha256_hash: Map.get(evidence, :sha256_hash),
      zotero_key: evidence.zotero_key,
      zotero_version: evidence.zotero_version,
      tags: evidence.tags,
      dublin_core: evidence.dublin_core,
      schema_org: evidence.schema_org,
      metadata: evidence.metadata,
      inserted_at: evidence.inserted_at,
      updated_at: evidence.updated_at
    }
  end

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end

  defp get_sync_state(investigation_id) do
    case ArangoDB.get("zotero_sync_state", "sync_#{investigation_id}") do
      {:ok, doc} ->
        %{
          library_version: doc["library_version"],
          updated_at: doc["updated_at"]
        }

      _ ->
        %{library_version: nil, updated_at: nil}
    end
  rescue
    _ -> %{library_version: nil, updated_at: nil}
  end

  defp get_evidence_count(investigation_id) do
    aql = """
    RETURN LENGTH(
      FOR e IN evidence
        FILTER e.investigation_id == @investigation_id
        RETURN 1
    )
    """

    case ArangoDB.query_read(aql, %{investigation_id: investigation_id}) do
      {:ok, [count]} -> count
      _ -> 0
    end
  end

  defp handle_fallback(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> json(%{errors: %{detail: "Not found"}})
  end

  defp handle_fallback(conn, {:error, reason}) do
    conn
    |> put_status(:internal_server_error)
    |> json(%{errors: %{detail: inspect(reason)}})
  end
end

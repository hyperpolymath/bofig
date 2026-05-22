# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
defmodule EvidenceGraphWeb.ExportController do
  @moduledoc """
  REST controller for multi-format evidence graph export.

  Provides endpoints for exporting investigation data as Zotero JSON, CSV,
  IIIF manifests, GraphML, and JSON-LD.

  All endpoints require the `:public_api` pipeline (API key authentication).
  """

  use EvidenceGraphWeb, :controller

  alias EvidenceGraph.Export

  action_fallback :handle_fallback

  @doc """
  GET /api/export/:investigation_id/zotero

  Export all evidence in an investigation as Zotero-compatible JSON.
  """
  def zotero(conn, %{"investigation_id" => investigation_id}) do
    case Export.export_zotero(investigation_id) do
      {:ok, items} ->
        conn
        |> put_status(:ok)
        |> json(%{data: items})

      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{errors: %{detail: inspect(reason)}})
    end
  end

  @doc """
  GET /api/export/:investigation_id/csv/:collection

  Export a collection within an investigation as CSV.

  Supported collections: evidence, claims, entities, financial_transactions
  """
  def csv(conn, %{"investigation_id" => investigation_id, "collection" => collection}) do
    case Export.export_csv(investigation_id, collection) do
      {:ok, csv_string} ->
        conn
        |> put_resp_content_type("text/csv")
        |> put_resp_header(
          "content-disposition",
          "attachment; filename=\"#{investigation_id}_#{collection}.csv\""
        )
        |> send_resp(200, csv_string)

      {:error, {:unsupported_collection, _col, valid}} ->
        conn
        |> put_status(:bad_request)
        |> json(%{
          errors: %{
            detail: "Unsupported collection: #{collection}. Valid: #{inspect(valid)}"
          }
        })

      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{errors: %{detail: inspect(reason)}})
    end
  end

  @doc """
  GET /api/export/:investigation_id/iiif

  Generate a IIIF Presentation API 3.0 manifest for image-based evidence.
  """
  def iiif(conn, %{"investigation_id" => investigation_id}) do
    case Export.export_iiif_manifest(investigation_id) do
      {:ok, manifest} ->
        conn
        |> put_resp_content_type("application/ld+json")
        |> put_resp_header("access-control-allow-origin", "*")
        |> json(manifest)

      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{errors: %{detail: inspect(reason)}})
    end
  end

  @doc """
  GET /api/export/:investigation_id/graphml

  Export the full investigation graph as GraphML XML.
  """
  def graphml(conn, %{"investigation_id" => investigation_id}) do
    case Export.export_graphml(investigation_id) do
      {:ok, xml} ->
        conn
        |> put_resp_content_type("application/xml")
        |> put_resp_header(
          "content-disposition",
          "attachment; filename=\"#{investigation_id}.graphml\""
        )
        |> send_resp(200, xml)

      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{errors: %{detail: inspect(reason)}})
    end
  end

  @doc """
  GET /api/export/:investigation_id/json-ld

  Export the investigation as JSON-LD with Schema.org vocabulary.
  """
  def json_ld(conn, %{"investigation_id" => investigation_id}) do
    case Export.export_json_ld(investigation_id) do
      {:ok, json_ld} ->
        conn
        |> put_resp_content_type("application/ld+json")
        |> json(json_ld)

      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{errors: %{detail: inspect(reason)}})
    end
  end

  # ---------------------------------------------------------------------------
  # Fallback
  # ---------------------------------------------------------------------------

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

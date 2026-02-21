# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
defmodule EvidenceGraphWeb.EvidenceApiControllerTest do
  @moduledoc """
  Tests for the Zotero evidence REST API controller.

  These tests exercise the import, export, batch-import, and sync-status
  endpoints against a live ArangoDB test database.
  """

  use EvidenceGraphWeb.ConnCase

  setup do
    # Ensure no api_key is configured for each test (dev mode — no auth)
    Application.delete_env(:evidence_graph, :api_key)
    on_exit(fn -> Application.delete_env(:evidence_graph, :api_key) end)
    :ok
  end

  @valid_zotero_item %{
    "key" => "ZTEST001",
    "version" => 7,
    "library" => %{"id" => 12345},
    "data" => %{
      "key" => "ZTEST001",
      "version" => 7,
      "itemType" => "journalArticle",
      "title" => "Distributional Impact of UK Inflation",
      "url" => "https://doi.org/10.1234/test",
      "date" => "2023-06-15",
      "creators" => [
        %{"firstName" => "Jane", "lastName" => "Smith"}
      ],
      "tags" => [
        %{"tag" => "inflation"},
        %{"tag" => "UK economy"}
      ],
      "collections" => [],
      "dateModified" => "2026-01-10T08:30:00Z"
    }
  }

  @valid_zotero_dataset %{
    "key" => "ZTEST002",
    "version" => 3,
    "data" => %{
      "key" => "ZTEST002",
      "version" => 3,
      "itemType" => "dataset",
      "title" => "CPI Microdata 2020-2023",
      "url" => "https://example.org/data",
      "date" => "2023-12-01",
      "creators" => [%{"name" => "ONS"}],
      "tags" => [%{"tag" => "CPI"}],
      "collections" => [],
      "dateModified" => "2026-01-05T12:00:00Z"
    }
  }

  @investigation_id "inv_uk_inflation_2023"

  # -- POST /api/evidence/import --

  describe "POST /api/evidence/import" do
    test "returns 201 with valid Zotero JSON", %{conn: conn} do
      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post(~p"/api/evidence/import", %{
          "investigation_id" => @investigation_id,
          "item" => @valid_zotero_item
        })

      assert %{"data" => data} = json_response(conn, 201)
      assert data["title"] == "Distributional Impact of UK Inflation"
      assert is_binary(data["id"])
    end

    test "returns 401 without API key when API key is configured", %{conn: conn} do
      Application.put_env(:evidence_graph, :api_key, "test-secret-key-12345")

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post(~p"/api/evidence/import", %{
          "investigation_id" => @investigation_id,
          "item" => @valid_zotero_item
        })

      assert %{"errors" => %{"detail" => detail}} = json_response(conn, 401)
      assert detail =~ "Invalid or missing API key"
    end

    test "returns 201 with valid API key when API key is configured", %{conn: conn} do
      Application.put_env(:evidence_graph, :api_key, "test-secret-key-12345")

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> put_req_header("x-api-key", "test-secret-key-12345")
        |> post(~p"/api/evidence/import", %{
          "investigation_id" => @investigation_id,
          "item" => @valid_zotero_item
        })

      assert %{"data" => data} = json_response(conn, 201)
      assert data["title"] == "Distributional Impact of UK Inflation"
    end

    test "returns 400 with missing required fields", %{conn: conn} do
      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post(~p"/api/evidence/import", %{"unrelated" => "data"})

      assert %{"errors" => %{"detail" => detail}} = json_response(conn, 400)
      assert detail =~ "Missing required fields"
    end
  end

  # -- GET /api/evidence/:id/export --

  describe "GET /api/evidence/:id/export" do
    test "returns Zotero JSON for a valid evidence ID", %{conn: conn} do
      # First, import an item so we have something to export
      import_conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post(~p"/api/evidence/import", %{
          "investigation_id" => @investigation_id,
          "item" => @valid_zotero_item
        })

      %{"data" => %{"id" => evidence_id}} = json_response(import_conn, 201)

      # Now export it
      export_conn = get(conn, ~p"/api/evidence/#{evidence_id}/export")

      assert %{"data" => zotero_data} = json_response(export_conn, 200)
      assert zotero_data["title"] == "Distributional Impact of UK Inflation"
    end

    test "returns 404 for a nonexistent evidence ID", %{conn: conn} do
      conn = get(conn, ~p"/api/evidence/nonexistent_id_999/export")

      assert %{"errors" => %{"detail" => detail}} = json_response(conn, 404)
      assert detail =~ "not found"
    end
  end

  # -- POST /api/evidence/batch-import --

  describe "POST /api/evidence/batch-import" do
    test "returns 200 with results summary for valid batch", %{conn: conn} do
      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post(~p"/api/evidence/batch-import", %{
          "investigation_id" => @investigation_id,
          "items" => [@valid_zotero_item, @valid_zotero_dataset]
        })

      assert %{"data" => data} = json_response(conn, 200)
      assert data["total"] == 2
      assert data["succeeded"] == 2
      assert data["failed"] == 0
      assert is_list(data["results"])
      assert length(data["results"]) == 2
    end

    test "returns 400 when items field is missing", %{conn: conn} do
      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post(~p"/api/evidence/batch-import", %{
          "investigation_id" => @investigation_id
        })

      assert %{"errors" => %{"detail" => detail}} = json_response(conn, 400)
      assert detail =~ "Missing required fields"
    end

    test "returns 400 when investigation_id is missing", %{conn: conn} do
      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post(~p"/api/evidence/batch-import", %{
          "items" => [@valid_zotero_item]
        })

      assert %{"errors" => %{"detail" => detail}} = json_response(conn, 400)
      assert detail =~ "Missing required fields"
    end
  end

  # -- GET /api/investigations/:id/sync-status --

  describe "GET /api/investigations/:id/sync-status" do
    test "returns sync status for an investigation", %{conn: conn} do
      conn = get(conn, ~p"/api/investigations/#{@investigation_id}/sync-status")

      assert %{"data" => data} = json_response(conn, 200)
      assert data["investigation_id"] == @investigation_id
      assert Map.has_key?(data, "library_version")
      assert Map.has_key?(data, "updated_at")
      assert Map.has_key?(data, "evidence_count")
    end

    test "returns null sync state for an investigation that has never synced", %{conn: conn} do
      conn = get(conn, ~p"/api/investigations/inv_never_synced_999/sync-status")

      assert %{"data" => data} = json_response(conn, 200)
      assert data["investigation_id"] == "inv_never_synced_999"
      assert is_nil(data["library_version"])
      assert is_nil(data["updated_at"])
    end
  end
end

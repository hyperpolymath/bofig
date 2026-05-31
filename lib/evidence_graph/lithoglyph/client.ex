# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
defmodule EvidenceGraph.Lithoglyph.Client do
  @moduledoc """
  HTTP client for Lithoglyph — the audit-grade provenance database.

  Communicates with Lithoglyph's REST/GQL API to insert, query, and manage
  evidence records with full provenance tracking (actor + rationale on every
  mutation) and PROMPT scoring.

  ## Configuration

      config :evidence_graph, EvidenceGraph.Lithoglyph.Client,
        base_url: "http://localhost:8080",
        api_key: System.fetch_env!("LITHOGLYPH_API_KEY"),
        timeout: 30_000
  """

  require Logger

  @default_timeout 30_000

  @doc """
  Insert an evidence record into a Lithoglyph collection.

  Every insert requires an actor and rationale (Lithoglyph invariant).

  ## Examples

      iex> insert("bofig_evidence", %{title: "Flight Log"}, actor: "docudactyl-pipeline", rationale: "Batch run 001")
      {:ok, %{"_id" => "bofig_evidence/ev_123", ...}}
  """
  def insert(collection, document, opts \\ []) do
    actor = Keyword.fetch!(opts, :actor)
    rationale = Keyword.fetch!(opts, :rationale)

    body = %{
      collection: collection,
      document: document,
      provenance: %{
        actor: actor,
        rationale: rationale,
        timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
      }
    }

    post("/api/v1/collections/#{collection}/documents", body)
  end

  @doc """
  Batch insert multiple documents into a Lithoglyph collection.

  Returns a summary with succeeded/failed counts and individual results.

  ## Examples

      iex> batch_insert("bofig_evidence", [doc1, doc2, ...], actor: "docudactyl-pipeline", rationale: "Batch run 001")
      {:ok, %{total: 100, succeeded: 99, failed: 1, results: [...], errors: [...]}}
  """
  def batch_insert(collection, documents, opts \\ []) do
    actor = Keyword.fetch!(opts, :actor)
    rationale = Keyword.fetch!(opts, :rationale)

    body = %{
      collection: collection,
      documents: documents,
      provenance: %{
        actor: actor,
        rationale: rationale,
        timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
      }
    }

    post("/api/v1/collections/#{collection}/documents/batch", body)
  end

  @doc """
  Query a Lithoglyph collection using FQL.

  ## Examples

      iex> query("SELECT * FROM bofig_evidence WHERE sha256_hash = @hash", %{hash: "abc123..."})
      {:ok, [%{...}, ...]}
  """
  def query(fql, vars \\ %{}) do
    body = %{query: fql, bind_vars: vars}
    post("/api/v1/query", body)
  end

  @doc """
  Check if a document with the given SHA-256 hash already exists (dedup).

  ## Examples

      iex> exists_by_hash?("bofig_evidence", "a1b2c3d4...")
      true
  """
  def exists_by_hash?(collection, sha256_hash) do
    fql = """
    SELECT COUNT(*) as cnt FROM #{collection}
    WHERE sha256_hash = @hash
    """

    case query(fql, %{hash: sha256_hash}) do
      {:ok, [%{"cnt" => count}]} when count > 0 -> true
      _ -> false
    end
  end

  @doc """
  Health check — verify Lithoglyph is reachable.
  """
  def health_check do
    case get("/health") do
      {:ok, %{"status" => "ok"}} -> :ok
      {:ok, resp} -> {:error, {:unexpected_response, resp}}
      error -> error
    end
  end

  # -- HTTP helpers --

  defp get(path) do
    url = base_url() <> path

    case Req.get(url, headers: auth_headers(), receive_timeout: timeout()) do
      {:ok, %Req.Response{status: status, body: body}} when status in 200..299 ->
        {:ok, body}

      {:ok, %Req.Response{status: status, body: body}} ->
        Logger.warning("Lithoglyph GET #{path} returned #{status}: #{inspect(body)}")
        {:error, {:http_error, status, body}}

      {:error, reason} ->
        Logger.error("Lithoglyph GET #{path} failed: #{inspect(reason)}")
        {:error, {:connection_error, reason}}
    end
  end

  defp post(path, body) do
    url = base_url() <> path

    case Req.post(url, json: body, headers: auth_headers(), receive_timeout: timeout()) do
      {:ok, %Req.Response{status: status, body: resp_body}} when status in 200..299 ->
        {:ok, resp_body}

      {:ok, %Req.Response{status: status, body: resp_body}} ->
        Logger.warning("Lithoglyph POST #{path} returned #{status}: #{inspect(resp_body)}")
        {:error, {:http_error, status, resp_body}}

      {:error, reason} ->
        Logger.error("Lithoglyph POST #{path} failed: #{inspect(reason)}")
        {:error, {:connection_error, reason}}
    end
  end

  defp config do
    Application.get_env(:evidence_graph, __MODULE__, [])
  end

  defp base_url do
    Keyword.get(config(), :base_url, "http://localhost:8080")
  end

  defp timeout do
    Keyword.get(config(), :timeout, @default_timeout)
  end

  defp auth_headers do
    case Keyword.get(config(), :api_key) do
      nil -> [{"content-type", "application/json"}]
      key -> [{"content-type", "application/json"}, {"x-api-key", key}]
    end
  end
end

# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
defmodule EvidenceGraph.ArangoDB do
  @moduledoc """
  ArangoDB connection and query interface.

  Provides a connection pool and helper functions for interacting with ArangoDB.
  Uses VelocyStream protocol (default Arangox transport) with DBConnection pooling.
  """

  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    # Convert flat username/password config into Arangox :auth tuple
    auth =
      case Keyword.get(opts, :auth) do
        nil ->
          username = Keyword.get(opts, :username, "root")
          password = Keyword.get(opts, :password, "")
          {:basic, username, password}

        auth ->
          auth
      end

    arangox_opts =
      opts
      |> Keyword.drop([:username, :password])
      |> Keyword.put(:auth, auth)
      |> Keyword.put_new(:name, Arangox)

    children = [
      {Arangox, arangox_opts}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  @doc """
  Execute an AQL query with parameters (read-write transaction).

  ## Examples

      iex> query("FOR c IN claims FILTER c._key == @key RETURN c", %{key: "claim_1"})
      {:ok, [%{"_key" => "claim_1", ...}]}
  """
  def query(aql, vars \\ %{}) do
    Arangox.transaction(
      Arangox,
      fn cursor ->
        stream = Arangox.cursor(cursor, aql, vars)

        Enum.reduce(stream, [], fn resp, acc ->
          acc ++ resp.body["result"]
        end)
      end,
      write: ["claims", "evidence", "relationships", "investigations", "navigation_paths", "entities", "financial_transactions", "access_grants", "investigation_links", "annotations", "redactions", "provenance_log", "api_keys"]
    )
  end

  @doc """
  Execute a read-only query (more efficient).
  """
  def query_read(aql, vars \\ %{}) do
    Arangox.transaction(
      Arangox,
      fn cursor ->
        stream = Arangox.cursor(cursor, aql, vars)

        Enum.reduce(stream, [], fn resp, acc ->
          acc ++ resp.body["result"]
        end)
      end,
      read: ["claims", "evidence", "relationships", "investigations", "navigation_paths", "entities", "financial_transactions", "access_grants", "investigation_links", "annotations", "redactions", "provenance_log", "api_keys"]
    )
  end

  @doc """
  Insert a document into a collection.

  ## Examples

      iex> insert("claims", %{text: "Test claim", investigation_id: "inv_1"})
      {:ok, %{"_key" => "...", "_id" => "claims/...", ...}}
  """
  def insert(collection, document) do
    aql = """
    INSERT @document INTO @@collection
    RETURN NEW
    """

    case query(aql, %{document: document, "@collection": collection}) do
      {:ok, [doc]} -> {:ok, doc}
      {:ok, []} -> {:error, :insert_failed}
      error -> error
    end
  end

  @doc """
  Update a document by key.
  """
  def update(collection, key, updates) do
    aql = """
    UPDATE @key WITH @updates IN @@collection
    RETURN NEW
    """

    case query(aql, %{key: key, updates: updates, "@collection": collection}) do
      {:ok, [doc]} -> {:ok, doc}
      {:ok, []} -> {:error, :not_found}
      error -> error
    end
  end

  @doc """
  Get a document by key.
  """
  def get(collection, key) do
    aql = """
    FOR doc IN @@collection
      FILTER doc._key == @key
      LIMIT 1
      RETURN doc
    """

    case query_read(aql, %{key: key, "@collection": collection}) do
      {:ok, [doc]} -> {:ok, doc}
      {:ok, []} -> {:error, :not_found}
      error -> error
    end
  end

  @doc """
  Delete a document by key.
  """
  def delete(collection, key) do
    aql = """
    REMOVE @key IN @@collection
    RETURN OLD
    """

    case query(aql, %{key: key, "@collection": collection}) do
      {:ok, [doc]} -> {:ok, doc}
      {:ok, []} -> {:error, :not_found}
      error -> error
    end
  end

  @doc """
  Create collections and indexes for Evidence Graph.
  Run this once during setup.
  """
  def setup_database do
    with :ok <- create_collections(),
         :ok <- create_indexes() do
      EvidenceGraph.Search.setup_search_views()
    end
  end

  @doc """
  Create the target database if it does not exist.

  Connects to the _system database via a temporary connection to issue
  the CREATE DATABASE request. Must be called before the main pool starts
  (or via a Mix task).
  """
  def ensure_database(opts) do
    database = Keyword.get(opts, :database, "evidence_graph")

    # Extract auth from either :auth tuple or legacy :username/:password
    auth =
      case Keyword.get(opts, :auth) do
        {:basic, _u, _p} = a -> a
        _ -> {:basic, Keyword.get(opts, :username, "root"), Keyword.get(opts, :password, "")}
      end

    system_opts =
      opts
      |> Keyword.drop([:username, :password, :database, :pool_size, :name])
      |> Keyword.put(:auth, auth)

    {:ok, conn} = Arangox.start_link(system_opts)

    result =
      case Arangox.request(conn, :post, "/_api/database", %{name: database}) do
        {:ok, _req, %{status: status}} when status in [200, 201] ->
          :ok

        {:ok, _req, %{status: 409}} ->
          # Database already exists
          :ok

        {:error, %{status: 409}} ->
          :ok

        {:error, reason} ->
          {:error, reason}
      end

    GenServer.stop(conn)
    result
  end

  defp create_collections do
    collections = [
      {"investigations", :document},
      {"claims", :document},
      {"evidence", :document},
      {"navigation_paths", :document},
      {"entities", :document},
      {"access_grants", :document},
      # Phase D collections
      {"investigation_links", :document},
      {"annotations", :document},
      {"redactions", :document},
      {"provenance_log", :document},
      {"api_keys", :document},
      {"financial_transactions", :edge},
      {"relationships", :edge}
    ]

    Enum.each(collections, fn {name, type} ->
      case Arangox.request(Arangox, :post, "/_api/collection", %{
             name: name,
             type: if(type == :edge, do: 3, else: 2)
           }) do
        {:ok, _req, _resp} -> :ok
        {:error, %{status: 409}} -> :ok
        error -> IO.warn("Failed to create collection #{name}: #{inspect(error)}")
      end
    end)

    :ok
  end

  defp create_indexes do
    indexes = [
      # Full-text search
      {"claims", "fulltext", ["text"]},
      {"evidence", "fulltext", ["title"]},

      # Investigation queries
      {"claims", "hash", ["investigation_id"]},
      {"evidence", "hash", ["investigation_id"]},

      # Zotero sync
      {"evidence", "hash", ["zotero_key"]},

      # SHA-256 dedup (Lithoglyph/Docudactyl pipeline)
      {"evidence", "hash", ["sha256_hash"]},

      # Financial transaction queries
      {"financial_transactions", "hash", ["investigation_id"]},
      {"financial_transactions", "hash", ["source_entity_id"]},
      {"financial_transactions", "hash", ["destination_entity_id"]},

      # PROMPT score queries
      {"claims", "skiplist", ["prompt_scores.provenance"]},
      {"evidence", "skiplist", ["prompt_scores.methodology"]},

      # Entity resolution
      {"entities", "hash", ["investigation_id"]},
      {"entities", "hash", ["primary_name"]},
      {"entities", "fulltext", ["primary_name"]},

      # RBAC access grants
      {"access_grants", "hash", ["investigation_id"]},
      {"access_grants", "hash", ["user_id"]},
      {"access_grants", "hash", ["investigation_id", "user_id"]},

      # Phase D: Investigation links
      {"investigation_links", "hash", ["investigation_a_id"]},
      {"investigation_links", "hash", ["investigation_b_id"]},

      # Phase D: Annotations
      {"annotations", "hash", ["target_id"]},
      {"annotations", "hash", ["target_type"]},
      {"annotations", "hash", ["user_id"]},

      # Phase D: Redactions
      {"redactions", "hash", ["evidence_id"]},

      # Phase D: Provenance log
      {"provenance_log", "hash", ["target_id"]},
      {"provenance_log", "hash", ["actor"]},
      {"provenance_log", "hash", ["action_type"]},
      {"provenance_log", "skiplist", ["timestamp"]},

      # Phase D: API keys
      {"api_keys", "hash", ["key_hash"]},
      {"api_keys", "hash", ["user_id"]}
    ]

    Enum.each(indexes, fn {collection, type, fields} ->
      body = %{
        type: type,
        fields: fields
      }

      case Arangox.request(Arangox, :post, "/_api/index?collection=#{collection}", body) do
        {:ok, _req, _resp} -> :ok
        error -> IO.warn("Failed to create index on #{collection}: #{inspect(error)}")
      end
    end)

    :ok
  end
end

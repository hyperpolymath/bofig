defmodule EvidenceGraph.ArangoDB do
  @moduledoc """
  ArangoDB connection and query interface.

  Provides a connection pool and helper functions for interacting with ArangoDB.
  """

  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    children = [
      {Arangox, opts}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  @doc """
  Execute an AQL query with parameters.

  ## Examples

      iex> query("FOR c IN claims FILTER c._key == @key RETURN c", %{key: "claim_1"})
      {:ok, [%{"_key" => "claim_1", ...}]}
  """
  def query(aql, vars \\ %{}) do
    Arangox.transaction(
      Arangox,
      fn cursor ->
        stream = Arangox.cursor(cursor, aql, vars)
        {:ok, Enum.to_list(stream)}
      end,
      write: [:claims, :evidence, :relationships, :investigations, :navigation_paths]
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
        {:ok, Enum.to_list(stream)}
      end,
      read: [:claims, :evidence, :relationships, :investigations, :navigation_paths]
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
    INSERT @document INTO #{collection}
    RETURN NEW
    """

    case query(aql, %{document: document}) do
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
    UPDATE @key WITH @updates IN #{collection}
    RETURN NEW
    """

    case query(aql, %{key: key, updates: updates}) do
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
    FOR doc IN #{collection}
      FILTER doc._key == @key
      LIMIT 1
      RETURN doc
    """

    case query_read(aql, %{key: key}) do
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
    REMOVE @key IN #{collection}
    RETURN OLD
    """

    case query(aql, %{key: key}) do
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
      :ok
    end
  end

  defp create_collections do
    collections = [
      {"investigations", :document},
      {"claims", :document},
      {"evidence", :document},
      {"navigation_paths", :document},
      {"relationships", :edge}
    ]

    Enum.each(collections, fn {name, type} ->
      case Arangox.request(Arangox, :post, "/_api/collection", %{
             name: name,
             type: if(type == :edge, do: 3, else: 2)
           }) do
        {:ok, _} -> :ok
        {:error, %{status: 409}} -> :ok  # Already exists
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

      # PROMPT score queries
      {"claims", "skiplist", ["prompt_scores.provenance"]},
      {"evidence", "skiplist", ["prompt_scores.methodology"]}
    ]

    Enum.each(indexes, fn {collection, type, fields} ->
      index_type =
        case type do
          "fulltext" -> "fulltext"
          "hash" -> "hash"
          "skiplist" -> "skiplist"
        end

      body = %{
        type: index_type,
        fields: fields
      }

      case Arangox.request(Arangox, :post, "/_api/index?collection=#{collection}", body) do
        {:ok, _} -> :ok
        error -> IO.warn("Failed to create index on #{collection}: #{inspect(error)}")
      end
    end)

    :ok
  end
end

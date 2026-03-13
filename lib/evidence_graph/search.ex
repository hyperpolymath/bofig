# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
defmodule EvidenceGraph.Search do
  @moduledoc """
  Unified full-text search across all collections using ArangoSearch.

  Provides functions to:
  - Search across evidence titles, claim text, and entity names simultaneously
  - Set up ArangoSearch views and analyzers (run once during database setup)
  - Perform collection-specific searches with relevance scoring

  Uses the `text_en` analyzer with stemming and stopword removal for
  English-language content.
  """

  alias EvidenceGraph.ArangoDB
  alias EvidenceGraph.Claims.Claim
  alias EvidenceGraph.Evidence.Evidence
  alias EvidenceGraph.Entities.Entity

  # ---------------------------------------------------------------------------
  # Unified search
  # ---------------------------------------------------------------------------

  @doc """
  Search across evidence titles, claim text, and entity names simultaneously.

  Returns:

      %{
        evidence: [%{item: %Evidence{}, score: float(), highlight: String.t()}],
        claims: [%{item: %Claim{}, score: float(), highlight: String.t()}],
        entities: [%{item: %Entity{}, score: float(), highlight: String.t()}]
      }

  ## Options

  - `:limit` — Maximum results per collection (default: 20)
  """
  def search_all(query, investigation_id \\ nil, opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)

    with {:ok, ev_results} <- search_evidence(query, investigation_id, limit: limit),
         {:ok, cl_results} <- search_claims(query, investigation_id, limit: limit),
         {:ok, en_results} <- search_entities(query, investigation_id, limit: limit) do
      {:ok,
       %{
         evidence: ev_results,
         claims: cl_results,
         entities: en_results
       }}
    end
  end

  # ---------------------------------------------------------------------------
  # Collection-specific searches
  # ---------------------------------------------------------------------------

  @doc """
  Search evidence by title, tags, and metadata content text using ArangoSearch.

  Falls back to LIKE-based search if the ArangoSearch view is not yet created.
  """
  def search_evidence(query, investigation_id \\ nil, opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)

    inv_filter =
      if investigation_id,
        do: "FILTER doc.investigation_id == @investigation_id",
        else: ""

    # Try ArangoSearch view first
    aql = """
    FOR doc IN evidence_search
      SEARCH ANALYZER(
        PHRASE(doc.title, @query, "text_en")
        OR TOKENS(@query, "text_en") ALL IN doc.title
        OR TOKENS(@query, "text_en") ANY IN doc.tags
        OR TOKENS(@query, "text_en") ALL IN doc.metadata.content_text,
        "text_en"
      )
      #{inv_filter}
      LET score = BM25(doc)
      SORT score DESC
      LIMIT @limit
      RETURN {
        doc: doc,
        score: score,
        highlight: SUBSTRING(doc.title, 0, 200)
      }
    """

    vars =
      %{query: query, limit: limit, investigation_id: investigation_id}
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> Map.new()

    case ArangoDB.query_read(aql, vars) do
      {:ok, results} ->
        parsed =
          Enum.map(results, fn r ->
            %{
              item: Evidence.from_arango_doc(r["doc"]),
              score: r["score"] || 0.0,
              highlight: r["highlight"] || ""
            }
          end)

        {:ok, parsed}

      # Fallback to LIKE-based search if view doesn't exist
      {:error, _} ->
        search_evidence_fallback(query, investigation_id, limit)
    end
  end

  @doc """
  Search claims by text using ArangoSearch.

  Falls back to FULLTEXT index if the ArangoSearch view is not yet created.
  """
  def search_claims(query, investigation_id \\ nil, opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)

    inv_filter =
      if investigation_id,
        do: "FILTER doc.investigation_id == @investigation_id",
        else: ""

    aql = """
    FOR doc IN claims_search
      SEARCH ANALYZER(
        TOKENS(@query, "text_en") ALL IN doc.text,
        "text_en"
      )
      #{inv_filter}
      LET score = BM25(doc)
      SORT score DESC
      LIMIT @limit
      RETURN {
        doc: doc,
        score: score,
        highlight: SUBSTRING(doc.text, 0, 200)
      }
    """

    vars =
      %{query: query, limit: limit, investigation_id: investigation_id}
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> Map.new()

    case ArangoDB.query_read(aql, vars) do
      {:ok, results} ->
        parsed =
          Enum.map(results, fn r ->
            %{
              item: Claim.from_arango_doc(r["doc"]),
              score: r["score"] || 0.0,
              highlight: r["highlight"] || ""
            }
          end)

        {:ok, parsed}

      {:error, _} ->
        search_claims_fallback(query, investigation_id, limit)
    end
  end

  @doc """
  Search entities by primary name and aliases using ArangoSearch.
  """
  def search_entities(query, investigation_id \\ nil, opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)

    inv_filter =
      if investigation_id,
        do: "FILTER doc.investigation_id == @investigation_id",
        else: ""

    aql = """
    FOR doc IN entities_search
      SEARCH ANALYZER(
        TOKENS(@query, "text_en") ALL IN doc.primary_name
        OR TOKENS(@query, "text_en") ANY IN doc.aliases,
        "text_en"
      )
      #{inv_filter}
      LET score = BM25(doc)
      SORT score DESC
      LIMIT @limit
      RETURN {
        doc: doc,
        score: score,
        highlight: doc.primary_name
      }
    """

    vars =
      %{query: query, limit: limit, investigation_id: investigation_id}
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> Map.new()

    case ArangoDB.query_read(aql, vars) do
      {:ok, results} ->
        parsed =
          Enum.map(results, fn r ->
            %{
              item: Entity.from_arango_doc(r["doc"]),
              score: r["score"] || 0.0,
              highlight: r["highlight"] || ""
            }
          end)

        {:ok, parsed}

      {:error, _} ->
        search_entities_fallback(query, investigation_id, limit)
    end
  end

  # ---------------------------------------------------------------------------
  # ArangoSearch setup
  # ---------------------------------------------------------------------------

  @doc """
  Create ArangoSearch analyzers and views.

  Should be called once during database setup (e.g. from a Mix task or
  `ArangoDB.setup_database/0`).

  Creates:
  - `evidence_search` view over the `evidence` collection
  - `claims_search` view over the `claims` collection
  - `entities_search` view over the `entities` collection

  All use the built-in `text_en` analyzer with stemming and stopwords.
  """
  def setup_search_views do
    views = [
      %{
        name: "evidence_search",
        type: "arangosearch",
        links: %{
          "evidence" => %{
            analyzers: ["text_en", "identity"],
            includeAllFields: false,
            fields: %{
              "title" => %{analyzers: ["text_en"]},
              "tags" => %{analyzers: ["text_en"]},
              "investigation_id" => %{analyzers: ["identity"]},
              "metadata" => %{
                fields: %{
                  "content_text" => %{analyzers: ["text_en"]}
                }
              }
            }
          }
        }
      },
      %{
        name: "claims_search",
        type: "arangosearch",
        links: %{
          "claims" => %{
            analyzers: ["text_en", "identity"],
            includeAllFields: false,
            fields: %{
              "text" => %{analyzers: ["text_en"]},
              "investigation_id" => %{analyzers: ["identity"]}
            }
          }
        }
      },
      %{
        name: "entities_search",
        type: "arangosearch",
        links: %{
          "entities" => %{
            analyzers: ["text_en", "identity"],
            includeAllFields: false,
            fields: %{
              "primary_name" => %{analyzers: ["text_en"]},
              "aliases" => %{analyzers: ["text_en"]},
              "investigation_id" => %{analyzers: ["identity"]}
            }
          }
        }
      }
    ]

    Enum.each(views, fn view ->
      case Arangox.request(Arangox, :post, "/_api/view", view) do
        {:ok, _req, _resp} ->
          :ok

        {:error, %{status: 409}} ->
          # View already exists, update links instead
          Arangox.request(Arangox, :patch, "/_api/view/#{view.name}/properties", %{
            links: view.links
          })

        error ->
          IO.warn("Failed to create ArangoSearch view #{view.name}: #{inspect(error)}")
      end
    end)

    :ok
  end

  # ---------------------------------------------------------------------------
  # Fallback searches (no ArangoSearch view)
  # ---------------------------------------------------------------------------

  defp search_evidence_fallback(query, investigation_id, limit) do
    inv_filter =
      if investigation_id,
        do: "FILTER e.investigation_id == @investigation_id",
        else: ""

    aql = """
    FOR e IN evidence
      FILTER CONTAINS(LOWER(e.title), LOWER(@query))
          OR @query IN e.tags
      #{inv_filter}
      LIMIT @limit
      RETURN {
        doc: e,
        score: 1.0,
        highlight: SUBSTRING(e.title, 0, 200)
      }
    """

    vars =
      %{query: query, limit: limit, investigation_id: investigation_id}
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> Map.new()

    case ArangoDB.query_read(aql, vars) do
      {:ok, results} ->
        {:ok,
         Enum.map(results, fn r ->
           %{
             item: Evidence.from_arango_doc(r["doc"]),
             score: r["score"] || 0.0,
             highlight: r["highlight"] || ""
           }
         end)}

      error ->
        error
    end
  end

  defp search_claims_fallback(query, investigation_id, limit) do
    inv_filter =
      if investigation_id,
        do: "FILTER c.investigation_id == @investigation_id",
        else: ""

    aql = """
    FOR c IN claims
      FILTER CONTAINS(LOWER(c.text), LOWER(@query))
      #{inv_filter}
      LIMIT @limit
      RETURN {
        doc: c,
        score: 1.0,
        highlight: SUBSTRING(c.text, 0, 200)
      }
    """

    vars =
      %{query: query, limit: limit, investigation_id: investigation_id}
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> Map.new()

    case ArangoDB.query_read(aql, vars) do
      {:ok, results} ->
        {:ok,
         Enum.map(results, fn r ->
           %{
             item: Claim.from_arango_doc(r["doc"]),
             score: r["score"] || 0.0,
             highlight: r["highlight"] || ""
           }
         end)}

      error ->
        error
    end
  end

  defp search_entities_fallback(query, investigation_id, limit) do
    inv_filter =
      if investigation_id,
        do: "FILTER ent.investigation_id == @investigation_id",
        else: ""

    aql = """
    FOR ent IN entities
      FILTER CONTAINS(LOWER(ent.primary_name), LOWER(@query))
          OR LENGTH(
               FOR alias IN (ent.aliases || [])
                 FILTER CONTAINS(LOWER(alias), LOWER(@query))
                 RETURN 1
             ) > 0
      #{inv_filter}
      LIMIT @limit
      RETURN {
        doc: ent,
        score: 1.0,
        highlight: ent.primary_name
      }
    """

    vars =
      %{query: query, limit: limit, investigation_id: investigation_id}
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> Map.new()

    case ArangoDB.query_read(aql, vars) do
      {:ok, results} ->
        {:ok,
         Enum.map(results, fn r ->
           %{
             item: Entity.from_arango_doc(r["doc"]),
             score: r["score"] || 0.0,
             highlight: r["highlight"] || ""
           }
         end)}

      error ->
        error
    end
  end
end

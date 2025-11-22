defmodule EvidenceGraph.Evidence do
  @moduledoc """
  Context for managing Evidence in the Evidence Graph.
  """

  alias EvidenceGraph.ArangoDB
  alias EvidenceGraph.Evidence.Evidence

  @doc """
  Get evidence by ID.
  """
  def get_evidence(id) do
    case ArangoDB.get("evidence", id) do
      {:ok, doc} -> {:ok, Evidence.from_arango_doc(doc)}
      error -> error
    end
  end

  @doc """
  Get evidence by ID, raises if not found.
  """
  def get_evidence!(id) do
    case get_evidence(id) do
      {:ok, evidence} -> evidence
      {:error, :not_found} -> raise "Evidence not found: #{id}"
    end
  end

  @doc """
  Get evidence by Zotero key.
  """
  def get_evidence_by_zotero_key(zotero_key) do
    aql = """
    FOR evidence IN evidence
      FILTER evidence.zotero_key == @zotero_key
      LIMIT 1
      RETURN evidence
    """

    case ArangoDB.query_read(aql, %{zotero_key: zotero_key}) do
      {:ok, [doc]} -> {:ok, Evidence.from_arango_doc(doc)}
      {:ok, []} -> {:error, :not_found}
      error -> error
    end
  end

  @doc """
  List all evidence for an investigation.
  """
  def list_evidence(investigation_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 100)
    offset = Keyword.get(opts, :offset, 0)

    aql = """
    FOR evidence IN evidence
      FILTER evidence.investigation_id == @investigation_id
      SORT evidence.inserted_at DESC
      LIMIT @offset, @limit
      RETURN evidence
    """

    case ArangoDB.query_read(aql, %{
           investigation_id: investigation_id,
           limit: limit,
           offset: offset
         }) do
      {:ok, docs} -> {:ok, Enum.map(docs, &Evidence.from_arango_doc/1)}
      error -> error
    end
  end

  @doc """
  Create new evidence.

  ## Examples

      iex> create_evidence(%{
      ...>   investigation_id: "inv_123",
      ...>   title: "ONS CPI Data October 2022",
      ...>   evidence_type: :dataset,
      ...>   source_url: "https://ons.gov.uk/..."
      ...> })
      {:ok, %Evidence{}}
  """
  def create_evidence(attrs) do
    changeset = Evidence.changeset(%Evidence{}, attrs)

    if changeset.valid? do
      evidence =
        Ecto.Changeset.apply_changes(changeset)
        |> Map.put(:inserted_at, DateTime.utc_now())
        |> Map.put(:updated_at, DateTime.utc_now())

      case ArangoDB.insert("evidence", Evidence.to_arango_doc(evidence)) do
        {:ok, doc} -> {:ok, Evidence.from_arango_doc(doc)}
        error -> error
      end
    else
      {:error, changeset}
    end
  end

  @doc """
  Update evidence.
  """
  def update_evidence(id, attrs) do
    with {:ok, evidence} <- get_evidence(id) do
      changeset = Evidence.changeset(evidence, attrs)

      if changeset.valid? do
        updates =
          Ecto.Changeset.apply_changes(changeset)
          |> Map.put(:updated_at, DateTime.utc_now())
          |> Evidence.to_arango_doc()
          |> Map.drop([:_key, :inserted_at])

        case ArangoDB.update("evidence", id, updates) do
          {:ok, doc} -> {:ok, Evidence.from_arango_doc(doc)}
          error -> error
        end
      else
        {:error, changeset}
      end
    end
  end

  @doc """
  Delete evidence.
  """
  def delete_evidence(id) do
    case ArangoDB.delete("evidence", id) do
      {:ok, _doc} -> :ok
      error -> error
    end
  end

  @doc """
  Search evidence by title or tags.
  """
  def search_evidence(query_text, investigation_id \\ nil) do
    aql =
      if investigation_id do
        """
        FOR evidence IN FULLTEXT(evidence, "title", @query)
          FILTER evidence.investigation_id == @investigation_id
          RETURN evidence
        """
      else
        """
        FOR evidence IN FULLTEXT(evidence, "title", @query)
          RETURN evidence
        """
      end

    vars = %{query: query_text, investigation_id: investigation_id}

    case ArangoDB.query_read(aql, vars) do
      {:ok, docs} -> {:ok, Enum.map(docs, &Evidence.from_arango_doc/1)}
      error -> error
    end
  end

  @doc """
  Import evidence from Zotero JSON.

  Updates existing evidence if zotero_key matches, otherwise creates new.
  """
  def import_from_zotero(zotero_json, investigation_id) do
    attrs = %{
      investigation_id: investigation_id,
      title: zotero_json["title"],
      evidence_type: map_zotero_type(zotero_json["itemType"]),
      source_url: zotero_json["url"],
      zotero_key: zotero_json["key"],
      zotero_version: zotero_json["version"] || 0,
      tags: Enum.map(zotero_json["tags"] || [], & &1["tag"]),
      dublin_core: extract_dublin_core(zotero_json),
      schema_org: extract_schema_org(zotero_json),
      metadata: %{
        zotero_item_type: zotero_json["itemType"]
      }
    }

    # Check if evidence with this zotero_key already exists
    case get_evidence_by_zotero_key(zotero_json["key"]) do
      {:ok, existing} ->
        update_evidence(existing.id, attrs)

      {:error, :not_found} ->
        create_evidence(attrs)
    end
  end

  defp map_zotero_type("journalArticle"), do: :document
  defp map_zotero_type("book"), do: :document
  defp map_zotero_type("dataset"), do: :dataset
  defp map_zotero_type("interview"), do: :interview
  defp map_zotero_type("audioRecording"), do: :media
  defp map_zotero_type("videoRecording"), do: :media
  defp map_zotero_type(_), do: :other

  defp extract_dublin_core(zotero) do
    %{
      "creator" => format_creators(zotero["creators"]),
      "date" => zotero["date"],
      "publisher" => zotero["publisher"],
      "description" => zotero["abstractNote"],
      "language" => zotero["language"],
      "rights" => zotero["rights"]
    }
  end

  defp extract_schema_org(zotero) do
    %{
      "@context" => "https://schema.org",
      "@type" => "CreativeWork",
      "name" => zotero["title"],
      "author" => Enum.map(zotero["creators"] || [], &%{"@type" => "Person", "name" => &1["name"]}),
      "datePublished" => zotero["date"],
      "url" => zotero["url"]
    }
  end

  defp format_creators(nil), do: nil

  defp format_creators(creators) when is_list(creators) do
    creators
    |> Enum.map(fn creator ->
      if creator["firstName"] && creator["lastName"] do
        "#{creator["firstName"]} #{creator["lastName"]}"
      else
        creator["name"]
      end
    end)
    |> Enum.join("; ")
  end

  @doc """
  Export evidence to Zotero JSON format.
  """
  def export_to_zotero(id) do
    with {:ok, evidence} <- get_evidence(id) do
      {:ok, Evidence.to_zotero_json(evidence)}
    end
  end

  @doc """
  Get all claims supported by this evidence.
  """
  def get_supported_claims(evidence_id) do
    aql = """
    FOR evidence IN evidence
      FILTER evidence._key == @evidence_id
      FOR v, e IN 1..1 INBOUND evidence relationships
        FILTER e.relationship_type == "supports"
        FILTER IS_SAME_COLLECTION("claims", v)
        RETURN {claim: v, relationship: e}
    """

    case ArangoDB.query_read(aql, %{evidence_id: evidence_id}) do
      {:ok, results} ->
        claims =
          Enum.map(results, fn %{"claim" => cl, "relationship" => rel} ->
            %{
              claim: EvidenceGraph.Claims.Claim.from_arango_doc(cl),
              weight: rel["weight"],
              confidence: rel["confidence"],
              reasoning: rel["reasoning"]
            }
          end)

        {:ok, claims}

      error ->
        error
    end
  end
end

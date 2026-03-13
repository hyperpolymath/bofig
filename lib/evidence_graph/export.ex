# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
defmodule EvidenceGraph.Export do
  @moduledoc """
  Multi-format export for the Evidence Graph.

  Supports exporting investigation data in the following formats:

  - **Zotero JSON** - For reference manager import
  - **CSV** - For spreadsheet analysis (evidence, claims, entities, transactions)
  - **IIIF Presentation API 3.0** - For image-based evidence viewing
  - **GraphML** - For graph analysis in Gephi
  - **JSON-LD** - Linked Data with Schema.org vocabulary
  """

  alias EvidenceGraph.ArangoDB

  @exportable_collections ~w(evidence claims entities financial_transactions)

  # ---------------------------------------------------------------------------
  # Zotero JSON
  # ---------------------------------------------------------------------------

  @doc """
  Export all evidence in an investigation as Zotero-compatible JSON.

  Returns a list of Zotero item objects ready for import into Zotero.

  ## Returns

  `{:ok, [zotero_item]}` or `{:error, reason}`
  """
  def export_zotero(investigation_id) do
    aql = """
    FOR ev IN evidence
      FILTER ev.investigation_id == @investigation_id
      SORT ev.inserted_at DESC
      RETURN ev
    """

    case ArangoDB.query_read(aql, %{investigation_id: investigation_id}) do
      {:ok, docs} ->
        items = Enum.map(docs, &to_zotero_item/1)
        {:ok, items}

      error ->
        error
    end
  end

  # ---------------------------------------------------------------------------
  # CSV
  # ---------------------------------------------------------------------------

  @doc """
  Export a collection within an investigation as CSV.

  Supported collections: #{inspect(@exportable_collections)}

  Returns `{:ok, csv_string}` with headers and rows.
  """
  def export_csv(investigation_id, collection)
      when collection in @exportable_collections do
    # Financial transactions use investigation_id field too
    aql = """
    FOR doc IN @@collection
      FILTER doc.investigation_id == @investigation_id
      SORT doc.inserted_at DESC
      RETURN doc
    """

    case ArangoDB.query_read(aql, %{
           investigation_id: investigation_id,
           "@collection": collection
         }) do
      {:ok, []} ->
        {:ok, ""}

      {:ok, docs} ->
        csv = docs_to_csv(docs, collection)
        {:ok, csv}

      error ->
        error
    end
  end

  def export_csv(_investigation_id, collection) do
    {:error, {:unsupported_collection, collection, @exportable_collections}}
  end

  # ---------------------------------------------------------------------------
  # IIIF Presentation API 3.0
  # ---------------------------------------------------------------------------

  @doc """
  Generate a IIIF Presentation API 3.0 manifest for image-based evidence
  in an investigation.

  Includes evidence items that are of type "document" or "media" and have
  a `source_url` or `local_path`.

  ## Returns

  `{:ok, iiif_manifest_map}` or `{:error, reason}`
  """
  def export_iiif_manifest(investigation_id) do
    # Fetch investigation metadata
    inv_aql = """
    FOR inv IN investigations
      FILTER inv._key == @investigation_id
      LIMIT 1
      RETURN inv
    """

    evidence_aql = """
    FOR ev IN evidence
      FILTER ev.investigation_id == @investigation_id
      FILTER ev.evidence_type IN ["document", "media"]
      SORT ev.inserted_at ASC
      RETURN ev
    """

    with {:ok, inv_docs} <- ArangoDB.query_read(inv_aql, %{investigation_id: investigation_id}),
         {:ok, evidence_docs} <- ArangoDB.query_read(evidence_aql, %{investigation_id: investigation_id}) do
      investigation = List.first(inv_docs) || %{}
      inv_label = investigation["title"] || investigation["name"] || investigation_id

      canvases =
        evidence_docs
        |> Enum.with_index(1)
        |> Enum.map(fn {ev, idx} ->
          image_url = ev["source_url"] || "file://#{ev["local_path"]}"

          %{
            "id" => "#{base_url()}/iiif/#{investigation_id}/canvas/#{idx}",
            "type" => "Canvas",
            "label" => %{"en" => [ev["title"] || "Evidence #{idx}"]},
            "items" => [
              %{
                "id" => "#{base_url()}/iiif/#{investigation_id}/canvas/#{idx}/page",
                "type" => "AnnotationPage",
                "items" => [
                  %{
                    "id" => "#{base_url()}/iiif/#{investigation_id}/canvas/#{idx}/anno",
                    "type" => "Annotation",
                    "motivation" => "painting",
                    "body" => %{
                      "id" => image_url,
                      "type" => "Image",
                      "format" => "image/jpeg"
                    },
                    "target" => "#{base_url()}/iiif/#{investigation_id}/canvas/#{idx}"
                  }
                ]
              }
            ]
          }
        end)

      manifest = %{
        "@context" => "http://iiif.io/api/presentation/3/context.json",
        "id" => "#{base_url()}/iiif/#{investigation_id}/manifest.json",
        "type" => "Manifest",
        "label" => %{"en" => [inv_label]},
        "metadata" => [
          %{"label" => %{"en" => ["Investigation ID"]}, "value" => %{"en" => [investigation_id]}},
          %{
            "label" => %{"en" => ["Evidence Count"]},
            "value" => %{"en" => [to_string(length(evidence_docs))]}
          }
        ],
        "items" => canvases
      }

      {:ok, manifest}
    end
  end

  # ---------------------------------------------------------------------------
  # GraphML
  # ---------------------------------------------------------------------------

  @doc """
  Export the full evidence graph for an investigation as GraphML XML.

  Includes entities as nodes and relationships as edges, suitable for
  import into Gephi, yEd, or other graph analysis tools.

  ## Returns

  `{:ok, graphml_xml_string}` or `{:error, reason}`
  """
  def export_graphml(investigation_id) do
    entities_aql = """
    FOR entity IN entities
      FILTER entity.investigation_id == @investigation_id
      RETURN entity
    """

    evidence_aql = """
    FOR ev IN evidence
      FILTER ev.investigation_id == @investigation_id
      RETURN ev
    """

    claims_aql = """
    FOR claim IN claims
      FILTER claim.investigation_id == @investigation_id
      RETURN claim
    """

    relationships_aql = """
    FOR rel IN relationships
      FILTER rel.investigation_id == @investigation_id
         OR rel._from IN (
           FOR e IN entities FILTER e.investigation_id == @investigation_id
           RETURN CONCAT("entities/", e._key)
         )
      RETURN rel
    """

    vars = %{investigation_id: investigation_id}

    with {:ok, entities} <- ArangoDB.query_read(entities_aql, vars),
         {:ok, evidence} <- ArangoDB.query_read(evidence_aql, vars),
         {:ok, claims} <- ArangoDB.query_read(claims_aql, vars),
         {:ok, relationships} <- ArangoDB.query_read(relationships_aql, vars) do
      xml = build_graphml(entities, evidence, claims, relationships, investigation_id)
      {:ok, xml}
    end
  end

  # ---------------------------------------------------------------------------
  # JSON-LD
  # ---------------------------------------------------------------------------

  @doc """
  Export the investigation as JSON-LD with Schema.org vocabulary.

  Produces a JSON-LD document describing the investigation, its evidence,
  claims, and entities using Schema.org types.

  ## Returns

  `{:ok, json_ld_map}` or `{:error, reason}`
  """
  def export_json_ld(investigation_id) do
    inv_aql = """
    FOR inv IN investigations
      FILTER inv._key == @investigation_id
      LIMIT 1
      RETURN inv
    """

    entities_aql = """
    FOR entity IN entities
      FILTER entity.investigation_id == @investigation_id
      RETURN entity
    """

    evidence_aql = """
    FOR ev IN evidence
      FILTER ev.investigation_id == @investigation_id
      RETURN ev
    """

    claims_aql = """
    FOR claim IN claims
      FILTER claim.investigation_id == @investigation_id
      RETURN claim
    """

    vars = %{investigation_id: investigation_id}

    with {:ok, inv_docs} <- ArangoDB.query_read(inv_aql, vars),
         {:ok, entities} <- ArangoDB.query_read(entities_aql, vars),
         {:ok, evidence} <- ArangoDB.query_read(evidence_aql, vars),
         {:ok, claims} <- ArangoDB.query_read(claims_aql, vars) do
      investigation = List.first(inv_docs) || %{}

      json_ld = %{
        "@context" => %{
          "@vocab" => "https://schema.org/",
          "evidence" => "https://schema.org/citation",
          "claim" => "https://schema.org/Claim",
          "investigation" => "https://schema.org/ResearchProject"
        },
        "@type" => "ResearchProject",
        "@id" => "#{base_url()}/investigations/#{investigation_id}",
        "name" => investigation["title"] || investigation["name"] || investigation_id,
        "description" => investigation["description"],
        "dateCreated" => investigation["inserted_at"],
        "hasPart" =>
          Enum.map(evidence, fn ev ->
            %{
              "@type" => "CreativeWork",
              "@id" => "#{base_url()}/evidence/#{ev["_key"]}",
              "name" => ev["title"],
              "url" => ev["source_url"],
              "encodingFormat" => ev["evidence_type"],
              "identifier" => ev["sha256_hash"],
              "datePublished" => get_in(ev, ["dublin_core", "date"])
            }
          end),
        "mentions" =>
          Enum.map(entities, fn ent ->
            type =
              case ent["entity_type"] do
                "person" -> "Person"
                "organization" -> "Organization"
                "location" -> "Place"
                _ -> "Thing"
              end

            %{
              "@type" => type,
              "@id" => "#{base_url()}/entities/#{ent["_key"]}",
              "name" => ent["primary_name"],
              "alternateName" => ent["aliases"] || [],
              "description" => ent["description"]
            }
          end),
        "claim" =>
          Enum.map(claims, fn cl ->
            %{
              "@type" => "Claim",
              "@id" => "#{base_url()}/claims/#{cl["_key"]}",
              "text" => cl["text"],
              "dateCreated" => cl["inserted_at"]
            }
          end)
      }

      {:ok, json_ld}
    end
  end

  @doc """
  Returns the list of collections that can be exported as CSV.
  """
  def exportable_collections, do: @exportable_collections

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp base_url do
    Application.get_env(:evidence_graph, EvidenceGraphWeb.Endpoint)[:url][:host] ||
      "http://localhost:4000"
  end

  # Convert an ArangoDB evidence document to Zotero JSON format.
  defp to_zotero_item(ev) do
    dublin_core = ev["dublin_core"] || %{}

    %{
      "key" => ev["zotero_key"] || ev["_key"],
      "version" => ev["zotero_version"] || 0,
      "itemType" => zotero_item_type(ev["evidence_type"]),
      "title" => ev["title"],
      "url" => ev["source_url"],
      "tags" => Enum.map(ev["tags"] || [], &%{"tag" => &1}),
      "creators" => parse_creators_for_zotero(dublin_core["creator"]),
      "date" => dublin_core["date"],
      "publisher" => dublin_core["publisher"],
      "abstractNote" => dublin_core["description"],
      "language" => dublin_core["language"],
      "rights" => dublin_core["rights"],
      "extra" => "evidence_graph_id: #{ev["_key"]}"
    }
  end

  defp zotero_item_type("document"), do: "journalArticle"
  defp zotero_item_type("dataset"), do: "dataset"
  defp zotero_item_type("interview"), do: "interview"
  defp zotero_item_type("media"), do: "audioRecording"
  defp zotero_item_type(_), do: "webpage"

  defp parse_creators_for_zotero(nil), do: []

  defp parse_creators_for_zotero(creator) when is_binary(creator) do
    creator
    |> String.split(";")
    |> Enum.map(&String.trim/1)
    |> Enum.map(&%{"name" => &1})
  end

  defp parse_creators_for_zotero(_), do: []

  # Convert a list of ArangoDB documents to a CSV string.
  defp docs_to_csv(docs, collection) do
    headers = csv_headers(collection)
    header_line = Enum.join(headers, ",")

    rows =
      Enum.map(docs, fn doc ->
        headers
        |> Enum.map(fn header ->
          value = doc[header]
          csv_escape(value)
        end)
        |> Enum.join(",")
      end)

    Enum.join([header_line | rows], "\n")
  end

  defp csv_headers("evidence") do
    ~w(_key investigation_id title evidence_type source_url sha256_hash
       ipfs_hash zotero_key tags inserted_at updated_at)
  end

  defp csv_headers("claims") do
    ~w(_key investigation_id text claim_type status inserted_at updated_at)
  end

  defp csv_headers("entities") do
    ~w(_key investigation_id primary_name entity_type aliases description
       document_count credibility_score inserted_at updated_at)
  end

  defp csv_headers("financial_transactions") do
    ~w(_key investigation_id source_entity_id destination_entity_id
       amount currency transaction_date instrument description inserted_at updated_at)
  end

  defp csv_headers(_), do: ~w(_key)

  defp csv_escape(nil), do: ""
  defp csv_escape(value) when is_binary(value) do
    if String.contains?(value, [",", "\"", "\n"]) do
      "\"" <> String.replace(value, "\"", "\"\"") <> "\""
    else
      value
    end
  end
  defp csv_escape(value) when is_list(value), do: csv_escape(Enum.join(value, "; "))
  defp csv_escape(value) when is_map(value), do: csv_escape(Jason.encode!(value))
  defp csv_escape(value), do: to_string(value)

  # Build a GraphML XML document from graph data.
  defp build_graphml(entities, evidence, claims, relationships, investigation_id) do
    entity_nodes =
      Enum.map(entities, fn ent ->
        """
          <node id="entity_#{ent["_key"]}">
            <data key="d0">#{xml_escape(ent["primary_name"])}</data>
            <data key="d1">entity</data>
            <data key="d2">#{xml_escape(ent["entity_type"])}</data>
          </node>
        """
      end)

    evidence_nodes =
      Enum.map(evidence, fn ev ->
        """
          <node id="evidence_#{ev["_key"]}">
            <data key="d0">#{xml_escape(ev["title"])}</data>
            <data key="d1">evidence</data>
            <data key="d2">#{xml_escape(ev["evidence_type"])}</data>
          </node>
        """
      end)

    claim_nodes =
      Enum.map(claims, fn cl ->
        text = String.slice(cl["text"] || "", 0, 100)

        """
          <node id="claim_#{cl["_key"]}">
            <data key="d0">#{xml_escape(text)}</data>
            <data key="d1">claim</data>
            <data key="d2">#{xml_escape(cl["claim_type"])}</data>
          </node>
        """
      end)

    edges =
      relationships
      |> Enum.with_index()
      |> Enum.map(fn {rel, idx} ->
        # ArangoDB _from/_to are like "collection/key" — extract just the key with prefix
        from = normalise_graphml_id(rel["_from"])
        to = normalise_graphml_id(rel["_to"])

        """
          <edge id="e#{idx}" source="#{from}" target="#{to}">
            <data key="d3">#{xml_escape(rel["relationship_type"])}</data>
            <data key="d4">#{rel["weight"] || 1.0}</data>
          </edge>
        """
      end)

    """
    <?xml version="1.0" encoding="UTF-8"?>
    <graphml xmlns="http://graphml.graphdrawing.org/graphml"
             xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
             xsi:schemaLocation="http://graphml.graphdrawing.org/graphml
             http://graphml.graphdrawing.org/graphml/1.0/graphml.xsd">
      <key id="d0" for="node" attr.name="label" attr.type="string"/>
      <key id="d1" for="node" attr.name="node_type" attr.type="string"/>
      <key id="d2" for="node" attr.name="subtype" attr.type="string"/>
      <key id="d3" for="edge" attr.name="relationship_type" attr.type="string"/>
      <key id="d4" for="edge" attr.name="weight" attr.type="double"/>
      <graph id="investigation_#{investigation_id}" edgedefault="directed">
    #{Enum.join(entity_nodes)}#{Enum.join(evidence_nodes)}#{Enum.join(claim_nodes)}#{Enum.join(edges)}  </graph>
    </graphml>
    """
  end

  # Convert ArangoDB "collection/key" to a GraphML-safe node ID.
  defp normalise_graphml_id(nil), do: "unknown"

  defp normalise_graphml_id(arango_id) when is_binary(arango_id) do
    case String.split(arango_id, "/", parts: 2) do
      [collection, key] ->
        singular =
          collection
          |> String.replace_trailing("s", "")
          |> String.replace("financial_transaction", "transaction")

        "#{singular}_#{key}"

      [single] ->
        single
    end
  end

  defp xml_escape(nil), do: ""

  defp xml_escape(value) when is_binary(value) do
    value
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&apos;")
  end

  defp xml_escape(value), do: xml_escape(to_string(value))
end

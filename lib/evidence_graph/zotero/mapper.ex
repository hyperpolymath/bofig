# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
defmodule EvidenceGraph.Zotero.Mapper do
  @moduledoc """
  Bidirectional mapping between Zotero JSON and Evidence Graph structs.

  Handles:
  - Zotero item types ↔ Evidence Graph evidence types
  - Dublin Core metadata extraction from Zotero fields
  - Schema.org metadata extraction from Zotero fields
  - Evidence Graph → Zotero export format (for re-import to Zotero)
  """

  @type_to_evidence %{
    "journalArticle" => :document,
    "book" => :document,
    "bookSection" => :document,
    "conferencePaper" => :document,
    "report" => :document,
    "thesis" => :document,
    "webpage" => :document,
    "interview" => :interview,
    "dataset" => :dataset,
    "audioRecording" => :media,
    "videoRecording" => :media,
    "podcast" => :media,
    "artwork" => :media
  }

  @evidence_to_type %{
    document: "journalArticle",
    dataset: "dataset",
    interview: "interview",
    media: "audioRecording",
    other: "webpage"
  }

  @schema_org_types %{
    "journalArticle" => "ScholarlyArticle",
    "book" => "Book",
    "dataset" => "Dataset",
    "interview" => "Interview",
    "videoRecording" => "VideoObject",
    "audioRecording" => "AudioObject",
    "webpage" => "WebPage"
  }

  @doc """
  Convert a Zotero API item response to Evidence Graph attributes.

  Expects the full Zotero item JSON (with `data` wrapper from API v3).
  """
  def zotero_to_evidence(zotero_item, investigation_id) do
    data = zotero_item["data"] || zotero_item

    %{
      investigation_id: investigation_id,
      title: data["title"],
      evidence_type: map_zotero_type(data["itemType"]),
      source_url: data["url"],
      zotero_key: data["key"] || zotero_item["key"],
      zotero_version: zotero_item["version"] || data["version"] || 0,
      tags: extract_tags(data["tags"]),
      dublin_core: extract_dublin_core(data),
      schema_org: extract_schema_org(data),
      metadata: %{
        "zotero_item_type" => data["itemType"],
        "zotero_version" => zotero_item["version"] || data["version"] || 0,
        "zotero_library_id" => zotero_item["library"] && zotero_item["library"]["id"],
        "zotero_collections" => data["collections"] || [],
        "zotero_date_modified" => data["dateModified"]
      }
    }
  end

  @doc """
  Convert Evidence Graph evidence to Zotero JSON format (for export/creation).
  """
  def evidence_to_zotero(evidence) do
    %{
      "itemType" => Map.get(@evidence_to_type, evidence.evidence_type, "webpage"),
      "title" => evidence.title,
      "url" => evidence.source_url,
      "tags" => Enum.map(evidence.tags || [], &%{"tag" => &1}),
      "creators" => parse_creators_for_zotero(evidence.dublin_core),
      "date" => dig(evidence.dublin_core, ["date"]),
      "publisher" => dig(evidence.dublin_core, ["publisher"]),
      "abstractNote" => dig(evidence.dublin_core, ["description"]),
      "language" => dig(evidence.dublin_core, ["language"]),
      "rights" => dig(evidence.dublin_core, ["rights"]),
      "extra" => build_extra_field(evidence)
    }
  end

  @doc """
  Map a Zotero item type to an Evidence Graph evidence type.
  """
  def map_zotero_type(zotero_type) do
    Map.get(@type_to_evidence, zotero_type, :other)
  end

  @doc """
  Map an Evidence Graph evidence type to a Zotero item type.
  """
  def map_evidence_type(evidence_type) do
    Map.get(@evidence_to_type, evidence_type, "webpage")
  end

  # -- Dublin Core extraction --

  defp extract_dublin_core(data) do
    %{
      "creator" => format_creators(data["creators"]),
      "date" => data["date"],
      "publisher" => data["publisher"],
      "description" => data["abstractNote"],
      "language" => data["language"],
      "rights" => data["rights"],
      "subject" => extract_tags(data["tags"]) |> Enum.join("; "),
      "type" => data["itemType"],
      "identifier" => build_identifiers(data),
      "source" => data["libraryCatalog"]
    }
  end

  # -- Schema.org extraction --

  defp extract_schema_org(data) do
    %{
      "@context" => "https://schema.org",
      "@type" => Map.get(@schema_org_types, data["itemType"], "CreativeWork"),
      "name" => data["title"],
      "author" =>
        Enum.map(data["creators"] || [], fn creator ->
          %{
            "@type" => "Person",
            "name" => format_creator_name(creator)
          }
        end),
      "datePublished" => data["date"],
      "publisher" =>
        if data["publisher"] do
          %{"@type" => "Organization", "name" => data["publisher"]}
        end,
      "url" => data["url"],
      "identifier" => build_identifiers(data)
    }
  end

  # -- Helpers --

  defp extract_tags(nil), do: []
  defp extract_tags(tags) when is_list(tags), do: Enum.map(tags, & &1["tag"])

  defp format_creators(nil), do: nil

  defp format_creators(creators) when is_list(creators) do
    Enum.map_join(creators, "; ", &format_creator_name/1)
  end

  defp format_creator_name(%{"firstName" => first, "lastName" => last})
       when is_binary(first) and is_binary(last) do
    "#{first} #{last}"
  end

  defp format_creator_name(%{"name" => name}) when is_binary(name), do: name
  defp format_creator_name(_), do: "Unknown"

  defp build_identifiers(data) do
    [
      if(data["DOI"], do: "DOI:#{data["DOI"]}"),
      if(data["ISBN"], do: "ISBN:#{data["ISBN"]}"),
      if(data["ISSN"], do: "ISSN:#{data["ISSN"]}"),
      if(data["url"], do: "URL:#{data["url"]}")
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.join("; ")
  end

  defp parse_creators_for_zotero(%{"creator" => nil}), do: []
  defp parse_creators_for_zotero(nil), do: []

  defp parse_creators_for_zotero(%{"creator" => creator_string}) when is_binary(creator_string) do
    creator_string
    |> String.split("; ")
    |> Enum.map(fn name ->
      case String.split(name, " ", parts: 2) do
        [first, last] ->
          %{"creatorType" => "author", "firstName" => first, "lastName" => last}

        [single] ->
          %{"creatorType" => "author", "name" => single}
      end
    end)
  end

  defp parse_creators_for_zotero(_), do: []

  defp build_extra_field(evidence) do
    prompt_lines =
      if evidence.prompt_scores do
        scores = evidence.prompt_scores

        """
        PROMPT Scores:
        - Provenance: #{Map.get(scores, :provenance, "-")}/100
        - Replicability: #{Map.get(scores, :replicability, "-")}/100
        - Objective: #{Map.get(scores, :objective, "-")}/100
        - Methodology: #{Map.get(scores, :methodology, "-")}/100
        - Publication: #{Map.get(scores, :publication, "-")}/100
        - Transparency: #{Map.get(scores, :transparency, "-")}/100
        """
      else
        ""
      end

    "evidence_graph_id: #{evidence.id}\n#{prompt_lines}"
    |> String.trim()
  end

  defp dig(nil, _keys), do: nil
  defp dig(map, []), do: map
  defp dig(map, [key | rest]) when is_map(map), do: dig(Map.get(map, key), rest)
  defp dig(_, _), do: nil
end

# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
defmodule EvidenceGraph.Zotero.MapperTest do
  use ExUnit.Case, async: true

  alias EvidenceGraph.Zotero.Mapper
  alias EvidenceGraph.PromptScores
  import EvidenceGraph.Fixtures

  describe "zotero_to_evidence/2" do
    test "maps journal article to evidence attributes" do
      item = zotero_journal_article()
      attrs = Mapper.zotero_to_evidence(item, "inv_test")

      assert attrs.investigation_id == "inv_test"
      assert attrs.title == "The Distributional Impact of Inflation in the UK"
      assert attrs.evidence_type == :document
      assert attrs.source_url == "https://doi.org/10.1234/example"
      assert attrs.zotero_key == "ZKEY_JOURNAL"
      assert attrs.zotero_version == 12
    end

    test "extracts tags from Zotero format" do
      item = zotero_journal_article()
      attrs = Mapper.zotero_to_evidence(item, "inv_test")

      assert "inflation" in attrs.tags
      assert "UK economy" in attrs.tags
      assert "inequality" in attrs.tags
    end

    test "extracts Dublin Core metadata" do
      item = zotero_journal_article()
      attrs = Mapper.zotero_to_evidence(item, "inv_test")

      dc = attrs.dublin_core
      assert dc["creator"] == "Jane Smith; John Doe"
      assert dc["date"] == "2023-06-15"
      assert dc["publisher"] == "Economic Journal"
      assert dc["description"] == "This paper examines how inflation affects different income groups."
      assert dc["language"] == "en"
      assert dc["rights"] == "CC-BY-4.0"
      assert dc["type"] == "journalArticle"
    end

    test "extracts Schema.org metadata" do
      item = zotero_journal_article()
      attrs = Mapper.zotero_to_evidence(item, "inv_test")

      so = attrs.schema_org
      assert so["@context"] == "https://schema.org"
      assert so["@type"] == "ScholarlyArticle"
      assert so["name"] == "The Distributional Impact of Inflation in the UK"
      assert so["datePublished"] == "2023-06-15"
      assert length(so["author"]) == 2
    end

    test "preserves Zotero metadata" do
      item = zotero_journal_article()
      attrs = Mapper.zotero_to_evidence(item, "inv_test")

      assert attrs.metadata["zotero_item_type"] == "journalArticle"
      assert attrs.metadata["zotero_version"] == 12
      assert attrs.metadata["zotero_library_id"] == 123_456
      assert attrs.metadata["zotero_collections"] == ["COL_ABC"]
    end

    test "maps dataset type correctly" do
      item = zotero_dataset()
      attrs = Mapper.zotero_to_evidence(item, "inv_test")

      assert attrs.evidence_type == :dataset
      assert attrs.title == "CPI Microdata 2020-2023"
    end

    test "handles item without data wrapper" do
      flat_item = %{
        "key" => "ZKEY_FLAT",
        "version" => 1,
        "itemType" => "book",
        "title" => "Flat item",
        "creators" => [],
        "tags" => []
      }

      attrs = Mapper.zotero_to_evidence(flat_item, "inv_test")
      assert attrs.title == "Flat item"
      assert attrs.zotero_key == "ZKEY_FLAT"
    end

    test "handles nil tags" do
      item = %{"data" => %{"itemType" => "webpage", "title" => "Test", "tags" => nil}}
      attrs = Mapper.zotero_to_evidence(item, "inv_test")
      assert attrs.tags == []
    end
  end

  describe "evidence_to_zotero/1" do
    test "maps evidence to Zotero JSON" do
      evidence = %{
        id: "evidence_exp1",
        title: "ONS Report",
        evidence_type: :document,
        source_url: "https://example.com",
        tags: ["inflation", "UK"],
        dublin_core: %{
          "creator" => "Jane Smith; John Doe",
          "date" => "2023",
          "publisher" => "ONS",
          "description" => "A report on inflation",
          "language" => "en",
          "rights" => "OGL"
        },
        prompt_scores: %PromptScores{provenance: 80}
      }

      zotero = Mapper.evidence_to_zotero(evidence)

      assert zotero["itemType"] == "journalArticle"
      assert zotero["title"] == "ONS Report"
      assert zotero["url"] == "https://example.com"
      assert zotero["date"] == "2023"
      assert zotero["publisher"] == "ONS"
      assert length(zotero["tags"]) == 2
      assert hd(zotero["tags"]) == %{"tag" => "inflation"}
    end

    test "parses creators from Dublin Core creator string" do
      evidence = %{
        id: "test",
        title: "Test",
        evidence_type: :document,
        source_url: nil,
        tags: [],
        dublin_core: %{"creator" => "Jane Smith; John Doe"},
        prompt_scores: nil
      }

      zotero = Mapper.evidence_to_zotero(evidence)
      creators = zotero["creators"]

      assert length(creators) == 2
      assert %{"creatorType" => "author", "firstName" => "Jane", "lastName" => "Smith"} = hd(creators)
    end

    test "handles nil dublin_core" do
      evidence = %{
        id: "test",
        title: "Test",
        evidence_type: :other,
        source_url: nil,
        tags: [],
        dublin_core: nil,
        prompt_scores: nil
      }

      zotero = Mapper.evidence_to_zotero(evidence)
      assert zotero["creators"] == []
    end

    test "includes evidence_graph_id in extra field" do
      evidence = %{
        id: "evidence_extra_test",
        title: "Test",
        evidence_type: :document,
        source_url: nil,
        tags: [],
        dublin_core: nil,
        prompt_scores: %PromptScores{provenance: 75}
      }

      zotero = Mapper.evidence_to_zotero(evidence)
      assert zotero["extra"] =~ "evidence_graph_id: evidence_extra_test"
    end

    test "includes PROMPT scores in extra field when present" do
      evidence = %{
        id: "test",
        title: "Test",
        evidence_type: :document,
        source_url: nil,
        tags: [],
        dublin_core: nil,
        prompt_scores: %PromptScores{
          provenance: 80,
          replicability: 70,
          objective: 65,
          methodology: 90,
          publication: 85,
          transparency: 75
        }
      }

      zotero = Mapper.evidence_to_zotero(evidence)
      assert zotero["extra"] =~ "Provenance: 80/100"
      assert zotero["extra"] =~ "Methodology: 90/100"
      assert zotero["extra"] =~ "Transparency: 75/100"
    end
  end

  describe "map_zotero_type/1" do
    test "maps all known Zotero types" do
      mappings = %{
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

      for {zotero_type, expected} <- mappings do
        assert Mapper.map_zotero_type(zotero_type) == expected,
               "Expected #{zotero_type} → #{expected}, got #{inspect(Mapper.map_zotero_type(zotero_type))}"
      end
    end

    test "unknown type maps to :other" do
      assert Mapper.map_zotero_type("unknownFormat") == :other
      assert Mapper.map_zotero_type(nil) == :other
    end
  end

  describe "map_evidence_type/1" do
    test "maps all evidence types to Zotero types" do
      assert Mapper.map_evidence_type(:document) == "journalArticle"
      assert Mapper.map_evidence_type(:dataset) == "dataset"
      assert Mapper.map_evidence_type(:interview) == "interview"
      assert Mapper.map_evidence_type(:media) == "audioRecording"
      assert Mapper.map_evidence_type(:other) == "webpage"
    end

    test "unknown evidence type maps to webpage" do
      assert Mapper.map_evidence_type(:unknown) == "webpage"
    end
  end

  describe "Schema.org type mapping" do
    test "journal article maps to ScholarlyArticle" do
      item = zotero_journal_article()
      attrs = Mapper.zotero_to_evidence(item, "inv_test")
      assert attrs.schema_org["@type"] == "ScholarlyArticle"
    end

    test "dataset maps to Dataset" do
      item = zotero_dataset()
      attrs = Mapper.zotero_to_evidence(item, "inv_test")
      assert attrs.schema_org["@type"] == "Dataset"
    end
  end

  describe "Dublin Core identifier building" do
    test "builds DOI identifier" do
      item = zotero_journal_article()
      attrs = Mapper.zotero_to_evidence(item, "inv_test")
      assert attrs.dublin_core["identifier"] =~ "DOI:10.1234/example"
    end

    test "builds URL identifier" do
      item = zotero_journal_article()
      attrs = Mapper.zotero_to_evidence(item, "inv_test")
      assert attrs.dublin_core["identifier"] =~ "URL:"
    end
  end
end

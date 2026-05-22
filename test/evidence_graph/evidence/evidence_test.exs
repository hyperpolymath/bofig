# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
defmodule EvidenceGraph.Evidence.EvidenceTest do
  use ExUnit.Case, async: true

  alias EvidenceGraph.Evidence.Evidence
  alias EvidenceGraph.PromptScores
  import EvidenceGraph.Fixtures

  describe "changeset/2 required fields" do
    test "valid attributes produce a valid changeset" do
      changeset = Evidence.changeset(%Evidence{}, valid_evidence_attrs())
      assert changeset.valid?
    end

    test "requires investigation_id" do
      changeset = Evidence.changeset(%Evidence{}, valid_evidence_attrs(%{investigation_id: nil}))
      refute changeset.valid?
      assert Keyword.has_key?(changeset.errors, :investigation_id)
    end

    test "requires title" do
      changeset = Evidence.changeset(%Evidence{}, valid_evidence_attrs(%{title: nil}))
      refute changeset.valid?
      assert Keyword.has_key?(changeset.errors, :title)
    end

    test "requires evidence_type" do
      changeset = Evidence.changeset(%Evidence{}, valid_evidence_attrs(%{evidence_type: nil}))
      refute changeset.valid?
      assert Keyword.has_key?(changeset.errors, :evidence_type)
    end
  end

  describe "changeset/2 validations" do
    test "title must be at least 3 characters" do
      changeset = Evidence.changeset(%Evidence{}, valid_evidence_attrs(%{title: "AB"}))
      refute changeset.valid?
    end

    test "title can be up to 500 characters" do
      title = String.duplicate("a", 500)
      changeset = Evidence.changeset(%Evidence{}, valid_evidence_attrs(%{title: title}))
      assert changeset.valid?
    end

    test "title over 500 characters is rejected" do
      title = String.duplicate("a", 501)
      changeset = Evidence.changeset(%Evidence{}, valid_evidence_attrs(%{title: title}))
      refute changeset.valid?
    end

    test "all evidence types are accepted" do
      for type <- [:document, :dataset, :interview, :media, :other] do
        changeset = Evidence.changeset(%Evidence{}, valid_evidence_attrs(%{evidence_type: type}))
        assert changeset.valid?, "Expected #{type} to be valid"
      end
    end

    test "invalid evidence_type is rejected" do
      changeset = Evidence.changeset(%Evidence{}, valid_evidence_attrs(%{evidence_type: :invalid}))
      refute changeset.valid?
    end
  end

  describe "changeset/2 ID generation" do
    test "auto-generates ID with evidence_ prefix" do
      changeset = Evidence.changeset(%Evidence{}, valid_evidence_attrs())
      id = Ecto.Changeset.get_change(changeset, :id)
      assert String.starts_with?(id, "evidence_")
    end

    test "does not overwrite existing ID" do
      evidence = %Evidence{id: "evidence_existing"}
      changeset = Evidence.changeset(evidence, valid_evidence_attrs())
      refute Ecto.Changeset.get_change(changeset, :id)
    end
  end

  describe "changeset/2 optional fields" do
    test "accepts Zotero integration fields" do
      changeset =
        Evidence.changeset(%Evidence{}, valid_evidence_attrs(%{
          zotero_key: "ZKEY123",
          zotero_version: 5
        }))

      assert changeset.valid?
    end

    test "accepts dublin_core and schema_org maps" do
      changeset =
        Evidence.changeset(%Evidence{}, valid_evidence_attrs(%{
          dublin_core: %{"creator" => "ONS", "date" => "2023"},
          schema_org: %{"@context" => "https://schema.org"}
        }))

      assert changeset.valid?
    end

    test "accepts tags as string array" do
      changeset =
        Evidence.changeset(%Evidence{}, valid_evidence_attrs(%{
          tags: ["inflation", "CPI", "UK"]
        }))

      assert changeset.valid?
    end

    test "defaults tags to empty list" do
      evidence = %Evidence{}
      assert evidence.tags == []
    end

    test "defaults dublin_core to empty map" do
      evidence = %Evidence{}
      assert evidence.dublin_core == %{}
    end
  end

  describe "to_arango_doc/1" do
    test "converts evidence struct to ArangoDB document" do
      evidence = %Evidence{
        id: "evidence_test1",
        investigation_id: "inv_1",
        title: "ONS CPI Report",
        evidence_type: :document,
        source_url: "https://example.com",
        zotero_key: "ZKEY1",
        zotero_version: 3,
        dublin_core: %{"creator" => "ONS"},
        schema_org: %{"@type" => "Dataset"},
        prompt_scores: %PromptScores{provenance: 90},
        tags: ["inflation"],
        metadata: %{},
        inserted_at: ~U[2026-01-15 10:30:00Z],
        updated_at: ~U[2026-01-15 10:30:00Z]
      }

      doc = Evidence.to_arango_doc(evidence)

      assert doc._key == "evidence_test1"
      assert doc.evidence_type == "document"
      assert doc.zotero_key == "ZKEY1"
      assert doc.zotero_version == 3
      assert doc.dublin_core == %{"creator" => "ONS"}
      assert doc.tags == ["inflation"]
    end
  end

  describe "from_arango_doc/1" do
    test "converts ArangoDB document to evidence struct" do
      doc = evidence_arango_doc()
      evidence = Evidence.from_arango_doc(doc)

      assert evidence.id == "evidence_xyz789"
      assert evidence.evidence_type == :document
      assert evidence.zotero_key == "ZKEY123"
      assert evidence.zotero_version == 5
      assert evidence.tags == ["inflation", "ONS"]
    end

    test "handles nil optional fields" do
      doc =
        evidence_arango_doc(%{
          "dublin_core" => nil,
          "schema_org" => nil,
          "tags" => nil,
          "metadata" => nil
        })

      evidence = Evidence.from_arango_doc(doc)
      assert evidence.dublin_core == %{}
      assert evidence.schema_org == %{}
      assert evidence.tags == []
      assert evidence.metadata == %{}
    end

    test "parses prompt_scores" do
      doc = evidence_arango_doc()
      evidence = Evidence.from_arango_doc(doc)
      assert evidence.prompt_scores.provenance == 95
      assert evidence.prompt_scores.transparency == 88
    end
  end

  describe "to_zotero_json/1" do
    test "produces Zotero-compatible JSON" do
      evidence = %Evidence{
        id: "evidence_zot1",
        title: "ONS CPI Report",
        evidence_type: :document,
        source_url: "https://example.com",
        zotero_key: "ZKEY1",
        zotero_version: 3,
        dublin_core: %{"creator" => "Jane Smith; John Doe", "date" => "2023"},
        prompt_scores: %PromptScores{provenance: 80, replicability: 70},
        tags: ["inflation", "UK"]
      }

      json = Evidence.to_zotero_json(evidence)

      assert json.key == "ZKEY1"
      assert json.version == 3
      assert json.itemType == "journalArticle"
      assert json.title == "ONS CPI Report"
      assert json.url == "https://example.com"
      assert json.date == "2023"
      assert length(json.tags) == 2
    end

    test "maps evidence types to Zotero item types" do
      for {ev_type, zot_type} <- [
            {:document, "journalArticle"},
            {:dataset, "dataset"},
            {:interview, "interview"},
            {:media, "audioRecording"},
            {:other, "webpage"}
          ] do
        evidence = %Evidence{
          id: "test",
          evidence_type: ev_type,
          title: "Test",
          dublin_core: %{},
          prompt_scores: %PromptScores{},
          tags: []
        }

        assert Evidence.to_zotero_json(evidence).itemType == zot_type
      end
    end

    test "includes PROMPT scores in extra field" do
      evidence = %Evidence{
        id: "evidence_extra",
        title: "Test",
        evidence_type: :document,
        dublin_core: %{},
        prompt_scores: %PromptScores{provenance: 80, replicability: 70},
        tags: []
      }

      json = Evidence.to_zotero_json(evidence)
      assert json.extra =~ "evidence_graph_id: evidence_extra"
      assert json.extra =~ "Provenance: 80/100"
      assert json.extra =~ "Replicability: 70/100"
    end

    test "uses evidence ID when zotero_key is nil" do
      evidence = %Evidence{
        id: "evidence_nokey",
        title: "Test",
        evidence_type: :document,
        zotero_key: nil,
        zotero_version: nil,
        dublin_core: %{},
        prompt_scores: %PromptScores{},
        tags: []
      }

      json = Evidence.to_zotero_json(evidence)
      assert json.key == "evidence_nokey"
      assert json.version == 0
    end

    test "parses semicolon-separated creators" do
      evidence = %Evidence{
        id: "test",
        title: "Test",
        evidence_type: :document,
        dublin_core: %{"creator" => "Jane Smith; John Doe"},
        prompt_scores: %PromptScores{},
        tags: []
      }

      json = Evidence.to_zotero_json(evidence)
      assert length(json.creators) == 2
    end
  end
end

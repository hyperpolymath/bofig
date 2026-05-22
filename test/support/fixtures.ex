# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
defmodule EvidenceGraph.Fixtures do
  @moduledoc """
  Shared test fixtures for Evidence Graph unit tests.
  """

  alias EvidenceGraph.PromptScores

  # -- Claim fixtures --

  def valid_claim_attrs(overrides \\ %{}) do
    Map.merge(
      %{
        investigation_id: "inv_uk_inflation_2023",
        text: "UK inflation disproportionately affects low-income households",
        claim_type: :primary,
        confidence_level: 0.85,
        created_by: "researcher_1"
      },
      overrides
    )
  end

  def claim_arango_doc(overrides \\ %{}) do
    Map.merge(
      %{
        "_key" => "claim_abc123",
        "investigation_id" => "inv_uk_inflation_2023",
        "text" => "UK inflation disproportionately affects low-income households",
        "claim_type" => "primary",
        "confidence_level" => 0.85,
        "prompt_scores" => %{
          "provenance" => 80,
          "replicability" => 70,
          "objective" => 75,
          "methodology" => 90,
          "publication" => 85,
          "transparency" => 60
        },
        "created_by" => "researcher_1",
        "metadata" => %{},
        "inserted_at" => "2026-01-15T10:30:00Z",
        "updated_at" => "2026-01-15T10:30:00Z"
      },
      overrides
    )
  end

  # -- Evidence fixtures --

  def valid_evidence_attrs(overrides \\ %{}) do
    Map.merge(
      %{
        investigation_id: "inv_uk_inflation_2023",
        title: "ONS Consumer Price Inflation October 2023",
        evidence_type: :document,
        source_url: "https://www.ons.gov.uk/economy/inflationandpriceindices",
        tags: ["inflation", "ONS", "UK"],
        dublin_core: %{
          "creator" => "Office for National Statistics",
          "date" => "2023-10-15",
          "publisher" => "ONS"
        }
      },
      overrides
    )
  end

  def evidence_arango_doc(overrides \\ %{}) do
    Map.merge(
      %{
        "_key" => "evidence_xyz789",
        "investigation_id" => "inv_uk_inflation_2023",
        "title" => "ONS Consumer Price Inflation October 2023",
        "evidence_type" => "document",
        "source_url" => "https://www.ons.gov.uk/economy/inflationandpriceindices",
        "local_path" => nil,
        "ipfs_hash" => nil,
        "zotero_key" => "ZKEY123",
        "zotero_version" => 5,
        "dublin_core" => %{"creator" => "ONS", "date" => "2023-10-15"},
        "schema_org" => %{"@context" => "https://schema.org", "@type" => "Dataset"},
        "prompt_scores" => %{
          "provenance" => 95,
          "replicability" => 90,
          "objective" => 85,
          "methodology" => 80,
          "publication" => 92,
          "transparency" => 88
        },
        "tags" => ["inflation", "ONS"],
        "metadata" => %{},
        "inserted_at" => "2026-01-15T10:30:00Z",
        "updated_at" => "2026-01-16T14:00:00Z"
      },
      overrides
    )
  end

  # -- Relationship fixtures --

  def valid_relationship_attrs(overrides \\ %{}) do
    Map.merge(
      %{
        from_id: "evidence_xyz789",
        from_type: :evidence,
        to_id: "claim_abc123",
        to_type: :claim,
        relationship_type: :supports,
        weight: 0.8,
        confidence: 0.9,
        reasoning: "ONS data directly measures CPI broken down by income quintile"
      },
      overrides
    )
  end

  def relationship_arango_doc(overrides \\ %{}) do
    Map.merge(
      %{
        "_key" => "rel_edge001",
        "_from" => "evidence/evidence_xyz789",
        "_to" => "claims/claim_abc123",
        "relationship_type" => "supports",
        "weight" => 0.8,
        "confidence" => 0.9,
        "reasoning" => "ONS data directly measures CPI",
        "created_by" => "researcher_1",
        "metadata" => %{},
        "inserted_at" => "2026-01-15T12:00:00Z"
      },
      overrides
    )
  end

  # -- Navigation Path fixtures --

  def valid_path_attrs(overrides \\ %{}) do
    Map.merge(
      %{
        investigation_id: "inv_uk_inflation_2023",
        audience_type: :researcher,
        name: "Methodology-focused path through inflation evidence",
        description: "Prioritises methodological rigour and replicability",
        entry_points: ["claim_abc123"],
        path_nodes: [
          %{
            "entity_id" => "claim_abc123",
            "entity_type" => "claim",
            "order" => 1
          },
          %{
            "entity_id" => "evidence_xyz789",
            "entity_type" => "evidence",
            "order" => 2
          }
        ]
      },
      overrides
    )
  end

  def path_arango_doc(overrides \\ %{}) do
    Map.merge(
      %{
        "_key" => "path_nav001",
        "investigation_id" => "inv_uk_inflation_2023",
        "audience_type" => "researcher",
        "name" => "Methodology-focused path",
        "description" => "Prioritises methodological rigour",
        "entry_points" => ["claim_abc123"],
        "path_nodes" => [
          %{
            "entity_id" => "claim_abc123",
            "entity_type" => "claim",
            "order" => 1
          }
        ],
        "metadata" => %{},
        "created_by" => "researcher_1",
        "inserted_at" => "2026-01-20T09:00:00Z",
        "updated_at" => "2026-01-20T09:00:00Z"
      },
      overrides
    )
  end

  # -- PROMPT scores fixtures --

  def high_methodology_scores do
    %PromptScores{
      provenance: 60,
      replicability: 80,
      objective: 70,
      methodology: 95,
      publication: 85,
      transparency: 90
    }
  end

  def balanced_scores do
    %PromptScores{
      provenance: 50,
      replicability: 50,
      objective: 50,
      methodology: 50,
      publication: 50,
      transparency: 50
    }
  end

  def max_scores do
    %PromptScores{
      provenance: 100,
      replicability: 100,
      objective: 100,
      methodology: 100,
      publication: 100,
      transparency: 100
    }
  end

  def zero_scores do
    %PromptScores{
      provenance: 0,
      replicability: 0,
      objective: 0,
      methodology: 0,
      publication: 0,
      transparency: 0
    }
  end

  # -- Zotero fixtures --

  def zotero_journal_article do
    %{
      "key" => "ZKEY_JOURNAL",
      "version" => 12,
      "library" => %{"id" => 123_456},
      "data" => %{
        "key" => "ZKEY_JOURNAL",
        "version" => 12,
        "itemType" => "journalArticle",
        "title" => "The Distributional Impact of Inflation in the UK",
        "url" => "https://doi.org/10.1234/example",
        "DOI" => "10.1234/example",
        "date" => "2023-06-15",
        "publisher" => "Economic Journal",
        "abstractNote" => "This paper examines how inflation affects different income groups.",
        "language" => "en",
        "rights" => "CC-BY-4.0",
        "libraryCatalog" => "DOI.org (Crossref)",
        "creators" => [
          %{"firstName" => "Jane", "lastName" => "Smith"},
          %{"firstName" => "John", "lastName" => "Doe"}
        ],
        "tags" => [
          %{"tag" => "inflation"},
          %{"tag" => "UK economy"},
          %{"tag" => "inequality"}
        ],
        "collections" => ["COL_ABC"],
        "dateModified" => "2026-01-10T08:30:00Z"
      }
    }
  end

  def zotero_dataset do
    %{
      "key" => "ZKEY_DATA",
      "version" => 3,
      "data" => %{
        "key" => "ZKEY_DATA",
        "version" => 3,
        "itemType" => "dataset",
        "title" => "CPI Microdata 2020-2023",
        "url" => "https://example.org/data",
        "date" => "2023-12-01",
        "creators" => [%{"name" => "ONS"}],
        "tags" => [%{"tag" => "CPI"}, %{"tag" => "microdata"}],
        "collections" => [],
        "dateModified" => "2026-01-05T12:00:00Z"
      }
    }
  end
end

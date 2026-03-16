# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
defmodule EvidenceGraph.Claims.ClaimTest do
  use ExUnit.Case, async: true

  alias EvidenceGraph.Claims.Claim
  alias EvidenceGraph.PromptScores
  import EvidenceGraph.Fixtures

  describe "changeset/2 required fields" do
    test "valid attributes produce a valid changeset" do
      changeset = Claim.changeset(%Claim{}, valid_claim_attrs())
      assert changeset.valid?
    end

    test "requires investigation_id" do
      changeset = Claim.changeset(%Claim{}, valid_claim_attrs(%{investigation_id: nil}))
      refute changeset.valid?
      assert Keyword.has_key?(changeset.errors, :investigation_id)
    end

    test "requires text" do
      changeset = Claim.changeset(%Claim{}, valid_claim_attrs(%{text: nil}))
      refute changeset.valid?
      assert Keyword.has_key?(changeset.errors, :text)
    end

    test "requires claim_type" do
      changeset = Claim.changeset(%Claim{}, valid_claim_attrs(%{claim_type: nil}))
      refute changeset.valid?
      assert Keyword.has_key?(changeset.errors, :claim_type)
    end
  end

  describe "changeset/2 validations" do
    test "text must be at least 10 characters" do
      changeset = Claim.changeset(%Claim{}, valid_claim_attrs(%{text: "Too short"}))
      refute changeset.valid?
      assert Keyword.has_key?(changeset.errors, :text)
    end

    test "text can be up to 5000 characters" do
      long_text = String.duplicate("a", 5000)
      changeset = Claim.changeset(%Claim{}, valid_claim_attrs(%{text: long_text}))
      assert changeset.valid?
    end

    test "text over 5000 characters is rejected" do
      long_text = String.duplicate("a", 5001)
      changeset = Claim.changeset(%Claim{}, valid_claim_attrs(%{text: long_text}))
      refute changeset.valid?
    end

    test "claim_type must be :primary, :supporting, or :counter" do
      for valid_type <- [:primary, :supporting, :counter] do
        changeset = Claim.changeset(%Claim{}, valid_claim_attrs(%{claim_type: valid_type}))
        assert changeset.valid?, "Expected #{valid_type} to be valid"
      end
    end

    test "invalid claim_type is rejected" do
      changeset = Claim.changeset(%Claim{}, valid_claim_attrs(%{claim_type: :invalid}))
      refute changeset.valid?
    end

    test "confidence_level must be between 0.0 and 1.0" do
      assert Claim.changeset(%Claim{}, valid_claim_attrs(%{confidence_level: 0.0})).valid?
      assert Claim.changeset(%Claim{}, valid_claim_attrs(%{confidence_level: 1.0})).valid?
      assert Claim.changeset(%Claim{}, valid_claim_attrs(%{confidence_level: 0.5})).valid?
    end

    test "confidence_level above 1.0 is rejected" do
      changeset = Claim.changeset(%Claim{}, valid_claim_attrs(%{confidence_level: 1.1}))
      refute changeset.valid?
    end

    test "negative confidence_level is rejected" do
      changeset = Claim.changeset(%Claim{}, valid_claim_attrs(%{confidence_level: -0.1}))
      refute changeset.valid?
    end

    test "defaults confidence_level to 0.5" do
      claim = %Claim{}
      assert claim.confidence_level == 0.5
    end
  end

  describe "changeset/2 ID generation" do
    test "auto-generates ID with claim_ prefix for new records" do
      changeset = Claim.changeset(%Claim{}, valid_claim_attrs())
      id = Ecto.Changeset.get_change(changeset, :id)
      assert String.starts_with?(id, "claim_")
    end

    test "does not overwrite existing ID" do
      claim = %Claim{id: "claim_existing"}
      changeset = Claim.changeset(claim, valid_claim_attrs())
      refute Ecto.Changeset.get_change(changeset, :id)
    end
  end

  describe "to_arango_doc/1" do
    test "converts claim struct to ArangoDB document" do
      claim = %Claim{
        id: "claim_test1",
        investigation_id: "inv_1",
        text: "Test claim text for inflation analysis",
        claim_type: :primary,
        confidence_level: 0.85,
        prompt_scores: %PromptScores{provenance: 80, replicability: 70},
        created_by: "researcher_1",
        metadata: %{"source" => "manual"},
        inserted_at: ~U[2026-01-15 10:30:00Z],
        updated_at: ~U[2026-01-15 10:30:00Z]
      }

      doc = Claim.to_arango_doc(claim)

      assert doc._key == "claim_test1"
      assert doc.investigation_id == "inv_1"
      assert doc.text == "Test claim text for inflation analysis"
      assert doc.claim_type == "primary"
      assert doc.confidence_level == 0.85
      assert doc.created_by == "researcher_1"
      assert doc.metadata == %{"source" => "manual"}
      assert is_map(doc.prompt_scores)
    end

    test "converts claim_type atom to string" do
      for {atom, string} <- [{:primary, "primary"}, {:supporting, "supporting"}, {:counter, "counter"}] do
        claim = %Claim{
          id: "test",
          investigation_id: "inv",
          text: "Test claim",
          claim_type: atom,
          prompt_scores: %PromptScores{}
        }

        assert Claim.to_arango_doc(claim).claim_type == string
      end
    end
  end

  describe "from_arango_doc/1" do
    test "converts ArangoDB document to claim struct" do
      doc = claim_arango_doc()
      claim = Claim.from_arango_doc(doc)

      assert claim.id == "claim_abc123"
      assert claim.investigation_id == "inv_uk_inflation_2023"
      assert claim.claim_type == :primary
      assert claim.confidence_level == 0.85
      assert claim.created_by == "researcher_1"
      assert %PromptScores{} = claim.prompt_scores
    end

    test "parses prompt_scores from map" do
      doc = claim_arango_doc()
      claim = Claim.from_arango_doc(doc)

      assert claim.prompt_scores.provenance == 80
      assert claim.prompt_scores.methodology == 90
    end

    test "handles nil prompt_scores" do
      doc = claim_arango_doc(%{"prompt_scores" => nil})
      claim = Claim.from_arango_doc(doc)
      assert %PromptScores{} = claim.prompt_scores
    end

    test "handles nil metadata" do
      doc = claim_arango_doc(%{"metadata" => nil})
      claim = Claim.from_arango_doc(doc)
      assert claim.metadata == %{}
    end

    test "parses ISO 8601 datetime strings" do
      doc = claim_arango_doc()
      claim = Claim.from_arango_doc(doc)
      assert %DateTime{} = claim.inserted_at
      assert claim.inserted_at.year == 2026
    end

    test "handles nil datetime" do
      doc = claim_arango_doc(%{"inserted_at" => nil, "updated_at" => nil})
      claim = Claim.from_arango_doc(doc)
      assert is_nil(claim.inserted_at)
      assert is_nil(claim.updated_at)
    end
  end

  describe "round-trip conversion" do
    test "to_arango_doc then from_arango_doc preserves key fields" do
      original = %Claim{
        id: "claim_roundtrip",
        investigation_id: "inv_rt",
        text: "Round trip test claim for verification",
        claim_type: :counter,
        confidence_level: 0.75,
        prompt_scores: %PromptScores{provenance: 88, methodology: 92},
        created_by: "tester",
        metadata: %{},
        inserted_at: ~U[2026-02-01 12:00:00Z],
        updated_at: ~U[2026-02-01 12:00:00Z]
      }

      doc = Claim.to_arango_doc(original)

      # Simulate ArangoDB returning string keys
      string_doc =
        for {k, v} <- doc, into: %{} do
          {to_string(k), v}
        end

      recovered = Claim.from_arango_doc(string_doc)

      assert recovered.id == original.id
      assert recovered.investigation_id == original.investigation_id
      assert recovered.text == original.text
      assert recovered.claim_type == original.claim_type
      assert recovered.confidence_level == original.confidence_level
    end
  end
end

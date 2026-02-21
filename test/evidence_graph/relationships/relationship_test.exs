# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
defmodule EvidenceGraph.Relationships.RelationshipTest do
  use ExUnit.Case, async: true

  alias EvidenceGraph.Relationships.Relationship
  import EvidenceGraph.Fixtures

  describe "changeset/2 required fields" do
    test "valid attributes produce a valid changeset" do
      changeset = Relationship.changeset(%Relationship{}, valid_relationship_attrs())
      assert changeset.valid?
    end

    test "requires from_id" do
      changeset = Relationship.changeset(%Relationship{}, valid_relationship_attrs(%{from_id: nil}))
      refute changeset.valid?
      assert Keyword.has_key?(changeset.errors, :from_id)
    end

    test "requires from_type" do
      changeset = Relationship.changeset(%Relationship{}, valid_relationship_attrs(%{from_type: nil}))
      refute changeset.valid?
      assert Keyword.has_key?(changeset.errors, :from_type)
    end

    test "requires to_id" do
      changeset = Relationship.changeset(%Relationship{}, valid_relationship_attrs(%{to_id: nil}))
      refute changeset.valid?
      assert Keyword.has_key?(changeset.errors, :to_id)
    end

    test "requires to_type" do
      changeset = Relationship.changeset(%Relationship{}, valid_relationship_attrs(%{to_type: nil}))
      refute changeset.valid?
      assert Keyword.has_key?(changeset.errors, :to_type)
    end

    test "requires relationship_type" do
      changeset = Relationship.changeset(%Relationship{}, valid_relationship_attrs(%{relationship_type: nil}))
      refute changeset.valid?
      assert Keyword.has_key?(changeset.errors, :relationship_type)
    end
  end

  describe "changeset/2 validations" do
    test "all relationship types are accepted" do
      for type <- [:supports, :contradicts, :contextualizes] do
        changeset = Relationship.changeset(%Relationship{}, valid_relationship_attrs(%{relationship_type: type}))
        assert changeset.valid?, "Expected #{type} to be valid"
      end
    end

    test "invalid relationship_type is rejected" do
      changeset =
        Relationship.changeset(%Relationship{}, valid_relationship_attrs(%{relationship_type: :invalid}))

      refute changeset.valid?
    end

    test "weight must be between -1.0 and 1.0" do
      assert Relationship.changeset(%Relationship{}, valid_relationship_attrs(%{weight: -1.0})).valid?
      assert Relationship.changeset(%Relationship{}, valid_relationship_attrs(%{weight: 0.0})).valid?
      assert Relationship.changeset(%Relationship{}, valid_relationship_attrs(%{weight: 1.0})).valid?
    end

    test "weight above 1.0 is rejected" do
      changeset = Relationship.changeset(%Relationship{}, valid_relationship_attrs(%{weight: 1.1}))
      refute changeset.valid?
    end

    test "weight below -1.0 is rejected" do
      changeset = Relationship.changeset(%Relationship{}, valid_relationship_attrs(%{weight: -1.1}))
      refute changeset.valid?
    end

    test "confidence must be between 0.0 and 1.0" do
      assert Relationship.changeset(%Relationship{}, valid_relationship_attrs(%{confidence: 0.0})).valid?
      assert Relationship.changeset(%Relationship{}, valid_relationship_attrs(%{confidence: 1.0})).valid?
    end

    test "negative confidence is rejected" do
      changeset = Relationship.changeset(%Relationship{}, valid_relationship_attrs(%{confidence: -0.1}))
      refute changeset.valid?
    end

    test "confidence above 1.0 is rejected" do
      changeset = Relationship.changeset(%Relationship{}, valid_relationship_attrs(%{confidence: 1.1}))
      refute changeset.valid?
    end

    test "from_type must be :claim or :evidence" do
      assert Relationship.changeset(%Relationship{}, valid_relationship_attrs(%{from_type: :claim})).valid?
      assert Relationship.changeset(%Relationship{}, valid_relationship_attrs(%{from_type: :evidence})).valid?
    end

    test "invalid from_type is rejected" do
      changeset = Relationship.changeset(%Relationship{}, valid_relationship_attrs(%{from_type: :path}))
      refute changeset.valid?
    end

    test "defaults weight to 0.5" do
      rel = %Relationship{}
      assert rel.weight == 0.5
    end

    test "defaults confidence to 0.5" do
      rel = %Relationship{}
      assert rel.confidence == 0.5
    end
  end

  describe "changeset/2 ID generation" do
    test "auto-generates ID with rel_ prefix" do
      changeset = Relationship.changeset(%Relationship{}, valid_relationship_attrs())
      id = Ecto.Changeset.get_change(changeset, :id)
      assert String.starts_with?(id, "rel_")
    end
  end

  describe "to_arango_doc/1" do
    test "converts to edge document with _from and _to" do
      rel = %Relationship{
        id: "rel_test1",
        from_id: "evidence_1",
        from_type: :evidence,
        to_id: "claim_1",
        to_type: :claim,
        relationship_type: :supports,
        weight: 0.8,
        confidence: 0.9,
        reasoning: "Direct evidence",
        metadata: %{}
      }

      doc = Relationship.to_arango_doc(rel)

      assert doc._key == "rel_test1"
      assert doc._from == "evidences/evidence_1"
      assert doc._to == "claims/claim_1"
      assert doc.relationship_type == "supports"
      assert doc.weight == 0.8
      assert doc.confidence == 0.9
    end

    test "converts relationship_type atom to string" do
      for {atom, string} <- [
            {:supports, "supports"},
            {:contradicts, "contradicts"},
            {:contextualizes, "contextualizes"}
          ] do
        rel = %Relationship{
          id: "test",
          from_id: "e1",
          from_type: :evidence,
          to_id: "c1",
          to_type: :claim,
          relationship_type: atom,
          metadata: %{}
        }

        assert Relationship.to_arango_doc(rel).relationship_type == string
      end
    end
  end

  describe "from_arango_doc/1" do
    test "parses edge document with _from/_to references" do
      doc = relationship_arango_doc()
      rel = Relationship.from_arango_doc(doc)

      assert rel.id == "rel_edge001"
      assert rel.from_id == "evidence_xyz789"
      assert rel.from_type == :evidence
      assert rel.to_id == "claim_abc123"
      assert rel.to_type == :claim
      assert rel.relationship_type == :supports
      assert rel.weight == 0.8
      assert rel.confidence == 0.9
    end

    test "handles nil metadata" do
      doc = relationship_arango_doc(%{"metadata" => nil})
      rel = Relationship.from_arango_doc(doc)
      assert rel.metadata == %{}
    end
  end

  describe "effective_weight/1" do
    test "multiplies weight by confidence" do
      rel = %Relationship{
        weight: 0.8,
        confidence: 0.9,
        from_id: "e1",
        from_type: :evidence,
        to_id: "c1",
        to_type: :claim,
        relationship_type: :supports,
        metadata: %{}
      }

      assert_in_delta Relationship.effective_weight(rel), 0.72, 0.001
    end

    test "full confidence preserves weight" do
      rel = %Relationship{
        weight: 0.5,
        confidence: 1.0,
        from_id: "e1",
        from_type: :evidence,
        to_id: "c1",
        to_type: :claim,
        relationship_type: :supports,
        metadata: %{}
      }

      assert_in_delta Relationship.effective_weight(rel), 0.5, 0.001
    end

    test "zero confidence zeroes effective weight" do
      rel = %Relationship{
        weight: 0.9,
        confidence: 0.0,
        from_id: "e1",
        from_type: :evidence,
        to_id: "c1",
        to_type: :claim,
        relationship_type: :supports,
        metadata: %{}
      }

      assert_in_delta Relationship.effective_weight(rel), 0.0, 0.001
    end

    test "negative weight with positive confidence produces negative effective weight" do
      rel = %Relationship{
        weight: -0.7,
        confidence: 0.8,
        from_id: "e1",
        from_type: :evidence,
        to_id: "c1",
        to_type: :claim,
        relationship_type: :contradicts,
        metadata: %{}
      }

      assert_in_delta Relationship.effective_weight(rel), -0.56, 0.001
    end
  end
end

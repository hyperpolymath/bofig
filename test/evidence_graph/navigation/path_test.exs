# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
defmodule EvidenceGraph.Navigation.PathTest do
  use ExUnit.Case, async: true

  alias EvidenceGraph.Navigation.Path
  import EvidenceGraph.Fixtures

  describe "changeset/2 required fields" do
    test "valid attributes produce a valid changeset" do
      changeset = Path.changeset(%Path{}, valid_path_attrs())
      assert changeset.valid?
    end

    test "requires investigation_id" do
      changeset = Path.changeset(%Path{}, valid_path_attrs(%{investigation_id: nil}))
      refute changeset.valid?
      assert Keyword.has_key?(changeset.errors, :investigation_id)
    end

    test "requires audience_type" do
      changeset = Path.changeset(%Path{}, valid_path_attrs(%{audience_type: nil}))
      refute changeset.valid?
      assert Keyword.has_key?(changeset.errors, :audience_type)
    end

    test "requires name" do
      changeset = Path.changeset(%Path{}, valid_path_attrs(%{name: nil}))
      refute changeset.valid?
      assert Keyword.has_key?(changeset.errors, :name)
    end
  end

  describe "changeset/2 validations" do
    test "all audience types are accepted" do
      for type <- [:activist, :policymaker, :researcher, :skeptic, :affected_person, :journalist] do
        changeset = Path.changeset(%Path{}, valid_path_attrs(%{audience_type: type}))
        assert changeset.valid?, "Expected #{type} to be valid"
      end
    end

    test "invalid audience_type is rejected" do
      changeset = Path.changeset(%Path{}, valid_path_attrs(%{audience_type: :invalid}))
      refute changeset.valid?
    end

    test "name must be at least 3 characters" do
      changeset = Path.changeset(%Path{}, valid_path_attrs(%{name: "AB"}))
      refute changeset.valid?
    end

    test "name over 200 characters is rejected" do
      long_name = String.duplicate("a", 201)
      changeset = Path.changeset(%Path{}, valid_path_attrs(%{name: long_name}))
      refute changeset.valid?
    end

    test "name of exactly 200 characters is accepted" do
      name = String.duplicate("a", 200)
      changeset = Path.changeset(%Path{}, valid_path_attrs(%{name: name}))
      assert changeset.valid?
    end
  end

  describe "changeset/2 path_nodes validation" do
    test "valid path_nodes are accepted" do
      nodes = [
        %{"entity_id" => "claim_1", "entity_type" => "claim", "order" => 1},
        %{"entity_id" => "evidence_1", "entity_type" => "evidence", "order" => 2}
      ]

      changeset = Path.changeset(%Path{}, valid_path_attrs(%{path_nodes: nodes}))
      assert changeset.valid?
    end

    test "path_nodes with invalid entity_type are rejected" do
      nodes = [
        %{"entity_id" => "x", "entity_type" => "path", "order" => 1}
      ]

      changeset = Path.changeset(%Path{}, valid_path_attrs(%{path_nodes: nodes}))
      refute changeset.valid?
      assert Keyword.has_key?(changeset.errors, :path_nodes)
    end

    test "path_nodes with non-integer order are rejected" do
      nodes = [
        %{"entity_id" => "claim_1", "entity_type" => "claim", "order" => "first"}
      ]

      changeset = Path.changeset(%Path{}, valid_path_attrs(%{path_nodes: nodes}))
      refute changeset.valid?
    end

    test "path_nodes missing required keys are rejected" do
      nodes = [
        %{"entity_id" => "claim_1"}
      ]

      changeset = Path.changeset(%Path{}, valid_path_attrs(%{path_nodes: nodes}))
      refute changeset.valid?
    end

    test "empty path_nodes list is accepted" do
      changeset = Path.changeset(%Path{}, valid_path_attrs(%{path_nodes: []}))
      assert changeset.valid?
    end

    test "defaults path_nodes to empty list" do
      path = %Path{}
      assert path.path_nodes == []
    end

    test "defaults entry_points to empty list" do
      path = %Path{}
      assert path.entry_points == []
    end
  end

  describe "changeset/2 ID generation" do
    test "auto-generates ID with path_ prefix" do
      changeset = Path.changeset(%Path{}, valid_path_attrs())
      id = Ecto.Changeset.get_change(changeset, :id)
      assert String.starts_with?(id, "path_")
    end
  end

  describe "to_arango_doc/1" do
    test "converts path struct to ArangoDB document" do
      path = %Path{
        id: "path_test1",
        investigation_id: "inv_1",
        audience_type: :researcher,
        name: "Research path",
        description: "For researchers",
        entry_points: ["claim_1"],
        path_nodes: [%{"entity_id" => "claim_1", "entity_type" => "claim", "order" => 1}],
        metadata: %{},
        created_by: "auto",
        inserted_at: ~U[2026-01-20 09:00:00Z],
        updated_at: ~U[2026-01-20 09:00:00Z]
      }

      doc = Path.to_arango_doc(path)

      assert doc._key == "path_test1"
      assert doc.audience_type == "researcher"
      assert doc.name == "Research path"
      assert doc.entry_points == ["claim_1"]
      assert length(doc.path_nodes) == 1
    end
  end

  describe "from_arango_doc/1" do
    test "converts ArangoDB document to path struct" do
      doc = path_arango_doc()
      path = Path.from_arango_doc(doc)

      assert path.id == "path_nav001"
      assert path.audience_type == :researcher
      assert path.name == "Methodology-focused path"
      assert path.entry_points == ["claim_abc123"]
      assert length(path.path_nodes) == 1
    end

    test "handles nil optional fields" do
      doc =
        path_arango_doc(%{
          "entry_points" => nil,
          "path_nodes" => nil,
          "metadata" => nil
        })

      path = Path.from_arango_doc(doc)
      assert path.entry_points == []
      assert path.path_nodes == []
      assert path.metadata == %{}
    end
  end

  describe "audience_description/1" do
    test "returns description for all audience types" do
      for type <- [:researcher, :policymaker, :skeptic, :activist, :affected_person, :journalist] do
        desc = Path.audience_description(type)
        assert is_binary(desc)
        assert String.length(desc) > 10
      end
    end
  end

  describe "prompt_weights/1" do
    test "delegates to PromptScores.audience_weights" do
      weights = Path.prompt_weights(:researcher)
      assert is_map(weights)
      assert Map.has_key?(weights, :methodology)
    end
  end
end

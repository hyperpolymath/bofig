# SPDX-License-Identifier: MPL-2.0
defmodule EvidenceGraph.ContextUpdatesTest do
  use ExUnit.Case, async: false

  alias EvidenceGraph.ArangoDB
  alias EvidenceGraph.Claims
  alias EvidenceGraph.Evidence
  alias EvidenceGraph.Fixtures
  alias EvidenceGraph.Navigation
  alias EvidenceGraph.Relationships

  for {context, collection, create, update, get, fixture, field, invalid, valid} <- [
        {Claims, "claims", :create_claim, :update_claim, :get_claim, :valid_claim_attrs, :text,
         "", "Updated investigative claim"},
        {Evidence, "evidence", :create_evidence, :update_evidence, :get_evidence,
         :valid_evidence_attrs, :title, "", "Updated evidence title"},
        {Relationships, "relationships", :create_relationship, :update_relationship,
         :get_relationship, :valid_relationship_attrs, :weight, -2.0, 0.5},
        {Navigation, "navigation_paths", :create_path, :update_path, :get_path, :valid_path_attrs,
         :name, "", "Updated navigation path"}
      ] do
    @context context
    @collection collection
    @create create
    @update update
    @get get
    @fixture fixture
    @field field
    @invalid invalid
    @valid valid

    test "#{collection} updates preserve records on validation errors and accept valid changes" do
      attrs = apply(Fixtures, @fixture, [])
      assert {:ok, original} = apply(@context, @create, [attrs])
      on_exit(fn -> ArangoDB.delete(@collection, original.id) end)

      assert {:error, %Ecto.Changeset{valid?: false} = changeset} =
               apply(@context, @update, [original.id, %{@field => @invalid}])

      assert Keyword.has_key?(changeset.errors, @field)
      assert {:ok, ^original} = apply(@context, @get, [original.id])

      assert {:ok, updated} = apply(@context, @update, [original.id, %{@field => @valid}])
      assert Map.fetch!(updated, @field) == @valid
      assert updated.id == original.id
      assert updated.inserted_at == original.inserted_at
      assert {:ok, ^updated} = apply(@context, @get, [original.id])
    end

    test "#{collection} updates return not_found for a missing record" do
      assert {:error, :not_found} =
               apply(@context, @update, ["missing_#{Ecto.UUID.generate()}", %{@field => @valid}])
    end
  end
end

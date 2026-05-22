# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
defmodule EvidenceGraphWeb.Schema.Types.EntityTypes do
  @moduledoc """
  Absinthe type definitions for the Entity Resolution module.
  """

  use Absinthe.Schema.Notation

  # ---------------------------------------------------------------------------
  # Object types
  # ---------------------------------------------------------------------------

  @desc "An entity (person, organisation, location, etc.) in the evidence graph"
  object :entity do
    field :id, non_null(:id)
    field :primary_name, non_null(:string)
    field :entity_type, non_null(:entity_type_enum)
    field :aliases, list_of(:string)
    field :description, :string
    field :investigation_id, non_null(:string)
    field :first_appearance_date, :date
    field :document_count, non_null(:integer)
    field :credibility_score, :integer
    field :metadata, :json
    field :inserted_at, non_null(:datetime)
    field :updated_at, non_null(:datetime)

    @desc "Evidence documents that mention this entity"
    field :documents, list_of(:evidence) do
      resolve(fn entity, _args, _resolution ->
        EvidenceGraph.Entities.get_entity_documents(entity.id)
      end)
    end
  end

  @desc "Result of resolving a single NER string"
  object :ner_resolution_result do
    field :ner_string, non_null(:string)
    field :status, non_null(:ner_status_enum)
    field :entity, :entity
    field :similarity, :float
  end

  # ---------------------------------------------------------------------------
  # Enums
  # ---------------------------------------------------------------------------

  enum :entity_type_enum do
    value :person, description: "Individual person"
    value :organization, description: "Organisation or company"
    value :location, description: "Geographic location"
    value :account, description: "Financial or online account"
    value :vessel, description: "Ship or watercraft"
    value :aircraft, description: "Aircraft"
  end

  enum :ner_status_enum do
    value :existing, description: "Exact match to existing entity"
    value :suggest_merge, description: "Fuzzy match above threshold; review recommended"
    value :created, description: "No match found; new entity created"
    value :error, description: "Resolution failed"
  end

  # ---------------------------------------------------------------------------
  # Input objects
  # ---------------------------------------------------------------------------

  input_object :create_entity_input do
    field :primary_name, non_null(:string)
    field :entity_type, non_null(:entity_type_enum)
    field :investigation_id, non_null(:string)
    field :aliases, list_of(:string)
    field :description, :string
    field :first_appearance_date, :date
    field :credibility_score, :integer
    field :metadata, :json
  end

  input_object :merge_entities_input do
    @desc "The entity that will absorb the source"
    field :target_id, non_null(:id)
    @desc "The entity that will be merged into the target and deleted"
    field :source_id, non_null(:id)
    @desc "Human-readable rationale for the merge (stored for audit)"
    field :rationale, non_null(:string)
  end

  input_object :resolve_ner_input do
    field :ner_strings, non_null(list_of(non_null(:string)))
    field :investigation_id, non_null(:string)
  end
end

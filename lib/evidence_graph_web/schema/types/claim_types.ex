# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
defmodule EvidenceGraphWeb.Schema.Types.ClaimTypes do
  use Absinthe.Schema.Notation
  @desc "A claim in an investigation"
  object :claim do
    field :id, non_null(:id)
    field :investigation_id, non_null(:string)
    field :text, non_null(:string)
    field :claim_type, non_null(:claim_type_enum)
    field :confidence_level, non_null(:float)
    field :prompt_scores, non_null(:prompt_scores)
    field :created_by, :string
    field :metadata, :json
    field :inserted_at, non_null(:datetime)
    field :updated_at, non_null(:datetime)

    # Relationships
    field :supporting_evidence, list_of(:evidence_with_relationship) do
      resolve(fn claim, _args, _resolution ->
        EvidenceGraph.Claims.get_supporting_evidence(claim.id)
      end)
    end

    field :contradicting_evidence, list_of(:evidence_with_relationship) do
      resolve(fn claim, _args, _resolution ->
        EvidenceGraph.Claims.get_contradicting_evidence(claim.id)
      end)
    end
  end

  @desc "Evidence with relationship metadata"
  object :evidence_with_relationship do
    field :evidence, non_null(:evidence)
    field :weight, non_null(:float)
    field :confidence, non_null(:float)
    field :reasoning, :string
  end

  enum :claim_type_enum do
    value :primary, description: "Primary claim of the investigation"
    value :supporting, description: "Supporting sub-claim"
    value :counter, description: "Counter-claim or alternative"
  end

  input_object :create_claim_input do
    field :investigation_id, non_null(:string)
    field :text, non_null(:string)
    field :claim_type, non_null(:claim_type_enum)
    field :confidence_level, :float
    field :prompt_scores, :prompt_scores_input
    field :created_by, :string
  end

  input_object :update_claim_input do
    field :text, :string
    field :claim_type, :claim_type_enum
    field :confidence_level, :float
    field :prompt_scores, :prompt_scores_input
  end
end

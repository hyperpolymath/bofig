# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
defmodule EvidenceGraphWeb.Schema.Types.EvidenceTypes do
  use Absinthe.Schema.Notation

  @desc "Evidence supporting or contradicting claims"
  object :evidence do
    field :id, non_null(:id)
    field :investigation_id, non_null(:string)
    field :title, non_null(:string)
    field :evidence_type, non_null(:evidence_type_enum)
    field :source_url, :string
    field :local_path, :string
    field :ipfs_hash, :string
    field :zotero_key, :string
    field :zotero_version, :integer
    field :dublin_core, :json
    field :schema_org, :json
    field :prompt_scores, non_null(:prompt_scores)
    field :tags, list_of(:string)
    field :metadata, :json
    field :inserted_at, non_null(:datetime)
    field :updated_at, non_null(:datetime)

    field :supported_claims, list_of(:claim_with_relationship) do
      resolve(fn evidence, _args, _ ->
        EvidenceGraph.Evidence.get_supported_claims(evidence.id)
      end)
    end
  end

  @desc "Claim with relationship metadata"
  object :claim_with_relationship do
    field :claim, non_null(:claim)
    field :weight, non_null(:float)
    field :confidence, non_null(:float)
    field :reasoning, :string
  end

  enum :evidence_type_enum do
    value :document, description: "Document (paper, report, article)"
    value :dataset, description: "Structured dataset"
    value :interview, description: "Interview or testimony"
    value :media, description: "Audio/video media"
    value :other, description: "Other type"
  end

  input_object :create_evidence_input do
    field :investigation_id, non_null(:string)
    field :title, non_null(:string)
    field :evidence_type, non_null(:evidence_type_enum)
    field :source_url, :string
    field :zotero_key, :string
    field :dublin_core, :json
    field :schema_org, :json
    field :prompt_scores, :prompt_scores_input
    field :tags, list_of(:string)
    field :metadata, :json
  end

  input_object :update_evidence_input do
    field :title, :string
    field :source_url, :string
    field :prompt_scores, :prompt_scores_input
    field :tags, list_of(:string)
  end
end

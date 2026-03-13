# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
defmodule EvidenceGraphWeb.Schema.Types.InvestigationTypes do
  @moduledoc """
  Absinthe type definitions for the Investigations module.
  """

  use Absinthe.Schema.Notation

  @desc "An investigation — top-level container for all evidence, claims, entities"
  object :investigation do
    field :id, non_null(:id)
    field :title, non_null(:string)
    field :description, :string
    field :created_by, :string
    field :status, non_null(:string)
    field :metadata, :json
    field :inserted_at, :string
    field :updated_at, :string
  end

  @desc "Aggregate statistics for an investigation"
  object :investigation_stats do
    field :evidence_count, non_null(:integer)
    field :claim_count, non_null(:integer)
    field :entity_count, non_null(:integer)
    field :transaction_count, non_null(:integer)
    field :relationship_count, non_null(:integer)
    field :avg_prompt_score, non_null(:float)
    field :contradiction_count, non_null(:integer)
  end

  input_object :create_investigation_input do
    field :title, non_null(:string)
    field :description, :string
    field :created_by, :string
    field :status, :string
    field :metadata, :json
  end

  input_object :update_investigation_input do
    field :title, :string
    field :description, :string
    field :status, :string
    field :metadata, :json
  end

  input_object :share_evidence_input do
    field :from_investigation_id, non_null(:string)
    field :to_investigation_id, non_null(:string)
    field :evidence_ids, non_null(list_of(non_null(:string)))
  end
end

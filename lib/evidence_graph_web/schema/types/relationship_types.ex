# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
defmodule EvidenceGraphWeb.Schema.Types.RelationshipTypes do
  use Absinthe.Schema.Notation

  @desc "Relationship between claims and evidence"
  object :relationship do
    field :id, non_null(:id)
    field :from_id, non_null(:string)
    field :from_type, non_null(:node_type_enum)
    field :to_id, non_null(:string)
    field :to_type, non_null(:node_type_enum)
    field :relationship_type, non_null(:relationship_type_enum)
    field :weight, non_null(:float)
    field :confidence, non_null(:float)
    field :reasoning, :string
    field :created_by, :string
    field :metadata, :json
    field :inserted_at, non_null(:datetime)
  end

  enum :relationship_type_enum do
    value :supports, description: "Evidence supports claim"
    value :contradicts, description: "Evidence contradicts claim"
    value :contextualizes, description: "Provides context"
  end

  enum :node_type_enum do
    value :claim
    value :evidence
  end

  input_object :create_relationship_input do
    field :from_id, non_null(:string)
    field :from_type, non_null(:node_type_enum)
    field :to_id, non_null(:string)
    field :to_type, non_null(:node_type_enum)
    field :relationship_type, non_null(:relationship_type_enum)
    field :weight, non_null(:float)
    field :confidence, non_null(:float)
    field :reasoning, :string
    field :created_by, :string
  end
end

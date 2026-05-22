# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
defmodule EvidenceGraphWeb.Schema.Types.NavigationTypes do
  use Absinthe.Schema.Notation

  @desc "Navigation path for specific audience"
  object :navigation_path do
    field :id, non_null(:id)
    field :investigation_id, non_null(:string)
    field :audience_type, non_null(:audience_type_enum)
    field :name, non_null(:string)
    field :description, :string
    field :entry_points, list_of(:string)
    field :path_nodes, list_of(:path_node)
    field :metadata, :json
    field :created_by, :string
    field :inserted_at, non_null(:datetime)
    field :updated_at, non_null(:datetime)
  end

  @desc "Node in a navigation path"
  object :path_node do
    field :entity_id, non_null(:string)
    field :entity_type, non_null(:string)
    field :order, non_null(:integer)
    field :context, :string
    field :emphasis, :json
  end

  enum :audience_type_enum do
    value :activist, description: "Activists seeking advocacy evidence"
    value :policymaker, description: "Policymakers needing recommendations"
    value :researcher, description: "Academic researchers"
    value :skeptic, description: "Skeptics demanding verification"
    value :affected_person, description: "People directly affected"
    value :journalist, description: "Journalists balancing credibility and story"
  end

  input_object :create_navigation_path_input do
    field :investigation_id, non_null(:string)
    field :audience_type, non_null(:audience_type_enum)
    field :name, non_null(:string)
    field :description, :string
    field :entry_points, list_of(:string)
    field :path_nodes, list_of(:path_node_input)
  end

  input_object :path_node_input do
    field :entity_id, non_null(:string)
    field :entity_type, non_null(:string)
    field :order, non_null(:integer)
    field :context, :string
    field :emphasis, :json
  end
end

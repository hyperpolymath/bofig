# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>

defmodule EvidenceGraphWeb.Schema do
  use Absinthe.Schema

  import_types(Absinthe.Type.Custom)
  import_types(EvidenceGraphWeb.Schema.Types.PromptScoresTypes)
  import_types(EvidenceGraphWeb.Schema.Types.ClaimTypes)
  import_types(EvidenceGraphWeb.Schema.Types.EvidenceTypes)
  import_types(EvidenceGraphWeb.Schema.Types.RelationshipTypes)
  import_types(EvidenceGraphWeb.Schema.Types.NavigationTypes)

  alias EvidenceGraph.{Claims, Evidence, Navigation, Relationships}

  query do
    @desc "Get a claim by ID"
    field :claim, :claim do
      arg(:id, non_null(:id))

      resolve(fn %{id: id}, _ ->
        Claims.get_claim(id)
      end)
    end

    @desc "List claims for an investigation"
    field :claims, list_of(:claim) do
      arg(:investigation_id, non_null(:string))
      arg(:limit, :integer, default_value: 100)
      arg(:offset, :integer, default_value: 0)

      resolve(fn args, _ ->
        Claims.list_claims(args.investigation_id, limit: args.limit, offset: args.offset)
      end)
    end

    @desc "Search claims by text"
    field :search_claims, list_of(:claim) do
      arg(:query, non_null(:string))
      arg(:investigation_id, :string)

      resolve(fn args, _ ->
        Claims.search_claims(args.query, args[:investigation_id])
      end)
    end

    @desc "Get evidence by ID"
    field :evidence, :evidence do
      arg(:id, non_null(:id))

      resolve(fn %{id: id}, _ ->
        Evidence.get_evidence(id)
      end)
    end

    @desc "Get evidence by Zotero key"
    field :evidence_by_zotero_key, :evidence do
      arg(:zotero_key, non_null(:string))

      resolve(fn %{zotero_key: key}, _ ->
        Evidence.get_evidence_by_zotero_key(key)
      end)
    end

    @desc "List evidence for an investigation"
    field :evidence_list, list_of(:evidence) do
      arg(:investigation_id, non_null(:string))
      arg(:limit, :integer, default_value: 100)
      arg(:offset, :integer, default_value: 0)

      resolve(fn args, _ ->
        Evidence.list_evidence(args.investigation_id, limit: args.limit, offset: args.offset)
      end)
    end

    @desc "Search evidence by title/tags"
    field :search_evidence, list_of(:evidence) do
      arg(:query, non_null(:string))
      arg(:investigation_id, :string)

      resolve(fn args, _ ->
        Evidence.search_evidence(args.query, args[:investigation_id])
      end)
    end

    @desc "Get evidence chain from a claim"
    field :evidence_chain, :evidence_graph do
      arg(:claim_id, non_null(:id))
      arg(:max_depth, :integer, default_value: 3)

      resolve(fn args, _ ->
        Relationships.evidence_chain(args.claim_id, args.max_depth)
      end)
    end

    @desc "Get navigation path by ID"
    field :navigation_path, :navigation_path do
      arg(:id, non_null(:id))

      resolve(fn %{id: id}, _ ->
        Navigation.get_path(id)
      end)
    end

    @desc "List navigation paths for investigation"
    field :navigation_paths, list_of(:navigation_path) do
      arg(:investigation_id, non_null(:string))
      arg(:audience_type, :audience_type_enum)

      resolve(fn args, _ ->
        Navigation.list_paths(args.investigation_id, audience_type: args[:audience_type])
      end)
    end
  end

  mutation do
    @desc "Create a new claim"
    field :create_claim, :claim do
      arg(:input, non_null(:create_claim_input))

      resolve(fn %{input: input}, _ ->
        Claims.create_claim(input)
      end)
    end

    @desc "Update a claim"
    field :update_claim, :claim do
      arg(:id, non_null(:id))
      arg(:input, non_null(:update_claim_input))

      resolve(fn %{id: id, input: input}, _ ->
        Claims.update_claim(id, input)
      end)
    end

    @desc "Delete a claim"
    field :delete_claim, :boolean do
      arg(:id, non_null(:id))

      resolve(fn %{id: id}, _ ->
        case Claims.delete_claim(id) do
          :ok -> {:ok, true}
          error -> error
        end
      end)
    end

    @desc "Create evidence"
    field :create_evidence, :evidence do
      arg(:input, non_null(:create_evidence_input))

      resolve(fn %{input: input}, _ ->
        Evidence.create_evidence(input)
      end)
    end

    @desc "Update evidence"
    field :update_evidence, :evidence do
      arg(:id, non_null(:id))
      arg(:input, non_null(:update_evidence_input))

      resolve(fn %{id: id, input: input}, _ ->
        Evidence.update_evidence(id, input)
      end)
    end

    @desc "Import evidence from Zotero JSON"
    field :import_from_zotero, :evidence do
      arg(:zotero_json, non_null(:json))
      arg(:investigation_id, non_null(:string))

      resolve(fn %{zotero_json: json, investigation_id: inv_id}, _ ->
        Evidence.import_from_zotero(json, inv_id)
      end)
    end

    @desc "Create a relationship"
    field :create_relationship, :relationship do
      arg(:input, non_null(:create_relationship_input))

      resolve(fn %{input: input}, _ ->
        Relationships.create_relationship(input)
      end)
    end

    @desc "Update relationship weight/confidence"
    field :update_relationship, :relationship do
      arg(:id, non_null(:id))
      arg(:weight, :float)
      arg(:confidence, :float)

      resolve(fn args, _ ->
        Relationships.update_relationship(args.id, Map.drop(args, [:id]))
      end)
    end

    @desc "Delete a relationship"
    field :delete_relationship, :boolean do
      arg(:id, non_null(:id))

      resolve(fn %{id: id}, _ ->
        case Relationships.delete_relationship(id) do
          :ok -> {:ok, true}
          error -> error
        end
      end)
    end

    @desc "Create a navigation path"
    field :create_navigation_path, :navigation_path do
      arg(:input, non_null(:create_navigation_path_input))

      resolve(fn %{input: input}, _ ->
        # Convert path_nodes input to map format
        path_nodes =
          Enum.map(input[:path_nodes] || [], fn node ->
            %{
              "entity_id" => node.entity_id,
              "entity_type" => node.entity_type,
              "order" => node.order,
              "context" => node[:context],
              "emphasis" => node[:emphasis]
            }
          end)

        Navigation.create_path(Map.put(input, :path_nodes, path_nodes))
      end)
    end

    @desc "Auto-generate navigation path for audience"
    field :auto_generate_path, :navigation_path do
      arg(:investigation_id, non_null(:string))
      arg(:audience_type, non_null(:audience_type_enum))

      resolve(fn args, _ ->
        Navigation.auto_generate_path(args.investigation_id, args.audience_type)
      end)
    end
  end

  # Custom types
  object :evidence_graph do
    field :root_claim, non_null(:claim)
    field :nodes, list_of(:graph_node)
    field :edges, list_of(:relationship)
    field :max_depth, :integer
  end

  union :graph_node do
    types([:claim, :evidence])

    resolve_type(fn
      {:claim, _}, _ -> :claim
      {:evidence, _}, _ -> :evidence
      %{__struct__: EvidenceGraph.Claims.Claim}, _ -> :claim
      %{__struct__: EvidenceGraph.Evidence.Evidence}, _ -> :evidence
    end)
  end

  # Custom scalars
  scalar :json, description: "JSON object" do
    parse(&decode_json/1)
    serialize(&encode_json/1)
  end

  defp decode_json(%Absinthe.Blueprint.Input.String{value: value}) do
    case Jason.decode(value) do
      {:ok, result} -> {:ok, result}
      _ -> :error
    end
  end

  defp decode_json(%Absinthe.Blueprint.Input.Null{}) do
    {:ok, nil}
  end

  defp decode_json(_), do: :error

  defp encode_json(value), do: value
end

# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>

defmodule EvidenceGraphWeb.Schema do
  use Absinthe.Schema

  import_types(Absinthe.Type.Custom)
  import_types(EvidenceGraphWeb.Schema.Types.PromptScoresTypes)
  import_types(EvidenceGraphWeb.Schema.Types.ClaimTypes)
  import_types(EvidenceGraphWeb.Schema.Types.EvidenceTypes)
  import_types(EvidenceGraphWeb.Schema.Types.RelationshipTypes)
  import_types(EvidenceGraphWeb.Schema.Types.NavigationTypes)
  import_types(EvidenceGraphWeb.Schema.Types.EntityTypes)
  import_types(EvidenceGraphWeb.Schema.Types.FinancialTypes)
  import_types(EvidenceGraphWeb.Schema.Types.SearchTypes)
  import_types(EvidenceGraphWeb.Schema.Types.InvestigationTypes)
  import_types(EvidenceGraphWeb.Schema.Types.TestimonyTypes)
  import_types(EvidenceGraphWeb.Schema.Types.ContradictionTypes)
  import_types(EvidenceGraphWeb.Schema.Types.AuthorizationTypes)

  alias EvidenceGraph.{Claims, Evidence, Navigation, Relationships}
  alias EvidenceGraph.{Investigations, Testimony, Contradictions, Search, Authorization}
  alias EvidenceGraph.Entities
  alias EvidenceGraphWeb.Schema.Resolvers.EntityResolver
  alias EvidenceGraphWeb.Schema.Resolvers.FinancialResolver

  # ---------------------------------------------------------------------------
  # Queries
  # ---------------------------------------------------------------------------

  query do
    @desc "Get a claim by ID"
    field :claim, :claim do
      arg(:id, non_null(:id))

      resolve(fn %{id: id}, resolution ->
        with {:ok, user_id} <- require_auth(resolution),
             {:ok, claim} <- Claims.get_claim(id),
             :ok <- Authorization.check_access(claim.investigation_id, user_id, :view) do
          {:ok, claim}
        end
      end)
    end

    @desc "List claims for an investigation"
    field :claims, list_of(:claim) do
      arg(:investigation_id, non_null(:string))
      arg(:limit, :integer, default_value: 100)
      arg(:offset, :integer, default_value: 0)

      resolve(fn args, resolution ->
        with {:ok, user_id} <- require_auth(resolution),
             :ok <- Authorization.check_access(args.investigation_id, user_id, :view) do
          Claims.list_claims(args.investigation_id, limit: args.limit, offset: args.offset)
        end
      end)
    end

    @desc "Search claims by text"
    field :search_claims, list_of(:claim) do
      arg(:query, non_null(:string))
      arg(:investigation_id, :string)

      resolve(fn args, resolution ->
        with {:ok, user_id} <- require_auth(resolution) do
          if inv_id = args[:investigation_id] do
            with :ok <- Authorization.check_access(inv_id, user_id, :view) do
              Claims.search_claims(args.query, inv_id)
            end
          else
            # No investigation_id: search across all, filtered by user's accessible investigations
            Claims.search_claims(args.query, nil)
          end
        end
      end)
    end

    @desc "Get evidence by ID"
    field :evidence, :evidence do
      arg(:id, non_null(:id))

      resolve(fn %{id: id}, resolution ->
        with {:ok, user_id} <- require_auth(resolution),
             {:ok, ev} <- Evidence.get_evidence(id),
             :ok <- Authorization.check_access(ev.investigation_id, user_id, :view) do
          {:ok, ev}
        end
      end)
    end

    @desc "Get evidence by Zotero key"
    field :evidence_by_zotero_key, :evidence do
      arg(:zotero_key, non_null(:string))

      resolve(fn %{zotero_key: key}, resolution ->
        with {:ok, user_id} <- require_auth(resolution),
             {:ok, ev} <- Evidence.get_evidence_by_zotero_key(key),
             :ok <- Authorization.check_access(ev.investigation_id, user_id, :view) do
          {:ok, ev}
        end
      end)
    end

    @desc "List evidence for an investigation"
    field :evidence_list, list_of(:evidence) do
      arg(:investigation_id, non_null(:string))
      arg(:limit, :integer, default_value: 100)
      arg(:offset, :integer, default_value: 0)

      resolve(fn args, resolution ->
        with {:ok, user_id} <- require_auth(resolution),
             :ok <- Authorization.check_access(args.investigation_id, user_id, :view) do
          Evidence.list_evidence(args.investigation_id, limit: args.limit, offset: args.offset)
        end
      end)
    end

    @desc "Search evidence by title/tags"
    field :search_evidence, list_of(:evidence) do
      arg(:query, non_null(:string))
      arg(:investigation_id, :string)

      resolve(fn args, resolution ->
        with {:ok, user_id} <- require_auth(resolution) do
          if inv_id = args[:investigation_id] do
            with :ok <- Authorization.check_access(inv_id, user_id, :view) do
              Evidence.search_evidence(args.query, inv_id)
            end
          else
            Evidence.search_evidence(args.query, nil)
          end
        end
      end)
    end

    @desc "Get evidence chain from a claim"
    field :evidence_chain, :evidence_graph do
      arg(:claim_id, non_null(:id))
      arg(:max_depth, :integer, default_value: 3)

      resolve(fn args, resolution ->
        with {:ok, user_id} <- require_auth(resolution),
             {:ok, claim} <- Claims.get_claim(args.claim_id),
             :ok <- Authorization.check_access(claim.investigation_id, user_id, :view) do
          Relationships.evidence_chain(args.claim_id, args.max_depth)
        end
      end)
    end

    @desc "Get navigation path by ID"
    field :navigation_path, :navigation_path do
      arg(:id, non_null(:id))

      resolve(fn %{id: id}, resolution ->
        with {:ok, user_id} <- require_auth(resolution),
             {:ok, path} <- Navigation.get_path(id),
             :ok <- Authorization.check_access(path.investigation_id, user_id, :view) do
          {:ok, path}
        end
      end)
    end

    @desc "List navigation paths for investigation"
    field :navigation_paths, list_of(:navigation_path) do
      arg(:investigation_id, non_null(:string))
      arg(:audience_type, :audience_type_enum)

      resolve(fn args, resolution ->
        with {:ok, user_id} <- require_auth(resolution),
             :ok <- Authorization.check_access(args.investigation_id, user_id, :view) do
          Navigation.list_paths(args.investigation_id, audience_type: args[:audience_type])
        end
      end)
    end

    # -- Entity queries -------------------------------------------------------

    @desc "Get an entity by ID"
    field :entity, :entity do
      arg(:id, non_null(:id))
      resolve(&EntityResolver.get_entity/2)
    end

    @desc "List entities for an investigation"
    field :entities, list_of(:entity) do
      arg(:investigation_id, non_null(:string))
      arg(:limit, :integer, default_value: 100)
      arg(:offset, :integer, default_value: 0)
      resolve(&EntityResolver.list_entities/2)
    end

    @desc "Search entities by name or alias"
    field :search_entities, list_of(:entity) do
      arg(:query, non_null(:string))
      arg(:investigation_id, :string)
      resolve(&EntityResolver.search_entities/2)
    end

    # -- Financial transaction queries -----------------------------------------

    @desc "List financial transactions for an investigation"
    field :transactions, list_of(:transaction) do
      arg(:investigation_id, non_null(:string))
      arg(:limit, :integer, default_value: 100)
      arg(:offset, :integer, default_value: 0)
      resolve(&FinancialResolver.list_transactions/2)
    end

    @desc "Follow-the-money graph traversal from an entity"
    field :transaction_chain, list_of(:transaction_chain_result) do
      arg(:entity_id, non_null(:string))
      arg(:depth, :integer, default_value: 3)
      arg(:investigation_id, :string)
      resolve(&FinancialResolver.transaction_chain/2)
    end

    @desc "Aggregate total flow between two entities"
    field :total_flow, list_of(:flow_aggregate) do
      arg(:from_id, non_null(:string))
      arg(:to_id, non_null(:string))
      arg(:start_date, :date)
      arg(:end_date, :date)
      resolve(&FinancialResolver.total_flow/2)
    end

    @desc "Detect anomalies in financial transactions"
    field :anomalies, list_of(:anomaly) do
      arg(:investigation_id, non_null(:string))
      resolve(&FinancialResolver.anomalies/2)
    end

    @desc "Sankey diagram data for financial flow visualisation"
    field :sankey_data, :sankey_data do
      arg(:investigation_id, non_null(:string))
      resolve(&FinancialResolver.sankey_data/2)
    end

    # -- Investigation queries -------------------------------------------------

    @desc "Get an investigation by ID"
    field :investigation, :investigation do
      arg(:id, non_null(:id))

      resolve(fn %{id: id}, resolution ->
        with {:ok, user_id} <- require_auth(resolution),
             :ok <- Authorization.check_access(id, user_id, :view) do
          Investigations.get_investigation(id)
        end
      end)
    end

    @desc "List investigations accessible to the current user"
    field :investigations, list_of(:investigation) do
      arg(:status, :string)
      arg(:limit, :integer, default_value: 50)
      arg(:offset, :integer, default_value: 0)

      resolve(fn args, resolution ->
        with {:ok, user_id} <- require_auth(resolution) do
          # Fetch all investigation IDs the user has access to, then filter
          case Authorization.user_investigations(user_id) do
            {:ok, grants} ->
              accessible_ids = Enum.map(grants, & &1.investigation_id)

              case Investigations.list_investigations(
                     status: args[:status],
                     limit: args.limit,
                     offset: args.offset
                   ) do
                {:ok, investigations} ->
                  {:ok, Enum.filter(investigations, &(&1.id in accessible_ids))}

                error ->
                  error
              end

            error ->
              error
          end
        end
      end)
    end

    @desc "Get aggregate statistics for an investigation"
    field :investigation_stats, :investigation_stats do
      arg(:id, non_null(:id))

      resolve(fn %{id: id}, resolution ->
        with {:ok, user_id} <- require_auth(resolution),
             :ok <- Authorization.check_access(id, user_id, :view) do
          Investigations.investigation_stats(id)
        end
      end)
    end

    # -- Search queries --------------------------------------------------------

    @desc "Unified full-text search across evidence, claims, and entities"
    field :search_all, non_null(:search_results) do
      arg(:query, non_null(:string))
      arg(:investigation_id, :string)
      arg(:limit, :integer, default_value: 20)

      resolve(fn args, resolution ->
        with {:ok, user_id} <- require_auth(resolution) do
          if inv_id = args[:investigation_id] do
            with :ok <- Authorization.check_access(inv_id, user_id, :view) do
              Search.search_all(args.query, inv_id, limit: args.limit)
            end
          else
            Search.search_all(args.query, nil, limit: args.limit)
          end
        end
      end)
    end

    # -- Testimony queries -----------------------------------------------------

    @desc "Cross-reference claims by a witness entity"
    field :cross_reference_claims, list_of(:cross_reference_result) do
      arg(:investigation_id, non_null(:string))
      arg(:entity_id, non_null(:string))

      resolve(fn args, resolution ->
        with {:ok, user_id} <- require_auth(resolution),
             :ok <- Authorization.check_access(args.investigation_id, user_id, :view) do
          Testimony.cross_reference_claims(args.investigation_id, args.entity_id)
        end
      end)
    end

    @desc "Calculate witness reliability"
    field :witness_reliability, :witness_reliability do
      arg(:entity_id, non_null(:string))

      resolve(fn %{entity_id: entity_id}, resolution ->
        with {:ok, user_id} <- require_auth(resolution),
             {:ok, entity} <- Entities.get_entity(entity_id),
             :ok <- Authorization.check_access(entity.investigation_id, user_id, :view) do
          Testimony.witness_reliability(entity_id)
        end
      end)
    end

    @desc "Find self-contradictions (impeachment check) for a witness"
    field :impeachment_check, list_of(:impeachment_result) do
      arg(:entity_id, non_null(:string))

      resolve(fn %{entity_id: entity_id}, resolution ->
        with {:ok, user_id} <- require_auth(resolution),
             {:ok, entity} <- Entities.get_entity(entity_id),
             :ok <- Authorization.check_access(entity.investigation_id, user_id, :view) do
          case Testimony.impeachment_check(entity_id) do
            {:ok, results} ->
              {:ok,
               Enum.map(results, fn r ->
                 Map.update!(r, :contradiction_type, &to_string/1)
               end)}

            error ->
              error
          end
        end
      end)
    end

    @desc "Chronological testimony timeline for a witness"
    field :testimony_timeline, list_of(:testimony_timeline_entry) do
      arg(:entity_id, non_null(:string))

      resolve(fn %{entity_id: entity_id}, resolution ->
        with {:ok, user_id} <- require_auth(resolution),
             {:ok, entity} <- Entities.get_entity(entity_id),
             :ok <- Authorization.check_access(entity.investigation_id, user_id, :view) do
          Testimony.testimony_timeline(entity_id)
        end
      end)
    end

    # -- Contradiction queries -------------------------------------------------

    @desc "List all contradictions in an investigation"
    field :contradictions, list_of(:contradiction) do
      arg(:investigation_id, non_null(:string))

      resolve(fn %{investigation_id: inv_id}, resolution ->
        with {:ok, user_id} <- require_auth(resolution),
             :ok <- Authorization.check_access(inv_id, user_id, :view) do
          case Contradictions.find_contradictions(inv_id) do
            {:ok, results} ->
              {:ok,
               Enum.map(results, fn c ->
                 %{
                   id: c.id,
                   claim_a: c.claim_a,
                   claim_b: c.claim_b,
                   type: to_string(c.type),
                   severity: c.severity,
                   detected_by: to_string(c.detected_by),
                   resolved: c.resolved,
                   resolution: c.resolution
                 }
               end)}

            error ->
              error
          end
        end
      end)
    end

    # -- Authorization queries -------------------------------------------------

    @desc "List collaborators on an investigation"
    field :collaborators, list_of(:access_grant) do
      arg(:investigation_id, non_null(:string))

      resolve(fn %{investigation_id: inv_id}, resolution ->
        with {:ok, user_id} <- require_auth(resolution),
             :ok <- Authorization.check_access(inv_id, user_id, :view) do
          Authorization.list_collaborators(inv_id)
        end
      end)
    end

    @desc "List investigations accessible by the current user"
    field :user_investigations, list_of(:access_grant) do
      arg(:user_id, non_null(:string))

      resolve(fn %{user_id: requested_user_id}, resolution ->
        with {:ok, user_id} <- require_auth(resolution) do
          # Users can only list their own accessible investigations
          if user_id == requested_user_id do
            Authorization.user_investigations(requested_user_id)
          else
            {:error, :forbidden}
          end
        end
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # Mutations
  # ---------------------------------------------------------------------------

  mutation do
    @desc "Create a new claim"
    field :create_claim, :claim do
      arg(:input, non_null(:create_claim_input))

      resolve(fn %{input: input}, resolution ->
        with {:ok, user_id} <- require_auth(resolution),
             :ok <- Authorization.check_access(input.investigation_id, user_id, :edit) do
          Claims.create_claim(input)
        end
      end)
    end

    @desc "Update a claim"
    field :update_claim, :claim do
      arg(:id, non_null(:id))
      arg(:input, non_null(:update_claim_input))

      resolve(fn %{id: id, input: input}, resolution ->
        with {:ok, user_id} <- require_auth(resolution),
             {:ok, claim} <- Claims.get_claim(id),
             :ok <- Authorization.check_access(claim.investigation_id, user_id, :edit) do
          Claims.update_claim(id, input)
        end
      end)
    end

    @desc "Delete a claim"
    field :delete_claim, :boolean do
      arg(:id, non_null(:id))

      resolve(fn %{id: id}, resolution ->
        with {:ok, user_id} <- require_auth(resolution),
             {:ok, claim} <- Claims.get_claim(id),
             :ok <- Authorization.check_access(claim.investigation_id, user_id, :delete) do
          case Claims.delete_claim(id) do
            :ok -> {:ok, true}
            error -> error
          end
        end
      end)
    end

    @desc "Create evidence"
    field :create_evidence, :evidence do
      arg(:input, non_null(:create_evidence_input))

      resolve(fn %{input: input}, resolution ->
        with {:ok, user_id} <- require_auth(resolution),
             :ok <- Authorization.check_access(input.investigation_id, user_id, :edit) do
          Evidence.create_evidence(input)
        end
      end)
    end

    @desc "Update evidence"
    field :update_evidence, :evidence do
      arg(:id, non_null(:id))
      arg(:input, non_null(:update_evidence_input))

      resolve(fn %{id: id, input: input}, resolution ->
        with {:ok, user_id} <- require_auth(resolution),
             {:ok, ev} <- Evidence.get_evidence(id),
             :ok <- Authorization.check_access(ev.investigation_id, user_id, :edit) do
          Evidence.update_evidence(id, input)
        end
      end)
    end

    @desc "Import evidence from Zotero JSON"
    field :import_from_zotero, :evidence do
      arg(:zotero_json, non_null(:json))
      arg(:investigation_id, non_null(:string))

      resolve(fn %{zotero_json: json, investigation_id: inv_id}, resolution ->
        with {:ok, user_id} <- require_auth(resolution),
             :ok <- Authorization.check_access(inv_id, user_id, :edit) do
          Evidence.import_from_zotero(json, inv_id)
        end
      end)
    end

    @desc "Create a relationship"
    field :create_relationship, :relationship do
      arg(:input, non_null(:create_relationship_input))

      resolve(fn %{input: input}, resolution ->
        with {:ok, user_id} <- require_auth(resolution),
             {:ok, inv_id} <- lookup_investigation_for_node(input.from_id, input.from_type),
             :ok <- Authorization.check_access(inv_id, user_id, :edit) do
          Relationships.create_relationship(input)
        end
      end)
    end

    @desc "Update relationship weight/confidence"
    field :update_relationship, :relationship do
      arg(:id, non_null(:id))
      arg(:weight, :float)
      arg(:confidence, :float)

      resolve(fn args, resolution ->
        with {:ok, user_id} <- require_auth(resolution),
             {:ok, rel} <- Relationships.get_relationship(args.id),
             {:ok, inv_id} <- lookup_investigation_for_node(rel.from_id, rel.from_type),
             :ok <- Authorization.check_access(inv_id, user_id, :edit) do
          Relationships.update_relationship(args.id, Map.drop(args, [:id]))
        end
      end)
    end

    @desc "Delete a relationship"
    field :delete_relationship, :boolean do
      arg(:id, non_null(:id))

      resolve(fn %{id: id}, resolution ->
        with {:ok, user_id} <- require_auth(resolution),
             {:ok, rel} <- Relationships.get_relationship(id),
             {:ok, inv_id} <- lookup_investigation_for_node(rel.from_id, rel.from_type),
             :ok <- Authorization.check_access(inv_id, user_id, :delete) do
          case Relationships.delete_relationship(id) do
            :ok -> {:ok, true}
            error -> error
          end
        end
      end)
    end

    @desc "Create a navigation path"
    field :create_navigation_path, :navigation_path do
      arg(:input, non_null(:create_navigation_path_input))

      resolve(fn %{input: input}, resolution ->
        with {:ok, user_id} <- require_auth(resolution),
             :ok <- Authorization.check_access(input.investigation_id, user_id, :edit) do
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
        end
      end)
    end

    @desc "Auto-generate navigation path for audience"
    field :auto_generate_path, :navigation_path do
      arg(:investigation_id, non_null(:string))
      arg(:audience_type, non_null(:audience_type_enum))

      resolve(fn args, resolution ->
        with {:ok, user_id} <- require_auth(resolution),
             :ok <- Authorization.check_access(args.investigation_id, user_id, :edit) do
          Navigation.auto_generate_path(args.investigation_id, args.audience_type)
        end
      end)
    end

    # -- Entity mutations -----------------------------------------------------

    @desc "Create a new entity"
    field :create_entity, :entity do
      arg(:input, non_null(:create_entity_input))
      resolve(&EntityResolver.create_entity/2)
    end

    @desc "Merge source entity into target (absorbs aliases, re-points edges, deletes source)"
    field :merge_entities, :entity do
      arg(:input, non_null(:merge_entities_input))
      resolve(&EntityResolver.merge_entities/2)
    end

    @desc "Reverse a previous merge, restoring the source entity"
    field :unmerge_entity, :entity do
      arg(:target_id, non_null(:id))
      arg(:source_id, non_null(:id))
      resolve(&EntityResolver.unmerge_entity/2)
    end

    @desc "Add an alias to an entity"
    field :add_entity_alias, :entity do
      arg(:entity_id, non_null(:id))
      arg(:alias_name, non_null(:string))
      resolve(&EntityResolver.add_entity_alias/2)
    end

    @desc "Remove an alias from an entity"
    field :remove_entity_alias, :entity do
      arg(:entity_id, non_null(:id))
      arg(:alias_name, non_null(:string))
      resolve(&EntityResolver.remove_entity_alias/2)
    end

    @desc "Resolve NER output strings against the entity pool"
    field :resolve_ner_entities, list_of(:ner_resolution_result) do
      arg(:input, non_null(:resolve_ner_input))
      resolve(&EntityResolver.resolve_ner_entities/2)
    end

    # -- Financial transaction mutations ---------------------------------------

    @desc "Create a financial transaction"
    field :create_transaction, :transaction do
      arg(:input, non_null(:create_transaction_input))
      resolve(&FinancialResolver.create_transaction/2)
    end

    # -- Investigation mutations -----------------------------------------------

    @desc "Create a new investigation"
    field :create_investigation, :investigation do
      arg(:input, non_null(:create_investigation_input))

      resolve(fn %{input: input}, resolution ->
        with {:ok, user_id} <- require_auth(resolution) do
          # Any authenticated user can create an investigation;
          # they automatically become the owner.
          case Investigations.create_investigation(input) do
            {:ok, investigation} = ok ->
              # Grant owner access to the creator
              Authorization.grant_access(investigation.id, user_id, :owner)
              ok

            error ->
              error
          end
        end
      end)
    end

    @desc "Update an investigation"
    field :update_investigation, :investigation do
      arg(:id, non_null(:id))
      arg(:input, non_null(:update_investigation_input))

      resolve(fn %{id: id, input: input}, resolution ->
        with {:ok, user_id} <- require_auth(resolution),
             :ok <- Authorization.check_access(id, user_id, :edit) do
          Investigations.update_investigation(id, input)
        end
      end)
    end

    @desc "Archive an investigation"
    field :archive_investigation, :investigation do
      arg(:id, non_null(:id))

      resolve(fn %{id: id}, resolution ->
        with {:ok, user_id} <- require_auth(resolution),
             :ok <- Authorization.check_access(id, user_id, :manage) do
          Investigations.archive_investigation(id)
        end
      end)
    end

    @desc "Share evidence between investigations"
    field :share_evidence, :investigation do
      arg(:input, non_null(:share_evidence_input))

      resolve(fn %{input: input}, resolution ->
        with {:ok, user_id} <- require_auth(resolution),
             :ok <- Authorization.check_access(input.from_investigation_id, user_id, :share),
             :ok <- Authorization.check_access(input.to_investigation_id, user_id, :edit) do
          Investigations.share_evidence(
            input.from_investigation_id,
            input.to_investigation_id,
            input.evidence_ids
          )
        end
      end)
    end

    # -- Contradiction mutations -----------------------------------------------

    @desc "Resolve a contradiction"
    field :resolve_contradiction, :boolean do
      arg(:input, non_null(:resolve_contradiction_input))

      resolve(fn %{input: input}, resolution ->
        with {:ok, user_id} <- require_auth(resolution),
             {:ok, contradiction} <- Contradictions.get_contradiction(input.contradiction_id),
             :ok <- Authorization.check_access(contradiction.investigation_id, user_id, :edit) do
          resolution_data = %{
            status: String.to_existing_atom(input.status),
            rationale: Map.get(input, :rationale, ""),
            resolved_by: Map.get(input, :resolved_by)
          }

          case Contradictions.resolve_contradiction(input.contradiction_id, resolution_data) do
            :ok -> {:ok, true}
            error -> error
          end
        end
      end)
    end

    # -- Authorization mutations -----------------------------------------------

    @desc "Grant access to an investigation"
    field :grant_access, :access_grant do
      arg(:input, non_null(:grant_access_input))

      resolve(fn %{input: input}, resolution ->
        with {:ok, user_id} <- require_auth(resolution),
             :ok <- Authorization.check_access(input.investigation_id, user_id, :manage) do
          Authorization.grant_access(input.investigation_id, input.user_id, input.role)
        end
      end)
    end

    @desc "Revoke access from an investigation"
    field :revoke_access, :boolean do
      arg(:input, non_null(:revoke_access_input))

      resolve(fn %{input: input}, resolution ->
        with {:ok, user_id} <- require_auth(resolution),
             :ok <- Authorization.check_access(input.investigation_id, user_id, :manage) do
          case Authorization.revoke_access(input.investigation_id, input.user_id) do
            :ok -> {:ok, true}
            error -> error
          end
        end
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # Authorization helpers
  # ---------------------------------------------------------------------------

  @doc false
  def require_auth(%{context: %{current_user_id: user_id}}) when is_binary(user_id) do
    {:ok, user_id}
  end

  def require_auth(_resolution) do
    {:error, "Authentication required. Please log in or provide valid credentials."}
  end

  @doc """
  Look up the investigation_id for a graph node (claim or evidence) by its ID and type.
  Used for relationship authorization where the relationship itself does not carry
  an investigation_id.
  """
  def lookup_investigation_for_node(node_id, node_type) do
    case node_type do
      t when t in [:claim, "claim"] ->
        case Claims.get_claim(node_id) do
          {:ok, claim} -> {:ok, claim.investigation_id}
          error -> error
        end

      t when t in [:evidence, "evidence"] ->
        case Evidence.get_evidence(node_id) do
          {:ok, ev} -> {:ok, ev.investigation_id}
          error -> error
        end

      _ ->
        {:error, :unknown_node_type}
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

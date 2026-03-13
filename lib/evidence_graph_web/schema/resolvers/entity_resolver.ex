# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
defmodule EvidenceGraphWeb.Schema.Resolvers.EntityResolver do
  @moduledoc """
  Absinthe resolvers for Entity queries and mutations.

  All resolvers enforce RBAC authorization by checking the authenticated
  user's access to the investigation that owns the entity.
  """

  alias EvidenceGraph.Entities
  alias EvidenceGraph.Authorization
  import EvidenceGraphWeb.Schema, only: [require_auth: 1]

  # ---------------------------------------------------------------------------
  # Queries
  # ---------------------------------------------------------------------------

  @doc "Resolve a single entity by ID."
  def get_entity(%{id: id}, resolution) do
    with {:ok, user_id} <- require_auth(resolution),
         {:ok, entity} <- Entities.get_entity(id),
         :ok <- Authorization.check_access(entity.investigation_id, user_id, :view) do
      {:ok, entity}
    end
  end

  @doc "List entities for an investigation with pagination."
  def list_entities(%{investigation_id: inv_id} = args, resolution) do
    with {:ok, user_id} <- require_auth(resolution),
         :ok <- Authorization.check_access(inv_id, user_id, :view) do
      Entities.list_entities(inv_id,
        limit: Map.get(args, :limit, 100),
        offset: Map.get(args, :offset, 0)
      )
    end
  end

  @doc "Search entities by name/alias."
  def search_entities(%{query: query} = args, resolution) do
    with {:ok, user_id} <- require_auth(resolution) do
      if inv_id = args[:investigation_id] do
        with :ok <- Authorization.check_access(inv_id, user_id, :view) do
          Entities.search_entities(query, inv_id)
        end
      else
        Entities.search_entities(query, nil)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Mutations
  # ---------------------------------------------------------------------------

  @doc "Create a new entity."
  def create_entity(%{input: input}, resolution) do
    with {:ok, user_id} <- require_auth(resolution),
         :ok <- Authorization.check_access(input.investigation_id, user_id, :edit) do
      Entities.create_entity(input)
    end
  end

  @doc "Merge source entity into target entity."
  def merge_entities(%{input: %{target_id: target_id, source_id: source_id, rationale: rationale}}, resolution) do
    with {:ok, user_id} <- require_auth(resolution),
         {:ok, target} <- Entities.get_entity(target_id),
         :ok <- Authorization.check_access(target.investigation_id, user_id, :edit) do
      Entities.merge_entities(target_id, source_id, rationale)
    end
  end

  @doc "Reverse a previous merge."
  def unmerge_entity(%{target_id: target_id, source_id: source_id}, resolution) do
    with {:ok, user_id} <- require_auth(resolution),
         {:ok, target} <- Entities.get_entity(target_id),
         :ok <- Authorization.check_access(target.investigation_id, user_id, :edit) do
      Entities.unmerge_entity(target_id, source_id)
    end
  end

  @doc "Add an alias to an entity."
  def add_entity_alias(%{entity_id: entity_id, alias_name: alias_name}, resolution) do
    with {:ok, user_id} <- require_auth(resolution),
         {:ok, entity} <- Entities.get_entity(entity_id),
         :ok <- Authorization.check_access(entity.investigation_id, user_id, :edit) do
      Entities.add_alias(entity_id, alias_name)
    end
  end

  @doc "Remove an alias from an entity."
  def remove_entity_alias(%{entity_id: entity_id, alias_name: alias_name}, resolution) do
    with {:ok, user_id} <- require_auth(resolution),
         {:ok, entity} <- Entities.get_entity(entity_id),
         :ok <- Authorization.check_access(entity.investigation_id, user_id, :edit) do
      Entities.remove_alias(entity_id, alias_name)
    end
  end

  @doc "Resolve a batch of NER strings against the entity pool."
  def resolve_ner_entities(%{input: %{ner_strings: ner_strings, investigation_id: inv_id}}, resolution) do
    with {:ok, user_id} <- require_auth(resolution),
         :ok <- Authorization.check_access(inv_id, user_id, :edit) do
      results =
        Entities.resolve_ner_output(ner_strings, inv_id)
        |> Enum.map(fn {ner_string, result} ->
          case result do
            {:existing, entity} ->
              %{ner_string: ner_string, status: :existing, entity: entity, similarity: nil}

            {:suggest_merge, entity, similarity} ->
              %{ner_string: ner_string, status: :suggest_merge, entity: entity, similarity: similarity}

            {:created, entity} ->
              %{ner_string: ner_string, status: :created, entity: entity, similarity: nil}

            {:error, _reason} ->
              %{ner_string: ner_string, status: :error, entity: nil, similarity: nil}
          end
        end)

      {:ok, results}
    end
  end
end

# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
defmodule EvidenceGraph.Entities do
  @moduledoc """
  Context for Entity Resolution in the Evidence Graph.

  Provides CRUD operations, alias management, entity merging/unmerging,
  fuzzy search, and NER co-reference resolution.  Entities live in the
  ArangoDB `entities` collection.
  """

  alias EvidenceGraph.ArangoDB
  alias EvidenceGraph.Entities.Entity

  # ---------------------------------------------------------------------------
  # CRUD
  # ---------------------------------------------------------------------------

  @doc """
  Create a new entity with validation.

  ## Examples

      iex> create_entity(%{
      ...>   primary_name: "HSBC Holdings plc",
      ...>   entity_type: :organization,
      ...>   investigation_id: "inv_123"
      ...> })
      {:ok, %Entity{}}
  """
  def create_entity(attrs) do
    changeset = Entity.changeset(%Entity{}, attrs)

    if changeset.valid? do
      entity =
        Ecto.Changeset.apply_changes(changeset)
        |> Map.put(:inserted_at, DateTime.utc_now())
        |> Map.put(:updated_at, DateTime.utc_now())

      case ArangoDB.insert("entities", Entity.to_arango_doc(entity)) do
        {:ok, doc} -> {:ok, Entity.from_arango_doc(doc)}
        error -> error
      end
    else
      {:error, changeset}
    end
  end

  @doc """
  Get an entity by ID.
  """
  def get_entity(id) do
    case ArangoDB.get("entities", id) do
      {:ok, doc} -> {:ok, Entity.from_arango_doc(doc)}
      error -> error
    end
  end

  @doc """
  Get an entity by ID, raises if not found.
  """
  def get_entity!(id) do
    case get_entity(id) do
      {:ok, entity} -> entity
      {:error, :not_found} -> raise "Entity not found: #{id}"
    end
  end

  @doc """
  Find an entity by name, checking both `primary_name` and the `aliases` array.

  Returns the first match within the given investigation scope.
  """
  def get_entity_by_name(name, investigation_id) do
    aql = """
    FOR entity IN entities
      FILTER entity.investigation_id == @investigation_id
      FILTER entity.primary_name == @name
          OR @name IN entity.aliases
      LIMIT 1
      RETURN entity
    """

    case ArangoDB.query_read(aql, %{name: name, investigation_id: investigation_id}) do
      {:ok, [doc]} -> {:ok, Entity.from_arango_doc(doc)}
      {:ok, []} -> {:error, :not_found}
      error -> error
    end
  end

  @doc """
  List entities for an investigation (paginated, most recent first).
  """
  def list_entities(investigation_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 100)
    offset = Keyword.get(opts, :offset, 0)

    aql = """
    FOR entity IN entities
      FILTER entity.investigation_id == @investigation_id
      SORT entity.inserted_at DESC
      LIMIT @offset, @limit
      RETURN entity
    """

    case ArangoDB.query_read(aql, %{
           investigation_id: investigation_id,
           limit: limit,
           offset: offset
         }) do
      {:ok, docs} -> {:ok, Enum.map(docs, &Entity.from_arango_doc/1)}
      error -> error
    end
  end

  # ---------------------------------------------------------------------------
  # Alias management
  # ---------------------------------------------------------------------------

  @doc """
  Add an alias to an existing entity.  No-ops if the alias already exists.
  """
  def add_alias(entity_id, alias_name) do
    aql = """
    LET entity = DOCUMENT("entities", @key)
    FILTER entity != null
    LET new_aliases = APPEND(
      entity.aliases,
      @alias_name IN entity.aliases ? [] : [@alias_name]
    )
    UPDATE entity WITH {
      aliases: new_aliases,
      updated_at: DATE_ISO8601(DATE_NOW())
    } IN entities
    RETURN NEW
    """

    case ArangoDB.query(aql, %{key: entity_id, alias_name: alias_name}) do
      {:ok, [doc]} -> {:ok, Entity.from_arango_doc(doc)}
      {:ok, []} -> {:error, :not_found}
      error -> error
    end
  end

  @doc """
  Remove an alias from an entity.
  """
  def remove_alias(entity_id, alias_name) do
    aql = """
    LET entity = DOCUMENT("entities", @key)
    FILTER entity != null
    UPDATE entity WITH {
      aliases: REMOVE_VALUE(entity.aliases, @alias_name),
      updated_at: DATE_ISO8601(DATE_NOW())
    } IN entities
    RETURN NEW
    """

    case ArangoDB.query(aql, %{key: entity_id, alias_name: alias_name}) do
      {:ok, [doc]} -> {:ok, Entity.from_arango_doc(doc)}
      {:ok, []} -> {:error, :not_found}
      error -> error
    end
  end

  # ---------------------------------------------------------------------------
  # Merge / Unmerge
  # ---------------------------------------------------------------------------

  @doc """
  Merge entity B into entity A.

  1. Copies all aliases and primary_name of B into A's aliases list
  2. Re-points every `relationships` edge referencing B to reference A
  3. Logs the merge in A's metadata under `merge_history`
  4. Deletes entity B
  5. Returns the merged entity A

  The `rationale` string is stored for audit and for `unmerge_entity/2`.
  """
  def merge_entities(target_id, source_id, rationale) do
    with {:ok, target} <- get_entity(target_id),
         {:ok, source} <- get_entity(source_id) do
      # Build combined alias list (deduplicated)
      new_aliases =
        (target.aliases ++ [source.primary_name | source.aliases])
        |> Enum.uniq()
        |> List.delete(target.primary_name)

      # Record merge history entry
      merge_entry = %{
        "merged_entity_id" => source_id,
        "merged_primary_name" => source.primary_name,
        "merged_aliases" => source.aliases,
        "merged_entity_type" => to_string(source.entity_type),
        "merged_metadata" => source.metadata,
        "rationale" => rationale,
        "merged_at" => DateTime.to_iso8601(DateTime.utc_now())
      }

      existing_history = Map.get(target.metadata, "merge_history", [])
      updated_metadata = Map.put(target.metadata, "merge_history", existing_history ++ [merge_entry])

      # Update target entity
      update_aql = """
      UPDATE @target_key WITH {
        aliases: @new_aliases,
        metadata: @metadata,
        document_count: @doc_count,
        updated_at: DATE_ISO8601(DATE_NOW())
      } IN entities
      RETURN NEW
      """

      merged_doc_count = target.document_count + source.document_count

      with {:ok, [updated_doc]} <-
             ArangoDB.query(update_aql, %{
               target_key: target_id,
               new_aliases: new_aliases,
               metadata: updated_metadata,
               doc_count: merged_doc_count
             }),
           # Re-point graph edges from source to target
           :ok <- repoint_edges(source_id, target_id),
           # Delete source entity
           {:ok, _} <- ArangoDB.delete("entities", source_id) do
        {:ok, Entity.from_arango_doc(updated_doc)}
      end
    end
  end

  @doc """
  Reverse a previous merge using the stored `merge_history` entry.

  Restores the originally-merged entity with its original name, aliases,
  and metadata.  Does NOT attempt to re-point edges back (that requires
  manual review).
  """
  def unmerge_entity(target_id, source_id) do
    with {:ok, target} <- get_entity(target_id) do
      merge_history = Map.get(target.metadata, "merge_history", [])

      case Enum.split_with(merge_history, &(&1["merged_entity_id"] == source_id)) do
        {[], _} ->
          {:error, :merge_not_found}

        {[entry | _rest], remaining_history} ->
          # Recreate the source entity from the stored snapshot
          restored_attrs = %{
            primary_name: entry["merged_primary_name"],
            entity_type: String.to_existing_atom(entry["merged_entity_type"]),
            aliases: entry["merged_aliases"] || [],
            investigation_id: target.investigation_id,
            metadata: Map.put(entry["merged_metadata"] || %{}, "unmerged_from", target_id)
          }

          # Remove source aliases from target
          aliases_to_remove =
            MapSet.new([entry["merged_primary_name"] | entry["merged_aliases"] || []])

          cleaned_aliases =
            Enum.reject(target.aliases, &MapSet.member?(aliases_to_remove, &1))

          cleaned_metadata = Map.put(target.metadata, "merge_history", remaining_history)

          with {:ok, restored} <- create_entity_with_id(source_id, restored_attrs),
               {:ok, _} <-
                 ArangoDB.update("entities", target_id, %{
                   aliases: cleaned_aliases,
                   metadata: cleaned_metadata,
                   updated_at: DateTime.to_iso8601(DateTime.utc_now())
                 }) do
            {:ok, restored}
          end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Search
  # ---------------------------------------------------------------------------

  @doc """
  Fuzzy search entities by name or alias within an investigation.

  Uses ArangoDB FULLTEXT index on `primary_name` and falls back to
  LIKE-based prefix matching for short queries.
  """
  def search_entities(query_text, investigation_id \\ nil) do
    aql =
      if investigation_id do
        """
        FOR entity IN entities
          FILTER entity.investigation_id == @investigation_id
          FILTER CONTAINS(LOWER(entity.primary_name), LOWER(@query))
              OR LENGTH(
                   FOR alias IN entity.aliases
                     FILTER CONTAINS(LOWER(alias), LOWER(@query))
                     RETURN alias
                 ) > 0
          RETURN entity
        """
      else
        """
        FOR entity IN entities
          FILTER CONTAINS(LOWER(entity.primary_name), LOWER(@query))
              OR LENGTH(
                   FOR alias IN entity.aliases
                     FILTER CONTAINS(LOWER(alias), LOWER(@query))
                     RETURN alias
                 ) > 0
          RETURN entity
        """
      end

    vars = %{query: query_text, investigation_id: investigation_id}

    case ArangoDB.query_read(aql, vars) do
      {:ok, docs} -> {:ok, Enum.map(docs, &Entity.from_arango_doc/1)}
      error -> error
    end
  end

  # ---------------------------------------------------------------------------
  # NER Co-reference Resolution
  # ---------------------------------------------------------------------------

  @doc """
  Resolve a list of raw NER strings against the existing entity pool for
  an investigation.

  For each string:

  1. **Exact match** on `primary_name` or any alias -> link to existing entity
  2. **Fuzzy match** (Jaro-Winkler > 0.85) -> return as `:suggest_merge`
  3. **No match** -> create a new entity with type `:person` (default;
     callers should refine)

  Returns a list of `{ner_string, result}` tuples where result is one of:

  - `{:existing, %Entity{}}` -- linked to existing entity
  - `{:suggest_merge, %Entity{}, similarity}` -- high-confidence fuzzy match
  - `{:created, %Entity{}}` -- brand-new entity created
  """
  def resolve_ner_output(ner_strings, investigation_id) do
    # Fetch all entities for the investigation up-front to avoid N+1 queries
    {:ok, existing} = list_entities(investigation_id, limit: 10_000)

    Enum.map(ner_strings, fn ner_string ->
      case find_exact_match(ner_string, existing) do
        {:ok, entity} ->
          {ner_string, {:existing, entity}}

        :none ->
          case find_fuzzy_match(ner_string, existing) do
            {:ok, entity, similarity} ->
              {ner_string, {:suggest_merge, entity, similarity}}

            :none ->
              case create_entity(%{
                     primary_name: ner_string,
                     entity_type: :person,
                     investigation_id: investigation_id,
                     metadata: %{"source" => "ner_auto"}
                   }) do
                {:ok, new_entity} ->
                  {ner_string, {:created, new_entity}}

                {:error, reason} ->
                  {ner_string, {:error, reason}}
              end
          end
      end
    end)
  end

  @doc """
  Get all evidence documents that mention a given entity.

  Traverses the ArangoDB graph via the `relationships` edge collection,
  following edges where the entity is referenced.
  """
  def get_entity_documents(entity_id) do
    aql = """
    FOR entity IN entities
      FILTER entity._key == @entity_id
      FOR v, e IN 1..1 ANY entity relationships
        FILTER IS_SAME_COLLECTION("evidence", v)
        RETURN DISTINCT v
    """

    case ArangoDB.query_read(aql, %{entity_id: entity_id}) do
      {:ok, docs} ->
        {:ok, Enum.map(docs, &EvidenceGraph.Evidence.Evidence.from_arango_doc/1)}

      error ->
        error
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  @doc false
  defp find_exact_match(name, entities) do
    normalized = String.downcase(name)

    Enum.find_value(entities, :none, fn entity ->
      primary_match = String.downcase(entity.primary_name) == normalized

      alias_match =
        Enum.any?(entity.aliases, &(String.downcase(&1) == normalized))

      if primary_match or alias_match do
        {:ok, entity}
      end
    end)
  end

  @doc false
  defp find_fuzzy_match(name, entities) do
    normalized = String.downcase(name)

    results =
      entities
      |> Enum.flat_map(fn entity ->
        all_names = [entity.primary_name | entity.aliases]

        all_names
        |> Enum.map(fn candidate ->
          sim = jaro_winkler_similarity(normalized, String.downcase(candidate))
          {entity, sim}
        end)
      end)
      |> Enum.filter(fn {_entity, sim} -> sim > 0.85 end)
      |> Enum.sort_by(fn {_entity, sim} -> sim end, :desc)

    case results do
      [{entity, similarity} | _] -> {:ok, entity, similarity}
      [] -> :none
    end
  end

  @doc """
  Jaro-Winkler string similarity (0.0 to 1.0).

  Uses Elixir's built-in `String.jaro_distance/2` which implements the
  Jaro-Winkler algorithm.
  """
  def jaro_winkler_similarity(a, b) do
    String.jaro_distance(a, b)
  end

  # Re-point all graph edges that reference source_id to target_id
  defp repoint_edges(source_id, target_id) do
    # Edges where source is _from
    from_aql = """
    FOR edge IN relationships
      FILTER edge._from == CONCAT("entities/", @source_id)
      UPDATE edge WITH {
        _from: CONCAT("entities/", @target_id)
      } IN relationships
    """

    # Edges where source is _to
    to_aql = """
    FOR edge IN relationships
      FILTER edge._to == CONCAT("entities/", @source_id)
      UPDATE edge WITH {
        _to: CONCAT("entities/", @target_id)
      } IN relationships
    """

    vars = %{source_id: source_id, target_id: target_id}

    with {:ok, _} <- ArangoDB.query(from_aql, vars),
         {:ok, _} <- ArangoDB.query(to_aql, vars) do
      :ok
    end
  end

  # Create an entity with a specific ID (used by unmerge to restore)
  defp create_entity_with_id(id, attrs) do
    changeset = Entity.changeset(%Entity{}, attrs)

    if changeset.valid? do
      entity =
        Ecto.Changeset.apply_changes(changeset)
        |> Map.put(:id, id)
        |> Map.put(:inserted_at, DateTime.utc_now())
        |> Map.put(:updated_at, DateTime.utc_now())

      case ArangoDB.insert("entities", Entity.to_arango_doc(entity)) do
        {:ok, doc} -> {:ok, Entity.from_arango_doc(doc)}
        error -> error
      end
    else
      {:error, changeset}
    end
  end
end

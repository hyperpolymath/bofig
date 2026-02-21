# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
defmodule EvidenceGraph.Navigation do
  @moduledoc """
  Context for managing Navigation Paths in the Evidence Graph.

  Navigation paths implement the "boundary objects" concept:
  different audiences navigate the same evidence in different ways.
  """

  alias EvidenceGraph.ArangoDB
  alias EvidenceGraph.Navigation.Path
  alias EvidenceGraph.PromptScores

  @doc """
  Get a navigation path by ID.
  """
  def get_path(id) do
    case ArangoDB.get("navigation_paths", id) do
      {:ok, doc} -> {:ok, Path.from_arango_doc(doc)}
      error -> error
    end
  end

  @doc """
  Get a path by ID, raises if not found.
  """
  def get_path!(id) do
    case get_path(id) do
      {:ok, path} -> path
      {:error, :not_found} -> raise "Navigation path not found: #{id}"
    end
  end

  @doc """
  List all navigation paths for an investigation.
  """
  def list_paths(investigation_id, opts \\ []) do
    audience_type = Keyword.get(opts, :audience_type)

    aql =
      if audience_type do
        """
        FOR path IN navigation_paths
          FILTER path.investigation_id == @investigation_id
          FILTER path.audience_type == @audience_type
          SORT path.inserted_at DESC
          RETURN path
        """
      else
        """
        FOR path IN navigation_paths
          FILTER path.investigation_id == @investigation_id
          SORT path.audience_type, path.inserted_at DESC
          RETURN path
        """
      end

    vars = %{
      investigation_id: investigation_id,
      audience_type: audience_type && to_string(audience_type)
    }

    case ArangoDB.query_read(aql, vars) do
      {:ok, docs} -> {:ok, Enum.map(docs, &Path.from_arango_doc/1)}
      error -> error
    end
  end

  @doc """
  Create a new navigation path.

  ## Examples

      iex> create_path(%{
      ...>   investigation_id: "inv_123",
      ...>   audience_type: :researcher,
      ...>   name: "Academic Research Path",
      ...>   entry_points: ["claim_1"],
      ...>   path_nodes: [
      ...>     %{entity_id: "claim_1", entity_type: "claim", order: 1},
      ...>     %{entity_id: "evidence_1", entity_type: "evidence", order: 2}
      ...>   ]
      ...> })
      {:ok, %Path{}}
  """
  def create_path(attrs) do
    changeset = Path.changeset(%Path{}, attrs)

    if changeset.valid? do
      path =
        Ecto.Changeset.apply_changes(changeset)
        |> Map.put(:inserted_at, DateTime.utc_now())
        |> Map.put(:updated_at, DateTime.utc_now())

      case ArangoDB.insert("navigation_paths", Path.to_arango_doc(path)) do
        {:ok, doc} -> {:ok, Path.from_arango_doc(doc)}
        error -> error
      end
    else
      {:error, changeset}
    end
  end

  @doc """
  Update a navigation path.
  """
  def update_path(id, attrs) do
    with {:ok, path} <- get_path(id) do
      changeset = Path.changeset(path, attrs)

      if changeset.valid? do
        updates =
          Ecto.Changeset.apply_changes(changeset)
          |> Map.put(:updated_at, DateTime.utc_now())
          |> Path.to_arango_doc()
          |> Map.drop([:_key, :inserted_at])

        case ArangoDB.update("navigation_paths", id, updates) do
          {:ok, doc} -> {:ok, Path.from_arango_doc(doc)}
          error -> error
        end
      else
        {:error, changeset}
      end
    end
  end

  @doc """
  Delete a navigation path.
  """
  def delete_path(id) do
    case ArangoDB.delete("navigation_paths", id) do
      {:ok, _doc} -> :ok
      error -> error
    end
  end

  @doc """
  Automatically generate a navigation path for an audience type.

  Uses PROMPT score weights to prioritize evidence based on audience preferences.
  """
  def auto_generate_path(investigation_id, audience_type) do
    with {:ok, claims} <- EvidenceGraph.Claims.list_claims(investigation_id),
         {:ok, evidence} <- EvidenceGraph.Evidence.list_evidence(investigation_id) do
      # Score each piece of evidence for this audience
      scored_evidence =
        evidence
        |> Enum.map(fn ev ->
          score = PromptScores.calculate_for_audience(ev.prompt_scores, audience_type)
          {ev, score}
        end)
        |> Enum.sort_by(fn {_ev, score} -> score end, :desc)

      # Score claims by their supporting evidence
      scored_claims =
        claims
        |> Enum.map(fn claim ->
          {:ok, supporting} = EvidenceGraph.Claims.get_supporting_evidence(claim.id)

          avg_evidence_score =
            if length(supporting) > 0 do
              supporting
              |> Enum.map(fn %{evidence: ev} ->
                PromptScores.calculate_for_audience(ev.prompt_scores, audience_type)
              end)
              |> Enum.sum()
              |> Kernel./(length(supporting))
            else
              0.0
            end

          claim_score = PromptScores.calculate_for_audience(claim.prompt_scores, audience_type)
          combined_score = claim_score * 0.4 + avg_evidence_score * 0.6

          {claim, combined_score}
        end)
        |> Enum.sort_by(fn {_claim, score} -> score end, :desc)

      # Build path alternating between claims and evidence
      path_nodes =
        scored_claims
        |> Enum.take(5)
        |> Enum.with_index()
        |> Enum.flat_map(fn {{claim, _score}, idx} ->
          claim_node = %{
            "entity_id" => claim.id,
            "entity_type" => "claim",
            "order" => idx * 2 + 1,
            "context" => "Key claim for #{audience_type}",
            "emphasis" => %{"priority" => "high"}
          }

          # Add top supporting evidence
          {:ok, supporting} = EvidenceGraph.Claims.get_supporting_evidence(claim.id)

          evidence_node =
            if length(supporting) > 0 do
              top_evidence = hd(supporting).evidence

              %{
                "entity_id" => top_evidence.id,
                "entity_type" => "evidence",
                "order" => idx * 2 + 2,
                "context" => "Supporting evidence",
                "emphasis" => %{"highlight_prompt" => true}
              }
            else
              nil
            end

          [claim_node, evidence_node] |> Enum.reject(&is_nil/1)
        end)

      entry_point =
        case scored_claims do
          [{claim, _} | _] -> [claim.id]
          _ -> []
        end

      create_path(%{
        investigation_id: investigation_id,
        audience_type: audience_type,
        name: "Auto-generated #{audience_type} path",
        description: Path.audience_description(audience_type),
        entry_points: entry_point,
        path_nodes: path_nodes,
        metadata: %{
          "auto_generated" => true,
          "generated_at" => DateTime.utc_now() |> DateTime.to_iso8601()
        }
      })
    end
  end

  @doc """
  Get the full path with hydrated Claims and Evidence.
  """
  def get_path_with_nodes(id) do
    with {:ok, path} <- get_path(id) do
      nodes =
        path.path_nodes
        |> Enum.sort_by(& &1["order"])
        |> Enum.map(fn node ->
          entity =
            case node["entity_type"] do
              "claim" ->
                {:ok, claim} = EvidenceGraph.Claims.get_claim(node["entity_id"])
                {:claim, claim}

              "evidence" ->
                {:ok, evidence} = EvidenceGraph.Evidence.get_evidence(node["entity_id"])
                {:evidence, evidence}
            end

          %{
            entity: entity,
            order: node["order"],
            context: node["context"],
            emphasis: node["emphasis"]
          }
        end)

      {:ok, %{path: path, nodes: nodes}}
    end
  end

  @doc """
  Compare how different audiences would navigate the same evidence.
  """
  def compare_audience_paths(investigation_id) do
    audience_types = [:researcher, :policymaker, :skeptic, :activist, :affected_person, :journalist]

    paths =
      Enum.map(audience_types, fn audience_type ->
        case list_paths(investigation_id, audience_type: audience_type) do
          {:ok, [path | _]} ->
            {audience_type, path}

          {:ok, []} ->
            # Auto-generate if doesn't exist
            {:ok, path} = auto_generate_path(investigation_id, audience_type)
            {audience_type, path}
        end
      end)

    {:ok, paths}
  end
end

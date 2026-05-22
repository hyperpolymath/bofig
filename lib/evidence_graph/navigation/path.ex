# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
defmodule EvidenceGraph.Navigation.Path do
  @moduledoc """
  Navigation Path schema for Evidence Graph.

  Navigation paths provide curated routes through an investigation
  tailored to different audience types. This implements the "boundary objects"
  concept - same evidence, multiple perspectives.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: String.t() | nil,
          investigation_id: String.t(),
          audience_type: atom(),
          name: String.t(),
          description: String.t() | nil,
          entry_points: list(String.t()),
          path_nodes: list(map()),
          metadata: map(),
          created_by: String.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  @audience_types [:activist, :policymaker, :researcher, :skeptic, :affected_person, :journalist]

  @primary_key {:id, :string, autogenerate: false}
  schema "navigation_paths" do
    field :investigation_id, :string
    field :audience_type, Ecto.Enum, values: @audience_types
    field :name, :string
    field :description, :string
    field :entry_points, {:array, :string}, default: []
    field :path_nodes, {:array, :map}, default: []
    field :metadata, :map, default: %{}
    field :created_by, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(path, attrs) do
    path
    |> cast(attrs, [
      :investigation_id,
      :audience_type,
      :name,
      :description,
      :entry_points,
      :path_nodes,
      :metadata,
      :created_by
    ])
    |> validate_required([:investigation_id, :audience_type, :name])
    |> validate_inclusion(:audience_type, @audience_types)
    |> validate_length(:name, min: 3, max: 200)
    |> validate_path_nodes()
    |> put_id()
  end

  defp validate_path_nodes(changeset) do
    case get_change(changeset, :path_nodes) do
      nil ->
        changeset

      nodes when is_list(nodes) ->
        if Enum.all?(nodes, &valid_path_node?/1) do
          changeset
        else
          add_error(changeset, :path_nodes, "contains invalid path nodes")
        end

      _ ->
        add_error(changeset, :path_nodes, "must be a list")
    end
  end

  defp valid_path_node?(%{
         "entity_id" => _,
         "entity_type" => type,
         "order" => order
       })
       when type in ["claim", "evidence"] and is_integer(order) do
    true
  end

  defp valid_path_node?(_), do: false

  defp put_id(%Ecto.Changeset{data: %{id: nil}} = changeset) do
    put_change(changeset, :id, "path_" <> Ecto.UUID.generate())
  end

  defp put_id(changeset), do: changeset

  @doc """
  Convert to ArangoDB document format.
  """
  def to_arango_doc(%__MODULE__{} = path) do
    %{
      _key: path.id,
      investigation_id: path.investigation_id,
      audience_type: to_string(path.audience_type),
      name: path.name,
      description: path.description,
      entry_points: path.entry_points,
      path_nodes: path.path_nodes,
      metadata: path.metadata,
      created_by: path.created_by,
      inserted_at: path.inserted_at,
      updated_at: path.updated_at
    }
  end

  @doc """
  Convert from ArangoDB document to Path struct.
  """
  def from_arango_doc(doc) do
    %__MODULE__{
      id: doc["_key"],
      investigation_id: doc["investigation_id"],
      audience_type: String.to_existing_atom(doc["audience_type"]),
      name: doc["name"],
      description: doc["description"],
      entry_points: doc["entry_points"] || [],
      path_nodes: doc["path_nodes"] || [],
      metadata: doc["metadata"] || %{},
      created_by: doc["created_by"],
      inserted_at: parse_datetime(doc["inserted_at"]),
      updated_at: parse_datetime(doc["updated_at"])
    }
  end

  defp parse_datetime(nil), do: nil
  defp parse_datetime(dt) when is_binary(dt), do: DateTime.from_iso8601(dt) |> elem(1)
  defp parse_datetime(%DateTime{} = dt), do: dt

  @doc """
  Get audience type description.
  """
  def audience_description(:researcher),
    do: "Academic researchers prioritizing methodology and replicability"

  def audience_description(:policymaker),
    do: "Policymakers needing authoritative sources and clear recommendations"

  def audience_description(:skeptic),
    do: "Skeptics demanding transparency and independent verification"

  def audience_description(:activist),
    do: "Activists seeking credible evidence for advocacy and action"

  def audience_description(:affected_person),
    do: "People directly affected who need clear, accessible explanations"

  def audience_description(:journalist),
    do: "Journalists balancing source credibility with storytelling needs"

  @doc """
  Get PROMPT score weights for audience type.
  """
  def prompt_weights(audience_type) do
    EvidenceGraph.PromptScores.audience_weights(audience_type)
  end
end

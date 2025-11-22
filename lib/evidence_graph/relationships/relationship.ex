defmodule EvidenceGraph.Relationships.Relationship do
  @moduledoc """
  Relationship (edge) schema for Evidence Graph.

  Represents connections between Claims and Evidence with weighted support/contradiction.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: String.t() | nil,
          from_id: String.t(),
          from_type: atom(),
          to_id: String.t(),
          to_type: atom(),
          relationship_type: atom(),
          weight: float(),
          confidence: float(),
          reasoning: String.t() | nil,
          created_by: String.t() | nil,
          metadata: map(),
          inserted_at: DateTime.t() | nil
        }

  @relationship_types [:supports, :contradicts, :contextualizes]

  @primary_key {:id, :string, autogenerate: false}
  schema "relationships" do
    field :from_id, :string
    field :from_type, Ecto.Enum, values: [:claim, :evidence]
    field :to_id, :string
    field :to_type, Ecto.Enum, values: [:claim, :evidence]
    field :relationship_type, Ecto.Enum, values: @relationship_types
    field :weight, :float, default: 0.5
    field :confidence, :float, default: 0.5
    field :reasoning, :string
    field :created_by, :string
    field :metadata, :map, default: %{}

    field :inserted_at, :utc_datetime
  end

  @doc false
  def changeset(relationship, attrs) do
    relationship
    |> cast(attrs, [
      :from_id,
      :from_type,
      :to_id,
      :to_type,
      :relationship_type,
      :weight,
      :confidence,
      :reasoning,
      :created_by,
      :metadata
    ])
    |> validate_required([:from_id, :from_type, :to_id, :to_type, :relationship_type])
    |> validate_inclusion(:relationship_type, @relationship_types)
    |> validate_number(:weight, greater_than_or_equal_to: -1.0, less_than_or_equal_to: 1.0)
    |> validate_number(:confidence, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0)
    |> put_id()
  end

  defp put_id(%Ecto.Changeset{data: %{id: nil}} = changeset) do
    put_change(changeset, :id, "rel_" <> Ecto.UUID.generate())
  end

  defp put_id(changeset), do: changeset

  @doc """
  Convert to ArangoDB edge document format.
  """
  def to_arango_doc(%__MODULE__{} = rel) do
    %{
      _key: rel.id,
      _from: "#{rel.from_type}s/#{rel.from_id}",
      _to: "#{rel.to_type}s/#{rel.to_id}",
      relationship_type: to_string(rel.relationship_type),
      weight: rel.weight,
      confidence: rel.confidence,
      reasoning: rel.reasoning,
      created_by: rel.created_by,
      metadata: rel.metadata,
      inserted_at: rel.inserted_at
    }
  end

  @doc """
  Convert from ArangoDB edge document to Relationship struct.
  """
  def from_arango_doc(doc) do
    {from_type, from_id} = parse_arango_id(doc["_from"])
    {to_type, to_id} = parse_arango_id(doc["_to"])

    %__MODULE__{
      id: doc["_key"],
      from_id: from_id,
      from_type: from_type,
      to_id: to_id,
      to_type: to_type,
      relationship_type: String.to_existing_atom(doc["relationship_type"]),
      weight: doc["weight"],
      confidence: doc["confidence"],
      reasoning: doc["reasoning"],
      created_by: doc["created_by"],
      metadata: doc["metadata"] || %{},
      inserted_at: parse_datetime(doc["inserted_at"])
    }
  end

  defp parse_arango_id(id) do
    [collection, key] = String.split(id, "/")

    type =
      case collection do
        "claims" -> :claim
        "evidence" -> :evidence
        _ -> :unknown
      end

    {type, key}
  end

  defp parse_datetime(nil), do: nil
  defp parse_datetime(dt) when is_binary(dt), do: DateTime.from_iso8601(dt) |> elem(1)
  defp parse_datetime(%DateTime{} = dt), do: dt

  @doc """
  Calculate confidence-adjusted weight.

  Lower confidence reduces the effective weight.
  """
  def effective_weight(%__MODULE__{} = rel) do
    rel.weight * rel.confidence
  end
end

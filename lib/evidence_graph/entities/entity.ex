# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
defmodule EvidenceGraph.Entities.Entity do
  @moduledoc """
  Entity schema for the Evidence Graph.

  Entities represent real-world actors and objects referenced across evidence
  and claims: people, organisations, locations, accounts, vessels, and aircraft.
  Used for Named-Entity Resolution (NER) co-reference linking.

  This is a validation-only Ecto schema -- persistence is handled by ArangoDB
  via the `bofig_entities` / `entities` collection.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: String.t() | nil,
          primary_name: String.t(),
          entity_type: atom(),
          aliases: list(String.t()),
          description: String.t() | nil,
          investigation_id: String.t(),
          first_appearance_date: Date.t() | nil,
          document_count: integer(),
          credibility_score: integer() | nil,
          metadata: map(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  @entity_types [:person, :organization, :location, :account, :vessel, :aircraft]

  @primary_key {:id, :string, autogenerate: false}
  schema "entities" do
    field :primary_name, :string
    field :entity_type, Ecto.Enum, values: @entity_types
    field :aliases, {:array, :string}, default: []
    field :description, :string
    field :investigation_id, :string
    field :first_appearance_date, :date
    field :document_count, :integer, default: 0
    field :credibility_score, :integer
    field :metadata, :map, default: %{}

    timestamps(type: :utc_datetime)
  end

  @doc """
  Returns the list of valid entity types.
  """
  def entity_types, do: @entity_types

  @doc false
  def changeset(entity, attrs) do
    entity
    |> cast(attrs, [
      :primary_name,
      :entity_type,
      :aliases,
      :description,
      :investigation_id,
      :first_appearance_date,
      :document_count,
      :credibility_score,
      :metadata
    ])
    |> validate_required([:primary_name, :entity_type, :investigation_id])
    |> validate_inclusion(:entity_type, @entity_types)
    |> validate_length(:primary_name, min: 1, max: 500)
    |> validate_number(:credibility_score,
      greater_than_or_equal_to: 0,
      less_than_or_equal_to: 100
    )
    |> validate_number(:document_count, greater_than_or_equal_to: 0)
    |> put_id()
  end

  defp put_id(%Ecto.Changeset{data: %{id: nil}} = changeset) do
    put_change(changeset, :id, "entity_" <> Ecto.UUID.generate())
  end

  defp put_id(changeset), do: changeset

  @doc """
  Convert an Entity struct to an ArangoDB document map.
  """
  def to_arango_doc(%__MODULE__{} = entity) do
    %{
      _key: entity.id,
      primary_name: entity.primary_name,
      entity_type: to_string(entity.entity_type),
      aliases: entity.aliases,
      description: entity.description,
      investigation_id: entity.investigation_id,
      first_appearance_date: encode_date(entity.first_appearance_date),
      document_count: entity.document_count,
      credibility_score: entity.credibility_score,
      metadata: entity.metadata,
      inserted_at: entity.inserted_at,
      updated_at: entity.updated_at
    }
  end

  @doc """
  Convert an ArangoDB document map to an Entity struct.
  """
  def from_arango_doc(doc) do
    %__MODULE__{
      id: doc["_key"],
      primary_name: doc["primary_name"],
      entity_type: safe_to_atom(doc["entity_type"]),
      aliases: doc["aliases"] || [],
      description: doc["description"],
      investigation_id: doc["investigation_id"],
      first_appearance_date: parse_date(doc["first_appearance_date"]),
      document_count: doc["document_count"] || 0,
      credibility_score: doc["credibility_score"],
      metadata: doc["metadata"] || %{},
      inserted_at: parse_datetime(doc["inserted_at"]),
      updated_at: parse_datetime(doc["updated_at"])
    }
  end

  # -- Private helpers -------------------------------------------------------

  defp safe_to_atom(nil), do: nil
  defp safe_to_atom(str) when is_binary(str), do: String.to_existing_atom(str)
  defp safe_to_atom(atom) when is_atom(atom), do: atom

  defp parse_datetime(nil), do: nil
  defp parse_datetime(dt) when is_binary(dt), do: DateTime.from_iso8601(dt) |> elem(1)
  defp parse_datetime(%DateTime{} = dt), do: dt

  defp parse_date(nil), do: nil
  defp parse_date(d) when is_binary(d), do: Date.from_iso8601!(d)
  defp parse_date(%Date{} = d), do: d

  defp encode_date(nil), do: nil
  defp encode_date(%Date{} = d), do: Date.to_iso8601(d)
end

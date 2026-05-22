# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
defmodule EvidenceGraph.Authorization.AccessGrant do
  @moduledoc """
  Ecto schema for the `access_grants` ArangoDB collection.

  Maps RBAC access grants between users and investigations. Each document
  records which user has which role on which investigation.

  This schema is used for validation (via changesets) and for in-memory
  representation. Persistence is handled by `EvidenceGraph.Authorization`
  which writes directly to ArangoDB.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @roles ~w(owner editor reviewer viewer)a

  @type t :: %__MODULE__{
          id: String.t() | nil,
          investigation_id: String.t(),
          user_id: String.t(),
          role: atom(),
          granted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  @primary_key {:id, :string, autogenerate: false}
  schema "access_grants" do
    field :investigation_id, :string
    field :user_id, :string
    field :role, Ecto.Enum, values: @roles
    field :granted_at, :utc_datetime
    field :updated_at, :utc_datetime
  end

  @doc false
  def changeset(grant, attrs) do
    grant
    |> cast(attrs, [:investigation_id, :user_id, :role])
    |> validate_required([:investigation_id, :user_id, :role])
    |> validate_inclusion(:role, @roles)
    |> put_id()
  end

  defp put_id(%Ecto.Changeset{data: %{id: nil}} = changeset) do
    inv_id = get_field(changeset, :investigation_id) || ""
    user_id = get_field(changeset, :user_id) || ""
    put_change(changeset, :id, "ag_#{inv_id}_#{user_id}")
  end

  defp put_id(changeset), do: changeset

  @doc """
  Convert to ArangoDB document format.
  """
  def to_arango_doc(%__MODULE__{} = grant) do
    %{
      _key: grant.id,
      investigation_id: grant.investigation_id,
      user_id: grant.user_id,
      role: to_string(grant.role),
      granted_at: grant.granted_at,
      updated_at: grant.updated_at
    }
  end

  @doc """
  Convert from ArangoDB document to AccessGrant struct.
  """
  def from_arango_doc(doc) do
    %__MODULE__{
      id: doc["_key"],
      investigation_id: doc["investigation_id"],
      user_id: doc["user_id"],
      role: String.to_existing_atom(doc["role"]),
      granted_at: parse_datetime(doc["granted_at"]),
      updated_at: parse_datetime(doc["updated_at"])
    }
  end

  defp parse_datetime(nil), do: nil
  defp parse_datetime(dt) when is_binary(dt), do: DateTime.from_iso8601(dt) |> elem(1)
  defp parse_datetime(%DateTime{} = dt), do: dt
end

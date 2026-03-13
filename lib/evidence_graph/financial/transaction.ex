# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
defmodule EvidenceGraph.Financial.Transaction do
  @moduledoc """
  Transaction schema for the Financial Transaction Graph.

  Represents a financial transaction between two entities in an investigation.
  Stored as an edge document in ArangoDB's `financial_transactions` edge collection,
  linking source and destination entities.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: String.t() | nil,
          investigation_id: String.t(),
          source_entity_id: String.t(),
          destination_entity_id: String.t(),
          amount: float(),
          currency: String.t(),
          transaction_date: Date.t(),
          instrument: atom(),
          intermediary_entity_id: String.t() | nil,
          source_account: String.t() | nil,
          destination_account: String.t() | nil,
          source_evidence_id: String.t() | nil,
          anomaly_flags: list(String.t()),
          notes: String.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  @currencies ~w(USD GBP EUR CHF JPY CAD AUD OTHER)
  @instruments [
    :wire_transfer,
    :check,
    :cash,
    :credit_card,
    :crypto,
    :trust_payment,
    :shell_company,
    :other
  ]

  @primary_key {:id, :string, autogenerate: false}
  schema "financial_transactions" do
    field :investigation_id, :string
    field :source_entity_id, :string
    field :destination_entity_id, :string
    field :amount, :float
    field :currency, :string
    field :transaction_date, :date
    field :instrument, Ecto.Enum, values: @instruments
    field :intermediary_entity_id, :string
    field :source_account, :string
    field :destination_account, :string
    field :source_evidence_id, :string
    field :anomaly_flags, {:array, :string}, default: []
    field :notes, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(transaction, attrs) do
    transaction
    |> cast(attrs, [
      :investigation_id,
      :source_entity_id,
      :destination_entity_id,
      :amount,
      :currency,
      :transaction_date,
      :instrument,
      :intermediary_entity_id,
      :source_account,
      :destination_account,
      :source_evidence_id,
      :anomaly_flags,
      :notes
    ])
    |> validate_required([
      :investigation_id,
      :source_entity_id,
      :destination_entity_id,
      :amount,
      :currency,
      :transaction_date,
      :instrument
    ])
    |> validate_inclusion(:currency, @currencies)
    |> validate_inclusion(:instrument, @instruments)
    |> validate_number(:amount, greater_than: 0.0)
    |> put_id()
  end

  defp put_id(%Ecto.Changeset{data: %{id: nil}} = changeset) do
    put_change(changeset, :id, "txn_" <> Ecto.UUID.generate())
  end

  defp put_id(changeset), do: changeset

  @doc """
  Convert to ArangoDB edge document format.

  Edge documents require `_from` and `_to` fields referencing the
  source and destination entity documents in the `entities` collection.
  """
  def to_arango_doc(%__MODULE__{} = txn) do
    %{
      _key: txn.id,
      _from: "entities/#{txn.source_entity_id}",
      _to: "entities/#{txn.destination_entity_id}",
      investigation_id: txn.investigation_id,
      source_entity_id: txn.source_entity_id,
      destination_entity_id: txn.destination_entity_id,
      amount: txn.amount,
      currency: txn.currency,
      transaction_date: format_date(txn.transaction_date),
      instrument: to_string(txn.instrument),
      intermediary_entity_id: txn.intermediary_entity_id,
      source_account: txn.source_account,
      destination_account: txn.destination_account,
      source_evidence_id: txn.source_evidence_id,
      anomaly_flags: txn.anomaly_flags,
      notes: txn.notes,
      inserted_at: txn.inserted_at,
      updated_at: txn.updated_at
    }
  end

  @doc """
  Convert from ArangoDB edge document to Transaction struct.
  """
  def from_arango_doc(doc) do
    %__MODULE__{
      id: doc["_key"],
      investigation_id: doc["investigation_id"],
      source_entity_id: doc["source_entity_id"],
      destination_entity_id: doc["destination_entity_id"],
      amount: doc["amount"],
      currency: doc["currency"],
      transaction_date: parse_date(doc["transaction_date"]),
      instrument: parse_instrument(doc["instrument"]),
      intermediary_entity_id: doc["intermediary_entity_id"],
      source_account: doc["source_account"],
      destination_account: doc["destination_account"],
      source_evidence_id: doc["source_evidence_id"],
      anomaly_flags: doc["anomaly_flags"] || [],
      notes: doc["notes"],
      inserted_at: parse_datetime(doc["inserted_at"]),
      updated_at: parse_datetime(doc["updated_at"])
    }
  end

  defp format_date(nil), do: nil
  defp format_date(%Date{} = d), do: Date.to_iso8601(d)
  defp format_date(d) when is_binary(d), do: d

  defp parse_date(nil), do: nil

  defp parse_date(d) when is_binary(d) do
    case Date.from_iso8601(d) do
      {:ok, date} -> date
      _ -> nil
    end
  end

  defp parse_date(%Date{} = d), do: d

  defp parse_instrument(nil), do: :other

  defp parse_instrument(s) when is_binary(s) do
    String.to_existing_atom(s)
  rescue
    ArgumentError -> :other
  end

  defp parse_datetime(nil), do: nil
  defp parse_datetime(dt) when is_binary(dt), do: DateTime.from_iso8601(dt) |> elem(1)
  defp parse_datetime(%DateTime{} = dt), do: dt
end

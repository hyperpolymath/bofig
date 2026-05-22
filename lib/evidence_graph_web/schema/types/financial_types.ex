# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
defmodule EvidenceGraphWeb.Schema.Types.FinancialTypes do
  @moduledoc """
  GraphQL types for the Financial Transaction Graph.
  """

  use Absinthe.Schema.Notation

  # ---------------------------------------------------------------------------
  # Enums
  # ---------------------------------------------------------------------------

  enum :currency_enum do
    value :usd, description: "US Dollar"
    value :gbp, description: "British Pound"
    value :eur, description: "Euro"
    value :chf, description: "Swiss Franc"
    value :jpy, description: "Japanese Yen"
    value :cad, description: "Canadian Dollar"
    value :aud, description: "Australian Dollar"
    value :other, description: "Other currency"
  end

  enum :instrument_enum do
    value :wire_transfer, description: "Wire transfer"
    value :check, description: "Check / cheque"
    value :cash, description: "Cash"
    value :credit_card, description: "Credit card"
    value :crypto, description: "Cryptocurrency"
    value :trust_payment, description: "Trust payment"
    value :shell_company, description: "Shell company transfer"
    value :other, description: "Other instrument"
  end

  enum :anomaly_severity_enum do
    value :low
    value :medium
    value :high
    value :critical
  end

  # ---------------------------------------------------------------------------
  # Objects
  # ---------------------------------------------------------------------------

  @desc "A financial transaction between two entities"
  object :transaction do
    field :id, non_null(:id)
    field :investigation_id, non_null(:string)
    field :source_entity_id, non_null(:string)
    field :destination_entity_id, non_null(:string)
    field :amount, non_null(:float)
    field :currency, non_null(:string)
    field :transaction_date, non_null(:date)
    field :instrument, non_null(:instrument_enum)
    field :intermediary_entity_id, :string
    field :source_account, :string
    field :destination_account, :string
    field :source_evidence_id, :string
    field :anomaly_flags, list_of(:string)
    field :notes, :string
    field :inserted_at, non_null(:datetime)
    field :updated_at, non_null(:datetime)
  end

  @desc "A step in a transaction chain graph traversal"
  object :transaction_chain_result do
    field :entity, non_null(:json)
    field :transaction, non_null(:transaction)
    field :path, :json
  end

  @desc "Sankey diagram data for D3.js visualisation"
  object :sankey_data do
    field :nodes, non_null(list_of(:sankey_node))
    field :links, non_null(list_of(:sankey_link))
  end

  @desc "A node in the Sankey diagram"
  object :sankey_node do
    field :id, non_null(:string)
    field :name, non_null(:string)
  end

  @desc "A link in the Sankey diagram"
  object :sankey_link do
    field :source, non_null(:string)
    field :target, non_null(:string)
    field :value, non_null(:float)
  end

  @desc "Aggregated flow between two entities"
  object :flow_aggregate do
    field :total_amount, non_null(:float)
    field :currency, non_null(:string)
    field :transaction_count, non_null(:integer)
  end

  @desc "A detected anomaly in a financial transaction"
  object :anomaly do
    field :transaction_id, non_null(:id)
    field :type, non_null(:string)
    field :description, non_null(:string)
    field :severity, non_null(:string)
  end

  # ---------------------------------------------------------------------------
  # Input objects
  # ---------------------------------------------------------------------------

  input_object :create_transaction_input do
    field :investigation_id, non_null(:string)
    field :source_entity_id, non_null(:string)
    field :destination_entity_id, non_null(:string)
    field :amount, non_null(:float)
    field :currency, non_null(:string)
    field :transaction_date, non_null(:date)
    field :instrument, non_null(:instrument_enum)
    field :intermediary_entity_id, :string
    field :source_account, :string
    field :destination_account, :string
    field :source_evidence_id, :string
    field :anomaly_flags, list_of(:string)
    field :notes, :string
  end
end

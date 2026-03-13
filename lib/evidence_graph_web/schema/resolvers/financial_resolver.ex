# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
defmodule EvidenceGraphWeb.Schema.Resolvers.FinancialResolver do
  @moduledoc """
  GraphQL resolvers for Financial Transaction queries and mutations.
  """

  alias EvidenceGraph.Financial

  # ---------------------------------------------------------------------------
  # Queries
  # ---------------------------------------------------------------------------

  @doc "List transactions for an investigation."
  def list_transactions(%{investigation_id: inv_id} = args, _resolution) do
    Financial.list_transactions(inv_id, limit: args[:limit] || 100, offset: args[:offset] || 0)
  end

  @doc "Get a single transaction by ID."
  def get_transaction(%{id: id}, _resolution) do
    Financial.get_transaction(id)
  end

  @doc "Follow-the-money graph traversal from an entity."
  def transaction_chain(%{entity_id: entity_id} = args, _resolution) do
    depth = args[:depth] || 3
    opts = if args[:investigation_id], do: [investigation_id: args[:investigation_id]], else: []
    Financial.transaction_chain(entity_id, depth, opts)
  end

  @doc "Aggregate total flow between two entities."
  def total_flow(%{from_id: from_id, to_id: to_id} = args, _resolution) do
    opts =
      []
      |> maybe_put(:start_date, args[:start_date])
      |> maybe_put(:end_date, args[:end_date])

    Financial.total_flow(from_id, to_id, opts)
  end

  @doc "Detect anomalies across transactions in an investigation."
  def anomalies(%{investigation_id: inv_id}, _resolution) do
    Financial.detect_anomalies(inv_id)
  end

  @doc "Format transaction data as a Sankey diagram."
  def sankey_data(%{investigation_id: inv_id}, _resolution) do
    Financial.sankey_data(inv_id)
  end

  # ---------------------------------------------------------------------------
  # Mutations
  # ---------------------------------------------------------------------------

  @doc "Create a new financial transaction."
  def create_transaction(%{input: input}, _resolution) do
    Financial.create_transaction(input)
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, key, value), do: Keyword.put(opts, key, value)
end

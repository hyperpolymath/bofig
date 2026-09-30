# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
defmodule EvidenceGraphWeb.Schema.Resolvers.FinancialResolver do
  @moduledoc """
  GraphQL resolvers for Financial Transaction queries and mutations.

  All resolvers enforce RBAC authorization by checking the authenticated
  user's access to the investigation that owns the financial data.
  """

  alias EvidenceGraph.Authorization
  alias EvidenceGraph.Entities
  alias EvidenceGraph.Financial
  import EvidenceGraphWeb.Schema, only: [require_auth: 1]

  # ---------------------------------------------------------------------------
  # Queries
  # ---------------------------------------------------------------------------

  @doc "List transactions for an investigation."
  def list_transactions(%{investigation_id: inv_id} = args, resolution) do
    with {:ok, user_id} <- require_auth(resolution),
         :ok <- Authorization.check_access(inv_id, user_id, :view) do
      Financial.list_transactions(inv_id, limit: args[:limit] || 100, offset: args[:offset] || 0)
    end
  end

  @doc "Get a single transaction by ID."
  def get_transaction(%{id: id}, resolution) do
    with {:ok, user_id} <- require_auth(resolution),
         {:ok, txn} <- Financial.get_transaction(id),
         :ok <- Authorization.check_access(txn.investigation_id, user_id, :view) do
      {:ok, txn}
    end
  end

  @doc "Follow-the-money graph traversal from an entity."
  def transaction_chain(%{entity_id: entity_id} = args, resolution) do
    with {:ok, user_id} <- require_auth(resolution),
         {:ok, inv_id} <- chain_investigation(entity_id, args),
         :ok <- Authorization.check_access(inv_id, user_id, :view) do
      depth = args[:depth] || 3
      opts = if args[:investigation_id], do: [investigation_id: args[:investigation_id]], else: []
      Financial.transaction_chain(entity_id, depth, opts)
    end
  end

  @doc "Aggregate total flow between two entities."
  def total_flow(%{from_id: from_id, to_id: to_id} = args, resolution) do
    with {:ok, user_id} <- require_auth(resolution),
         {:ok, entity} <- Entities.get_entity(from_id),
         :ok <- Authorization.check_access(entity.investigation_id, user_id, :view) do
      opts =
        []
        |> maybe_put(:start_date, args[:start_date])
        |> maybe_put(:end_date, args[:end_date])

      Financial.total_flow(from_id, to_id, opts)
    end
  end

  @doc "Detect anomalies across transactions in an investigation."
  def anomalies(%{investigation_id: inv_id}, resolution) do
    with {:ok, user_id} <- require_auth(resolution),
         :ok <- Authorization.check_access(inv_id, user_id, :view) do
      Financial.detect_anomalies(inv_id)
    end
  end

  @doc "Format transaction data as a Sankey diagram."
  def sankey_data(%{investigation_id: inv_id}, resolution) do
    with {:ok, user_id} <- require_auth(resolution),
         :ok <- Authorization.check_access(inv_id, user_id, :view) do
      Financial.sankey_data(inv_id)
    end
  end

  # ---------------------------------------------------------------------------
  # Mutations
  # ---------------------------------------------------------------------------

  @doc "Create a new financial transaction."
  def create_transaction(%{input: input}, resolution) do
    with {:ok, user_id} <- require_auth(resolution),
         :ok <- Authorization.check_access(input.investigation_id, user_id, :edit) do
      Financial.create_transaction(input)
    end
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, key, value), do: Keyword.put(opts, key, value)

  defp chain_investigation(entity_id, args) do
    inv_id = args[:investigation_id] || entity_investigation(entity_id)
    if inv_id, do: {:ok, inv_id}, else: {:error, :not_found}
  end

  defp entity_investigation(entity_id) do
    case Entities.get_entity(entity_id) do
      {:ok, entity} -> entity.investigation_id
      _ -> nil
    end
  end
end

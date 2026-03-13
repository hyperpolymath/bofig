# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
defmodule EvidenceGraph.Financial do
  @moduledoc """
  Context for managing Financial Transactions in the Evidence Graph.

  Provides functions for creating, querying, and analysing financial transactions
  stored as edge documents in ArangoDB's `financial_transactions` edge collection.
  Includes graph traversal for follow-the-money analysis, flow aggregation,
  anomaly detection, and Sankey diagram data formatting.
  """

  alias EvidenceGraph.ArangoDB
  alias EvidenceGraph.Financial.Transaction

  # ---------------------------------------------------------------------------
  # CRUD
  # ---------------------------------------------------------------------------

  @doc """
  Create a new financial transaction.

  ## Examples

      iex> create_transaction(%{
      ...>   investigation_id: "inv_123",
      ...>   source_entity_id: "ent_abc",
      ...>   destination_entity_id: "ent_def",
      ...>   amount: 50_000.00,
      ...>   currency: "GBP",
      ...>   transaction_date: ~D[2024-03-15],
      ...>   instrument: :wire_transfer
      ...> })
      {:ok, %Transaction{}}
  """
  def create_transaction(attrs) do
    changeset = Transaction.changeset(%Transaction{}, attrs)

    if changeset.valid? do
      transaction =
        Ecto.Changeset.apply_changes(changeset)
        |> Map.put(:inserted_at, DateTime.utc_now())
        |> Map.put(:updated_at, DateTime.utc_now())

      case ArangoDB.insert("financial_transactions", Transaction.to_arango_doc(transaction)) do
        {:ok, doc} -> {:ok, Transaction.from_arango_doc(doc)}
        error -> error
      end
    else
      {:error, changeset}
    end
  end

  @doc """
  Get a transaction by ID.
  """
  def get_transaction(id) do
    case ArangoDB.get("financial_transactions", id) do
      {:ok, doc} -> {:ok, Transaction.from_arango_doc(doc)}
      error -> error
    end
  end

  @doc """
  List transactions for an investigation with pagination.
  """
  def list_transactions(investigation_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 100)
    offset = Keyword.get(opts, :offset, 0)

    aql = """
    FOR txn IN financial_transactions
      FILTER txn.investigation_id == @investigation_id
      SORT txn.transaction_date DESC
      LIMIT @offset, @limit
      RETURN txn
    """

    case ArangoDB.query_read(aql, %{
           investigation_id: investigation_id,
           limit: limit,
           offset: offset
         }) do
      {:ok, docs} -> {:ok, Enum.map(docs, &Transaction.from_arango_doc/1)}
      error -> error
    end
  end

  # ---------------------------------------------------------------------------
  # Graph traversal — follow the money
  # ---------------------------------------------------------------------------

  @doc """
  Traverse the financial transaction graph from an entity, following money
  through up to `depth` hops.

  Returns a list of `%{entity: map, transaction: map, path: map}` results
  representing each vertex, edge, and path encountered during the traversal.
  """
  def transaction_chain(entity_id, depth \\ 3, opts \\ []) do
    investigation_id = Keyword.get(opts, :investigation_id)

    filter_clause =
      if investigation_id do
        "FILTER e.investigation_id == @investigation_id"
      else
        ""
      end

    aql = """
    FOR v, e, p IN 1..@depth OUTBOUND @start_id financial_transactions
      #{filter_clause}
      RETURN {entity: v, transaction: e, path: p}
    """

    vars =
      %{
        start_id: "entities/#{entity_id}",
        depth: depth,
        investigation_id: investigation_id
      }
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> Map.new()

    case ArangoDB.query_read(aql, vars) do
      {:ok, results} ->
        chain =
          Enum.map(results, fn %{"entity" => ent, "transaction" => txn, "path" => path} ->
            %{
              entity: ent,
              transaction: Transaction.from_arango_doc(txn),
              path: path
            }
          end)

        {:ok, chain}

      error ->
        error
    end
  end

  # ---------------------------------------------------------------------------
  # Aggregation — total flow between two entities
  # ---------------------------------------------------------------------------

  @doc """
  Aggregate the total monetary flow between two entities within an optional
  date range. Groups results by currency.
  """
  def total_flow(from_entity_id, to_entity_id, opts \\ []) do
    start_date = Keyword.get(opts, :start_date)
    end_date = Keyword.get(opts, :end_date)

    date_filter =
      cond do
        start_date && end_date ->
          "FILTER txn.transaction_date >= @start_date AND txn.transaction_date <= @end_date"

        start_date ->
          "FILTER txn.transaction_date >= @start_date"

        end_date ->
          "FILTER txn.transaction_date <= @end_date"

        true ->
          ""
      end

    aql = """
    FOR txn IN financial_transactions
      FILTER txn.source_entity_id == @from_id
      FILTER txn.destination_entity_id == @to_id
      #{date_filter}
      COLLECT currency = txn.currency
      AGGREGATE total = SUM(txn.amount), count = LENGTH(1)
      RETURN {
        currency: currency,
        total_amount: total,
        transaction_count: count
      }
    """

    vars =
      %{
        from_id: from_entity_id,
        to_id: to_entity_id,
        start_date: format_date_param(start_date),
        end_date: format_date_param(end_date)
      }
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> Map.new()

    case ArangoDB.query_read(aql, vars) do
      {:ok, results} ->
        aggregates =
          Enum.map(results, fn r ->
            %{
              currency: r["currency"],
              total_amount: r["total_amount"],
              transaction_count: r["transaction_count"]
            }
          end)

        {:ok, aggregates}

      error ->
        error
    end
  end

  # ---------------------------------------------------------------------------
  # Anomaly detection
  # ---------------------------------------------------------------------------

  @doc """
  Detect anomalies in financial transactions for an investigation.

  Flags:
  - **round_number**: Exact round amounts (e.g. $10,000.00, $50,000.00)
  - **structuring**: Multiple transactions just under reporting thresholds
  - **unusual_timing**: Transactions on weekends or known holidays
  - **rapid_succession**: Multiple transactions between same parties within 24h
  """
  def detect_anomalies(investigation_id, opts \\ []) do
    threshold = Keyword.get(opts, :structuring_threshold, 10_000.0)

    with {:ok, transactions} <- list_transactions(investigation_id, limit: 10_000) do
      anomalies =
        Enum.flat_map(transactions, fn txn ->
          flags = []

          # Round number detection
          flags =
            if is_round_number?(txn.amount) do
              [build_anomaly(txn, "round_number", "Exact round amount: #{txn.currency} #{txn.amount}", :medium) | flags]
            else
              flags
            end

          # Structuring detection (just under threshold)
          flags =
            if txn.amount >= threshold * 0.8 and txn.amount < threshold do
              [build_anomaly(txn, "structuring", "Amount #{txn.currency} #{txn.amount} is just under #{threshold} threshold", :high) | flags]
            else
              flags
            end

          # Weekend timing
          flags =
            if txn.transaction_date && Date.day_of_week(txn.transaction_date) in [6, 7] do
              [build_anomaly(txn, "unusual_timing", "Transaction on weekend: #{txn.transaction_date}", :low) | flags]
            else
              flags
            end

          flags
        end)

      # Rapid succession detection (multiple txns between same parties same day)
      rapid_anomalies = detect_rapid_succession(transactions)

      {:ok, anomalies ++ rapid_anomalies}
    end
  end

  # ---------------------------------------------------------------------------
  # Sankey diagram data
  # ---------------------------------------------------------------------------

  @doc """
  Format transaction data for a D3.js Sankey diagram.

  Returns `%{nodes: [%{id, name}], links: [%{source, target, value}]}` where
  links are aggregated by source/destination entity pair.
  """
  def sankey_data(investigation_id, _opts \\ []) do
    aql = """
    LET txns = (
      FOR txn IN financial_transactions
        FILTER txn.investigation_id == @investigation_id
        RETURN txn
    )

    LET entity_ids = UNION_DISTINCT(
      (FOR t IN txns RETURN t.source_entity_id),
      (FOR t IN txns RETURN t.destination_entity_id)
    )

    LET nodes = (
      FOR eid IN entity_ids
        LET entity = FIRST(
          FOR e IN entities
            FILTER e._key == eid
            RETURN e
        )
        RETURN {
          id: eid,
          name: entity.name != null ? entity.name : eid
        }
    )

    LET links = (
      FOR txn IN txns
        COLLECT source = txn.source_entity_id, target = txn.destination_entity_id
        AGGREGATE value = SUM(txn.amount)
        RETURN {
          source: source,
          target: target,
          value: value
        }
    )

    RETURN {nodes: nodes, links: links}
    """

    case ArangoDB.query_read(aql, %{investigation_id: investigation_id}) do
      {:ok, [result]} ->
        {:ok, %{
          nodes: result["nodes"] || [],
          links: result["links"] || []
        }}

      {:ok, []} ->
        {:ok, %{nodes: [], links: []}}

      error ->
        error
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp is_round_number?(amount) when is_float(amount) do
    # Check if the amount is a round number (multiple of 1000 with no cents)
    rem_cents = :erlang.float_to_binary(amount, decimals: 2)
    String.ends_with?(rem_cents, "000.00") or
      String.ends_with?(rem_cents, "500.00")
  end

  defp is_round_number?(_), do: false

  defp build_anomaly(txn, type, description, severity) do
    %{
      transaction_id: txn.id,
      type: type,
      description: description,
      severity: to_string(severity)
    }
  end

  defp detect_rapid_succession(transactions) do
    transactions
    |> Enum.group_by(fn txn -> {txn.source_entity_id, txn.destination_entity_id} end)
    |> Enum.flat_map(fn {{src, dst}, txns} ->
      txns
      |> Enum.sort_by(& &1.transaction_date, Date)
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.filter(fn [a, b] ->
        a.transaction_date && b.transaction_date &&
          Date.diff(b.transaction_date, a.transaction_date) == 0
      end)
      |> Enum.map(fn [a, _b] ->
        build_anomaly(
          a,
          "rapid_succession",
          "Multiple transactions between #{src} and #{dst} on #{a.transaction_date}",
          :high
        )
      end)
    end)
  end

  defp format_date_param(nil), do: nil
  defp format_date_param(%Date{} = d), do: Date.to_iso8601(d)
  defp format_date_param(s) when is_binary(s), do: s
end

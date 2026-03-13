# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
defmodule EvidenceGraphWeb.TimelineLive do
  @moduledoc """
  Timeline Visualization LiveView.

  Loads events from evidence (document_date), claims (claim date), and
  financial transactions (transaction_date), then pushes the combined
  dataset to a D3.js horizontal timeline via `push_event/3`.

  Supports granularity switching (day/week/month), entity filtering,
  and date range selection.
  """

  use EvidenceGraphWeb, :live_view

  alias EvidenceGraph.Claims
  alias EvidenceGraph.Evidence
  alias EvidenceGraph.Financial
  alias EvidenceGraph.PromptScores

  @granularities ~w(day week month)
  @event_types ~w(evidence claim transaction)

  @impl true
  def mount(%{"id" => investigation_id}, _session, socket) do
    events = build_timeline_events(investigation_id)

    {:ok,
     assign(socket,
       page_title: "Investigation Timeline",
       investigation_id: investigation_id,
       events: events,
       granularity: "month",
       granularities: @granularities,
       event_types: @event_types,
       active_types: @event_types,
       entity_filter: nil,
       date_start: nil,
       date_end: nil
     )}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    send(self(), :push_timeline)
    {:noreply, socket}
  end

  @impl true
  def handle_info(:push_timeline, socket) do
    filtered = filter_events(socket.assigns)
    {:noreply, push_event(socket, "timeline_data", %{events: filtered, granularity: socket.assigns.granularity})}
  end

  # ---------------------------------------------------------------------------
  # Events from client
  # ---------------------------------------------------------------------------

  @impl true
  def handle_event("set_granularity", %{"granularity" => granularity}, socket)
      when granularity in @granularities do
    socket =
      socket
      |> assign(granularity: granularity)

    filtered = filter_events(socket.assigns)

    {:noreply, push_event(socket, "timeline_data", %{events: filtered, granularity: granularity})}
  end

  def handle_event("toggle_type", %{"type" => type}, socket) when type in @event_types do
    active =
      if type in socket.assigns.active_types do
        List.delete(socket.assigns.active_types, type)
      else
        [type | socket.assigns.active_types]
      end

    socket = assign(socket, active_types: active)
    filtered = filter_events(socket.assigns)

    {:noreply, push_event(socket, "timeline_data", %{events: filtered, granularity: socket.assigns.granularity})}
  end

  def handle_event("filter_entity", %{"entity_id" => ""}, socket) do
    socket = assign(socket, entity_filter: nil)
    filtered = filter_events(socket.assigns)
    {:noreply, push_event(socket, "timeline_data", %{events: filtered, granularity: socket.assigns.granularity})}
  end

  def handle_event("filter_entity", %{"entity_id" => entity_id}, socket) do
    socket = assign(socket, entity_filter: entity_id)
    filtered = filter_events(socket.assigns)
    {:noreply, push_event(socket, "timeline_data", %{events: filtered, granularity: socket.assigns.granularity})}
  end

  def handle_event("filter_dates", %{"start" => start_str, "end" => end_str}, socket) do
    date_start = parse_date_input(start_str)
    date_end = parse_date_input(end_str)

    socket = assign(socket, date_start: date_start, date_end: date_end)
    filtered = filter_events(socket.assigns)

    {:noreply, push_event(socket, "timeline_data", %{events: filtered, granularity: socket.assigns.granularity})}
  end

  def handle_event("event_clicked", %{"id" => id, "type" => type}, socket) do
    {:noreply, push_navigate(socket, to: detail_path(socket.assigns.investigation_id, type, id))}
  end

  # ---------------------------------------------------------------------------
  # Render
  # ---------------------------------------------------------------------------

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-4">
      <.header>
        Timeline: {@investigation_id}
        <:actions>
          <.link navigate={~p"/investigations/#{@investigation_id}"}>
            <.button>Details</.button>
          </.link>
          <.link navigate={~p"/investigations/#{@investigation_id}/graph"}>
            <.button>Graph</.button>
          </.link>
        </:actions>
      </.header>

      <%!-- Controls --%>
      <div class="flex flex-wrap gap-4 items-end">
        <%!-- Granularity selector --%>
        <div>
          <label class="block text-xs font-medium text-gray-600 dark:text-gray-400 mb-1">
            Granularity
          </label>
          <div class="flex gap-1">
            <button
              :for={g <- @granularities}
              phx-click="set_granularity"
              phx-value-granularity={g}
              class={[
                "px-3 py-1 text-sm rounded",
                if(@granularity == g,
                  do: "bg-blue-600 text-white",
                  else: "bg-gray-200 dark:bg-gray-700 text-gray-700 dark:text-gray-300 hover:bg-gray-300"
                )
              ]}
            >
              {String.capitalize(g)}
            </button>
          </div>
        </div>

        <%!-- Event type toggles --%>
        <div>
          <label class="block text-xs font-medium text-gray-600 dark:text-gray-400 mb-1">
            Event Types
          </label>
          <div class="flex gap-1">
            <button
              :for={t <- @event_types}
              phx-click="toggle_type"
              phx-value-type={t}
              class={[
                "px-3 py-1 text-sm rounded",
                if(t in @active_types,
                  do: type_active_class(t),
                  else: "bg-gray-200 dark:bg-gray-700 text-gray-500"
                )
              ]}
            >
              {String.capitalize(t)}
            </button>
          </div>
        </div>

        <%!-- Entity filter --%>
        <div>
          <label class="block text-xs font-medium text-gray-600 dark:text-gray-400 mb-1">
            Entity filter
          </label>
          <form phx-change="filter_entity" class="flex gap-1">
            <input
              type="text"
              name="entity_id"
              value={@entity_filter || ""}
              placeholder="Entity ID..."
              class="px-2 py-1 text-sm border rounded dark:bg-gray-800 dark:border-gray-600"
            />
          </form>
        </div>

        <%!-- Date range --%>
        <div>
          <label class="block text-xs font-medium text-gray-600 dark:text-gray-400 mb-1">
            Date range
          </label>
          <form phx-change="filter_dates" class="flex gap-1">
            <input
              type="date"
              name="start"
              value={format_date_input(@date_start)}
              class="px-2 py-1 text-sm border rounded dark:bg-gray-800 dark:border-gray-600"
            />
            <span class="self-center text-gray-400">-</span>
            <input
              type="date"
              name="end"
              value={format_date_input(@date_end)}
              class="px-2 py-1 text-sm border rounded dark:bg-gray-800 dark:border-gray-600"
            />
          </form>
        </div>
      </div>

      <%!-- D3 Timeline container --%>
      <div
        id="investigation-timeline"
        phx-hook="TimelineHook"
        phx-update="ignore"
        class="timeline-container border rounded dark:border-gray-700"
        style="min-height: 300px; width: 100%;"
      >
      </div>

      <%!-- Legend --%>
      <div class="flex gap-4 text-xs text-gray-500 dark:text-gray-400">
        <span class="flex items-center gap-1">
          <span class="inline-block w-3 h-3 rounded-full bg-blue-500"></span>
          Evidence
        </span>
        <span class="flex items-center gap-1">
          <span class="inline-block w-3 h-3 rounded-full bg-green-500"></span>
          Claim
        </span>
        <span class="flex items-center gap-1">
          <span class="inline-block w-3 h-3 rounded-full bg-red-500"></span>
          Transaction
        </span>
        <span class="text-gray-400 italic">
          Circle size = PROMPT score
        </span>
      </div>

      <.back navigate={~p"/investigations/#{@investigation_id}"}>Back to investigation</.back>
    </div>
    """
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp build_timeline_events(investigation_id) do
    evidence_events = build_evidence_events(investigation_id)
    claim_events = build_claim_events(investigation_id)
    transaction_events = build_transaction_events(investigation_id)

    (evidence_events ++ claim_events ++ transaction_events)
    |> Enum.sort_by(& &1.date, Date)
  end

  defp build_evidence_events(investigation_id) do
    case Evidence.list_evidence(investigation_id, limit: 10_000) do
      {:ok, items} ->
        Enum.flat_map(items, fn e ->
          date = extract_evidence_date(e)

          if date do
            [%{
              id: e.id,
              type: "evidence",
              label: e.title,
              date: date,
              prompt_score: PromptScores.calculate_overall(e.prompt_scores),
              entity_ids: []
            }]
          else
            []
          end
        end)

      _ ->
        []
    end
  end

  defp build_claim_events(investigation_id) do
    case Claims.list_claims(investigation_id, limit: 10_000) do
      {:ok, items} ->
        Enum.map(items, fn c ->
          %{
            id: c.id,
            type: "claim",
            label: String.slice(c.text, 0, 80),
            date: DateTime.to_date(c.inserted_at),
            prompt_score: PromptScores.calculate_overall(c.prompt_scores),
            entity_ids: []
          }
        end)

      _ ->
        []
    end
  end

  defp build_transaction_events(investigation_id) do
    case Financial.list_transactions(investigation_id, limit: 10_000) do
      {:ok, items} ->
        Enum.map(items, fn txn ->
          %{
            id: txn.id,
            type: "transaction",
            label: "#{txn.currency} #{txn.amount} (#{txn.instrument})",
            date: txn.transaction_date,
            prompt_score: 50.0,
            entity_ids: [txn.source_entity_id, txn.destination_entity_id]
          }
        end)

      _ ->
        []
    end
  end

  defp extract_evidence_date(evidence) do
    cond do
      date_str = get_in(evidence.dublin_core, ["date"]) ->
        case Date.from_iso8601(date_str) do
          {:ok, d} -> d
          _ -> evidence.inserted_at && DateTime.to_date(evidence.inserted_at)
        end

      evidence.inserted_at ->
        DateTime.to_date(evidence.inserted_at)

      true ->
        nil
    end
  end

  defp filter_events(assigns) do
    assigns.events
    |> Enum.filter(fn evt -> evt.type in assigns.active_types end)
    |> maybe_filter_entity(assigns.entity_filter)
    |> maybe_filter_date_range(assigns.date_start, assigns.date_end)
    |> Enum.map(fn evt ->
      %{
        id: evt.id,
        type: evt.type,
        label: evt.label,
        date: Date.to_iso8601(evt.date),
        prompt_score: evt.prompt_score,
        entity_ids: evt.entity_ids
      }
    end)
  end

  defp maybe_filter_entity(events, nil), do: events

  defp maybe_filter_entity(events, entity_id) do
    Enum.filter(events, fn evt ->
      entity_id in (evt.entity_ids || [])
    end)
  end

  defp maybe_filter_date_range(events, nil, nil), do: events

  defp maybe_filter_date_range(events, start_date, end_date) do
    Enum.filter(events, fn evt ->
      after_start = is_nil(start_date) or Date.compare(evt.date, start_date) != :lt
      before_end = is_nil(end_date) or Date.compare(evt.date, end_date) != :gt
      after_start and before_end
    end)
  end

  defp detail_path(investigation_id, "evidence", id) do
    ~p"/investigations/#{investigation_id}?evidence=#{id}"
  end

  defp detail_path(investigation_id, _type, _id) do
    ~p"/investigations/#{investigation_id}"
  end

  defp type_active_class("evidence"), do: "bg-blue-500 text-white"
  defp type_active_class("claim"), do: "bg-green-500 text-white"
  defp type_active_class("transaction"), do: "bg-red-500 text-white"
  defp type_active_class(_), do: "bg-gray-500 text-white"

  defp parse_date_input(""), do: nil
  defp parse_date_input(nil), do: nil

  defp parse_date_input(str) when is_binary(str) do
    case Date.from_iso8601(str) do
      {:ok, d} -> d
      _ -> nil
    end
  end

  defp format_date_input(nil), do: ""
  defp format_date_input(%Date{} = d), do: Date.to_iso8601(d)
end

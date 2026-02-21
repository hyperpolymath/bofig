# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
defmodule EvidenceGraphWeb.PromptLive do
  @moduledoc """
  PROMPT scoring interface LiveView.

  Renders a radar/spider chart for the 6 PROMPT dimensions using the
  PromptRadarHook D3 hook. Supports audience toggle to overlay
  different weight profiles, and an item selector for claims/evidence.
  """
  use EvidenceGraphWeb, :live_view

  alias EvidenceGraph.Claims
  alias EvidenceGraph.Evidence
  alias EvidenceGraph.PromptScores

  @audience_types [:researcher, :policymaker, :skeptic, :activist, :affected_person, :journalist]

  @impl true
  def mount(%{"id" => investigation_id}, _session, socket) do
    claims = fetch_list(Claims, :list_claims, investigation_id)
    evidence = fetch_list(Evidence, :list_evidence, investigation_id)
    items = build_items(claims, evidence)

    # Select first item by default
    selected = List.first(items)

    {:ok,
     assign(socket,
       page_title: "PROMPT Scores",
       investigation_id: investigation_id,
       claims: claims,
       evidence: evidence,
       items: items,
       selected_item: selected,
       selected_audience: nil,
       audience_types: @audience_types
     )}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    send(self(), :push_radar)
    {:noreply, socket}
  end

  @impl true
  def handle_info(:push_radar, socket) do
    case socket.assigns.selected_item do
      nil ->
        {:noreply, socket}

      item ->
        scores = PromptScores.to_map(item.prompt_scores)
        {:noreply, push_event(socket, "radar_data", %{scores: scores, weights: nil, audience: nil})}
    end
  end

  @impl true
  def handle_event("select_item", %{"item-id" => item_id, "item-type" => item_type}, socket) do
    selected =
      Enum.find(socket.assigns.items, fn item ->
        item.id == item_id && to_string(item.type) == item_type
      end)

    socket =
      socket
      |> assign(selected_item: selected, selected_audience: nil)

    scores =
      if selected do
        PromptScores.to_map(selected.prompt_scores)
      else
        %{}
      end

    {:noreply, push_event(socket, "radar_data", %{scores: scores, weights: nil, audience: nil})}
  end

  def handle_event("select_audience", %{"audience" => audience}, socket) do
    audience_atom = String.to_existing_atom(audience)
    weights = PromptScores.audience_weights(audience_atom)

    socket = assign(socket, selected_audience: audience_atom)

    {:noreply,
     push_event(socket, "radar_overlay", %{
       weights: weights,
       audience: audience,
       color: audience_color(audience_atom)
     })}
  end

  def handle_event("clear_audience", _params, socket) do
    # Re-render radar without overlay
    socket = assign(socket, selected_audience: nil)

    case socket.assigns.selected_item do
      nil ->
        {:noreply, socket}

      item ->
        scores = PromptScores.to_map(item.prompt_scores)
        {:noreply, push_event(socket, "radar_data", %{scores: scores, weights: nil, audience: nil})}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-4">
      <.header>
        PROMPT Scores: {@investigation_id}
        <:subtitle>
          Epistemological scoring across 6 dimensions
        </:subtitle>
        <:actions>
          <.link navigate={~p"/investigations/#{@investigation_id}/graph"}>
            <.button>Graph</.button>
          </.link>
        </:actions>
      </.header>

      <div class="grid grid-cols-12 gap-6">
        <%!-- Left panel: item selector --%>
        <div class="col-span-12 lg:col-span-4 space-y-3">
          <h3 class="text-sm font-semibold text-gray-700 dark:text-gray-300">Select Item</h3>

          <div class="space-y-2 max-h-96 overflow-y-auto">
            <button
              :for={item <- @items}
              phx-click="select_item"
              phx-value-item-id={item.id}
              phx-value-item-type={item.type}
              class={[
                "w-full text-left p-2 rounded-lg border text-sm transition-colors",
                if(@selected_item && @selected_item.id == item.id,
                  do: "border-blue-500 bg-blue-50 dark:bg-blue-950",
                  else: "border-gray-200 dark:border-gray-700 hover:bg-gray-50 dark:hover:bg-gray-900"
                )
              ]}
            >
              <div class="flex items-center gap-2">
                <span class={[
                  "w-2 h-2 rounded-full flex-shrink-0",
                  if(item.type == :claim, do: "bg-claim-500", else: "bg-evidence-500")
                ]} />
                <span class="truncate">{item.label}</span>
              </div>
              <span class="text-xs text-gray-500 capitalize ml-4">{item.type}</span>
            </button>
          </div>

          <%!-- Audience toggles --%>
          <div class="pt-4 border-t border-gray-200 dark:border-gray-700 space-y-2">
            <h3 class="text-sm font-semibold text-gray-700 dark:text-gray-300">
              Audience Weights
            </h3>
            <button
              :for={audience <- @audience_types}
              phx-click="select_audience"
              phx-value-audience={audience}
              class="block w-full text-left"
            >
              <.audience_badge type={audience} active={@selected_audience == audience} />
            </button>
            <button
              :if={@selected_audience}
              phx-click="clear_audience"
              class="text-xs text-gray-500 hover:text-gray-700 mt-1"
            >
              Clear overlay
            </button>
          </div>
        </div>

        <%!-- Centre panel: radar chart --%>
        <div class="col-span-12 lg:col-span-5">
          <div
            id="prompt-radar"
            phx-hook="PromptRadarHook"
            phx-update="ignore"
            class="prompt-radar-container"
          >
          </div>
        </div>

        <%!-- Right panel: score details --%>
        <div class="col-span-12 lg:col-span-3">
          <div :if={@selected_item} class="space-y-3">
            <h3 class="text-sm font-semibold text-gray-700 dark:text-gray-300">Score Breakdown</h3>

            <div :if={@selected_item.type == :claim}>
              <.claim_card claim={find_claim(@claims, @selected_item.id)} />
            </div>
            <div :if={@selected_item.type == :evidence}>
              <.evidence_card evidence={find_evidence(@evidence, @selected_item.id)} />
            </div>

            <div :if={@selected_audience} class="mt-4 p-3 rounded-lg bg-gray-50 dark:bg-gray-900">
              <p class="text-xs text-gray-600 dark:text-gray-400">
                <span class="font-semibold capitalize">{@selected_audience}</span>
                weighted score:
                <span class="font-bold text-base ml-1">
                  {calculate_audience_score(@selected_item, @selected_audience)}
                </span>
              </p>
            </div>
          </div>
        </div>
      </div>

      <.back navigate={~p"/"}>Back to dashboard</.back>
    </div>
    """
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp build_items(claims, evidence) do
    claim_items =
      Enum.map(claims, fn c ->
        %{id: c.id, type: :claim, label: String.slice(c.text, 0, 60), prompt_scores: c.prompt_scores}
      end)

    evidence_items =
      Enum.map(evidence, fn e ->
        %{id: e.id, type: :evidence, label: e.title, prompt_scores: e.prompt_scores}
      end)

    claim_items ++ evidence_items
  end

  defp find_claim(claims, id), do: Enum.find(claims, &(&1.id == id))
  defp find_evidence(evidence, id), do: Enum.find(evidence, &(&1.id == id))

  defp calculate_audience_score(item, audience) do
    PromptScores.calculate_for_audience(item.prompt_scores, audience)
    |> Float.round(1)
  end

  defp audience_color(:researcher), do: "rgba(124, 58, 237, 0.15)"
  defp audience_color(:policymaker), do: "rgba(37, 99, 235, 0.15)"
  defp audience_color(:skeptic), do: "rgba(234, 88, 12, 0.15)"
  defp audience_color(:activist), do: "rgba(220, 38, 38, 0.15)"
  defp audience_color(:affected_person), do: "rgba(13, 148, 136, 0.15)"
  defp audience_color(:journalist), do: "rgba(22, 163, 74, 0.15)"

  defp fetch_list(module, function, investigation_id) do
    case apply(module, function, [investigation_id]) do
      {:ok, items} -> items
      _ -> []
    end
  end
end

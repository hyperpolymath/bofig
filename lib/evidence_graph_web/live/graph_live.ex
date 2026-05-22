# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
defmodule EvidenceGraphWeb.GraphLive do
  @moduledoc """
  D3.js force-directed graph LiveView.

  Builds graph data from claims, evidence, and relationships, then pushes
  it to the EvidenceGraphHook client-side hook via `push_event/3`.
  The D3 container uses `phx-update="ignore"` so LiveView does not
  interfere with D3's DOM ownership.

  Audience selector reweights PROMPT scores and updates node opacity.
  Node click reveals a detail panel.
  """
  use EvidenceGraphWeb, :live_view

  alias EvidenceGraph.Claims
  alias EvidenceGraph.Evidence
  alias EvidenceGraph.Relationships
  alias EvidenceGraph.PromptScores

  @audience_types [:researcher, :policymaker, :skeptic, :activist, :affected_person, :journalist]

  @impl true
  def mount(%{"id" => investigation_id}, _session, socket) do
    graph_data = build_graph_data(investigation_id)

    {:ok,
     assign(socket,
       page_title: "Evidence Graph",
       investigation_id: investigation_id,
       graph_data: graph_data,
       audience_types: @audience_types,
       selected_audience: nil,
       selected_node: nil
     )}
  end

  @impl true
  def handle_event("select_audience", %{"audience" => audience}, socket) do
    audience_atom = String.to_existing_atom(audience)
    investigation_id = socket.assigns.investigation_id

    # Recalculate PROMPT scores for this audience
    updated_nodes = reweight_nodes(investigation_id, audience_atom)

    socket =
      socket
      |> assign(selected_audience: audience_atom)
      |> push_event("update_audience", %{nodes: updated_nodes})

    {:noreply, socket}
  end

  def handle_event("clear_audience", _params, socket) do
    {:noreply,
     socket
     |> assign(selected_audience: nil)
     |> push_event("update_audience", %{nodes: socket.assigns.graph_data.nodes})}
  end

  def handle_event("node_clicked", %{"id" => node_id, "node_type" => node_type}, socket) do
    selected_node = fetch_node_detail(node_id, node_type)
    {:noreply, assign(socket, selected_node: selected_node)}
  end

  def handle_event("close_detail", _params, socket) do
    {:noreply, assign(socket, selected_node: nil)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-4">
      <.header>
        Evidence Graph: {@investigation_id}
        <:actions>
          <.link navigate={~p"/investigations/#{@investigation_id}"}>
            <.button>Details</.button>
          </.link>
        </:actions>
      </.header>

      <%!-- Three-panel layout: audience selector | graph | detail panel --%>
      <div class="grid grid-cols-12 gap-4" style="min-height: 600px;">
        <%!-- Left panel: audience selector --%>
        <div class="col-span-12 lg:col-span-2 space-y-2">
          <h3 class="text-sm font-semibold text-gray-700 dark:text-gray-300">Audience</h3>
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
            class="text-xs text-gray-500 hover:text-gray-700 mt-2"
          >
            Clear filter
          </button>
        </div>

        <%!-- Centre panel: D3 graph --%>
        <div class="col-span-12 lg:col-span-7">
          <div
            id="evidence-graph"
            phx-hook="EvidenceGraphHook"
            phx-update="ignore"
            class="evidence-graph-container"
          >
          </div>
        </div>

        <%!-- Right panel: node detail --%>
        <div class="col-span-12 lg:col-span-3">
          <div :if={@selected_node} class="space-y-3">
            <div class="flex items-center justify-between">
              <h3 class="text-sm font-semibold text-gray-700 dark:text-gray-300">Detail</h3>
              <button phx-click="close_detail" class="text-gray-400 hover:text-gray-600 text-xs">
                Close
              </button>
            </div>

            <div :if={@selected_node.type == :claim}>
              <.claim_card claim={@selected_node.entity} />
            </div>
            <div :if={@selected_node.type == :evidence}>
              <.evidence_card evidence={@selected_node.entity} />
            </div>
          </div>
          <p
            :if={!@selected_node}
            class="text-sm text-gray-500 dark:text-gray-400 italic"
          >
            Click a node to see details.
          </p>
        </div>
      </div>

      <.back navigate={~p"/"}>Back to dashboard</.back>
    </div>
    """
  end

  # Push graph data to the hook after the socket connects
  @impl true
  def handle_info(:push_graph, socket) do
    {:noreply, push_event(socket, "graph_data", socket.assigns.graph_data)}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    # Push graph data on initial mount and navigation
    send(self(), :push_graph)
    {:noreply, socket}
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp build_graph_data(investigation_id) do
    claims = fetch_list(Claims, :list_claims, investigation_id)
    evidence = fetch_list(Evidence, :list_evidence, investigation_id)

    claim_nodes =
      Enum.map(claims, fn c ->
        %{
          id: c.id,
          label: String.slice(c.text, 0, 60),
          nodeType: "claim",
          promptScore: PromptScores.calculate_overall(c.prompt_scores)
        }
      end)

    evidence_nodes =
      Enum.map(evidence, fn e ->
        %{
          id: e.id,
          label: e.title,
          nodeType: "evidence",
          promptScore: PromptScores.calculate_overall(e.prompt_scores)
        }
      end)

    nodes = claim_nodes ++ evidence_nodes

    # Collect relationships for all claims
    links =
      claims
      |> Enum.flat_map(fn claim ->
        case Relationships.get_node_relationships(claim.id, :claim) do
          {:ok, rels} ->
            Enum.map(rels, fn rel ->
              %{
                source: rel.from_id,
                target: rel.to_id,
                relationship: to_string(rel.relationship_type),
                weight: rel.weight
              }
            end)

          _ ->
            []
        end
      end)
      |> Enum.uniq_by(fn l -> {l.source, l.target} end)

    %{nodes: nodes, links: links}
  end

  defp reweight_nodes(investigation_id, audience_type) do
    claims = fetch_list(Claims, :list_claims, investigation_id)
    evidence = fetch_list(Evidence, :list_evidence, investigation_id)

    claim_nodes =
      Enum.map(claims, fn c ->
        %{
          id: c.id,
          promptScore: PromptScores.calculate_for_audience(c.prompt_scores, audience_type)
        }
      end)

    evidence_nodes =
      Enum.map(evidence, fn e ->
        %{
          id: e.id,
          promptScore: PromptScores.calculate_for_audience(e.prompt_scores, audience_type)
        }
      end)

    claim_nodes ++ evidence_nodes
  end

  defp fetch_node_detail(node_id, "claim") do
    case Claims.get_claim(node_id) do
      {:ok, claim} -> %{type: :claim, entity: claim}
      _ -> nil
    end
  end

  defp fetch_node_detail(node_id, "evidence") do
    case Evidence.get_evidence(node_id) do
      {:ok, evidence} -> %{type: :evidence, entity: evidence}
      _ -> nil
    end
  end

  defp fetch_list(module, function, investigation_id) do
    case apply(module, function, [investigation_id]) do
      {:ok, items} -> items
      _ -> []
    end
  end
end

# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
defmodule EvidenceGraphWeb.ContradictionsLive do
  @moduledoc """
  Contradiction Detection Dashboard LiveView.

  Displays a sortable, filterable table of contradictions within an investigation.
  Each row shows both conflicting claims side-by-side with their PROMPT scores
  and provides resolution controls (resolve, dismiss, escalate).
  """

  use EvidenceGraphWeb, :live_view

  alias EvidenceGraph.Contradictions
  alias EvidenceGraph.PromptScores

  @resolution_options [
    {"Confirmed", "confirmed"},
    {"Dismissed", "dismissed"},
    {"Partial", "partial"},
    {"Requires Investigation", "requires_investigation"}
  ]

  @impl true
  def mount(%{"id" => investigation_id}, _session, socket) do
    {:ok,
     socket
     |> assign(
       page_title: "Contradiction Dashboard",
       investigation_id: investigation_id,
       dashboard: nil,
       filter_entity: nil,
       filter_status: "all",
       expanded_id: nil,
       resolve_rationale: "",
       resolve_status: "confirmed",
       resolution_options: @resolution_options,
       loading: true
     )
     |> load_dashboard()}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  # ---------------------------------------------------------------------------
  # Events
  # ---------------------------------------------------------------------------

  @impl true
  def handle_event("filter_entity", %{"entity" => entity_id}, socket) do
    value = if entity_id == "", do: nil, else: entity_id

    {:noreply,
     socket
     |> assign(filter_entity: value)}
  end

  def handle_event("filter_status", %{"status" => status}, socket) do
    {:noreply,
     socket
     |> assign(filter_status: status)}
  end

  def handle_event("expand", %{"id" => id}, socket) do
    new_id = if socket.assigns.expanded_id == id, do: nil, else: id
    {:noreply, assign(socket, expanded_id: new_id, resolve_rationale: "", resolve_status: "confirmed")}
  end

  def handle_event("resolve", %{"id" => contradiction_id}, socket) do
    resolution = %{
      status: String.to_existing_atom(socket.assigns.resolve_status),
      rationale: socket.assigns.resolve_rationale,
      resolved_by: "current_user"
    }

    case Contradictions.resolve_contradiction(contradiction_id, resolution) do
      :ok ->
        {:noreply,
         socket
         |> put_flash(:info, "Contradiction resolved.")
         |> assign(expanded_id: nil)
         |> load_dashboard()}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to resolve: #{inspect(reason)}")}
    end
  end

  def handle_event("set_resolve_status", %{"status" => status}, socket) do
    {:noreply, assign(socket, resolve_status: status)}
  end

  def handle_event("set_rationale", %{"rationale" => rationale}, socket) do
    {:noreply, assign(socket, resolve_rationale: rationale)}
  end

  # ---------------------------------------------------------------------------
  # Render
  # ---------------------------------------------------------------------------

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <.header>
        Contradiction Dashboard: {@investigation_id}
        <:actions>
          <.link navigate={~p"/investigations/#{@investigation_id}"}>
            <.button>Back to Investigation</.button>
          </.link>
        </:actions>
      </.header>

      <%= if @loading do %>
        <p class="text-gray-500 animate-pulse">Loading contradiction data...</p>
      <% else %>
        <%!-- Stats header --%>
        <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
          <.stat_card label="Total" value={@dashboard.total} colour="blue" />
          <.stat_card label="Unresolved" value={@dashboard.unresolved} colour="red" />
          <.stat_card label="Resolved" value={@dashboard.resolved} colour="green" />
          <.stat_card label="Explicit" value={Map.get(@dashboard.by_type, :explicit, 0)} colour="purple" />
        </div>

        <%!-- By-entity breakdown --%>
        <%= if length(@dashboard.by_entity) > 0 do %>
          <div class="bg-gray-50 dark:bg-gray-800 rounded p-4">
            <h3 class="font-semibold text-sm text-gray-600 dark:text-gray-400 mb-2">By Entity</h3>
            <div class="flex flex-wrap gap-2">
              <span
                :for={ent <- @dashboard.by_entity}
                class="px-2 py-1 text-xs rounded bg-gray-200 dark:bg-gray-700"
              >
                {ent.entity_name}: {ent.count}
              </span>
            </div>
          </div>
        <% end %>

        <%!-- Filters --%>
        <div class="flex flex-wrap gap-4 items-end">
          <div>
            <label class="block text-xs font-medium text-gray-600 dark:text-gray-400 mb-1">
              Filter by entity
            </label>
            <form phx-change="filter_entity">
              <input
                type="text"
                name="entity"
                value={@filter_entity || ""}
                placeholder="Entity ID..."
                class="px-2 py-1 text-sm border rounded dark:bg-gray-800 dark:border-gray-600"
              />
            </form>
          </div>
          <div>
            <label class="block text-xs font-medium text-gray-600 dark:text-gray-400 mb-1">
              Resolution status
            </label>
            <form phx-change="filter_status">
              <select name="status" class="px-2 py-1 text-sm border rounded dark:bg-gray-800 dark:border-gray-600">
                <option value="all" selected={@filter_status == "all"}>All</option>
                <option value="unresolved" selected={@filter_status == "unresolved"}>Unresolved</option>
                <option value="resolved" selected={@filter_status == "resolved"}>Resolved</option>
              </select>
            </form>
          </div>
        </div>

        <%!-- Contradictions table --%>
        <div class="space-y-2">
          <%= for c <- filtered_contradictions(assigns) do %>
            <div class="border rounded dark:border-gray-700 overflow-hidden">
              <%!-- Row summary --%>
              <div
                class="flex items-center justify-between px-4 py-3 cursor-pointer hover:bg-gray-50 dark:hover:bg-gray-800"
                phx-click="expand"
                phx-value-id={c.id}
              >
                <div class="flex-1">
                  <span class={[
                    "inline-block px-2 py-0.5 text-xs rounded mr-2",
                    severity_class(c.severity)
                  ]}>
                    {severity_label(c.severity)}
                  </span>
                  <span class={[
                    "inline-block px-2 py-0.5 text-xs rounded mr-2",
                    if(c.type == :explicit, do: "bg-purple-100 text-purple-800 dark:bg-purple-900 dark:text-purple-200", else: "bg-yellow-100 text-yellow-800 dark:bg-yellow-900 dark:text-yellow-200")
                  ]}>
                    {c.type}
                  </span>
                  <span class="text-sm text-gray-700 dark:text-gray-300">
                    {String.slice(c.claim_a.text, 0, 60)}...
                  </span>
                </div>
                <div class="flex items-center gap-2">
                  <%= if c.resolved do %>
                    <span class="text-xs text-green-600 dark:text-green-400">Resolved</span>
                  <% else %>
                    <span class="text-xs text-red-600 dark:text-red-400">Unresolved</span>
                  <% end %>
                  <span class="text-gray-400">{if @expanded_id == c.id, do: "▲", else: "▼"}</span>
                </div>
              </div>

              <%!-- Expanded detail --%>
              <%= if @expanded_id == c.id do %>
                <div class="border-t dark:border-gray-700 px-4 py-4 space-y-4 bg-gray-50 dark:bg-gray-900">
                  <%!-- Side-by-side claims --%>
                  <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                    <.contradiction_claim_card claim={c.claim_a} label="Claim A" />
                    <.contradiction_claim_card claim={c.claim_b} label="Claim B" />
                  </div>

                  <%!-- Resolution controls --%>
                  <%= unless c.resolved do %>
                    <div class="border-t dark:border-gray-700 pt-4 space-y-3">
                      <h4 class="text-sm font-semibold text-gray-600 dark:text-gray-400">Resolve</h4>
                      <div class="flex flex-wrap gap-2">
                        <button
                          :for={{label, value} <- @resolution_options}
                          phx-click="set_resolve_status"
                          phx-value-status={value}
                          class={[
                            "px-3 py-1 text-sm rounded",
                            if(@resolve_status == value,
                              do: "bg-blue-600 text-white",
                              else: "bg-gray-200 dark:bg-gray-700 text-gray-700 dark:text-gray-300"
                            )
                          ]}
                        >
                          {label}
                        </button>
                      </div>
                      <form phx-change="set_rationale">
                        <textarea
                          name="rationale"
                          rows="2"
                          placeholder="Rationale for resolution..."
                          class="w-full px-3 py-2 text-sm border rounded dark:bg-gray-800 dark:border-gray-600"
                        >{@resolve_rationale}</textarea>
                      </form>
                      <button
                        phx-click="resolve"
                        phx-value-id={c.id}
                        class="px-4 py-2 text-sm bg-green-600 text-white rounded hover:bg-green-700"
                      >
                        Resolve Contradiction
                      </button>
                    </div>
                  <% else %>
                    <div class="border-t dark:border-gray-700 pt-4">
                      <p class="text-sm text-green-600 dark:text-green-400">
                        Resolved as <strong>{c.resolution["status"]}</strong>
                        <%= if c.resolution["rationale"] && c.resolution["rationale"] != "" do %>
                          &mdash; {c.resolution["rationale"]}
                        <% end %>
                      </p>
                    </div>
                  <% end %>
                </div>
              <% end %>
            </div>
          <% end %>

          <%= if length(filtered_contradictions(assigns)) == 0 do %>
            <p class="text-gray-500 text-center py-8">No contradictions found matching your filters.</p>
          <% end %>
        </div>
      <% end %>

      <.back navigate={~p"/investigations/#{@investigation_id}"}>Back to investigation</.back>
    </div>
    """
  end

  # ---------------------------------------------------------------------------
  # Components
  # ---------------------------------------------------------------------------

  defp stat_card(assigns) do
    ~H"""
    <div class={"rounded-lg p-4 bg-#{@colour}-50 dark:bg-#{@colour}-900/20 border border-#{@colour}-200 dark:border-#{@colour}-800"}>
      <p class={"text-2xl font-bold text-#{@colour}-600 dark:text-#{@colour}-400"}>{@value}</p>
      <p class="text-xs text-gray-600 dark:text-gray-400">{@label}</p>
    </div>
    """
  end

  defp contradiction_claim_card(assigns) do
    ~H"""
    <div class="border rounded p-3 dark:border-gray-700 bg-white dark:bg-gray-800">
      <p class="text-xs font-semibold text-gray-500 dark:text-gray-400 mb-1">{@label}</p>
      <p class="text-sm text-gray-800 dark:text-gray-200 mb-2">{@claim.text}</p>
      <div class="flex gap-2 text-xs text-gray-500 dark:text-gray-400">
        <span>Type: {to_string(@claim.claim_type)}</span>
        <span>|</span>
        <span>PROMPT: {Float.round(PromptScores.calculate_overall(@claim.prompt_scores), 1)}</span>
        <span>|</span>
        <span>Confidence: {Float.round(@claim.confidence_level * 100, 0)}%</span>
      </div>
    </div>
    """
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp load_dashboard(socket) do
    case Contradictions.contradiction_dashboard_data(socket.assigns.investigation_id) do
      {:ok, dashboard} ->
        assign(socket, dashboard: dashboard, loading: false)

      {:error, _reason} ->
        socket
        |> put_flash(:error, "Failed to load contradiction data.")
        |> assign(
          dashboard: %{
            total: 0,
            unresolved: 0,
            resolved: 0,
            by_type: %{explicit: 0, same_entity_opposing: 0},
            by_entity: [],
            most_contradicted: [],
            contradictions: []
          },
          loading: false
        )
    end
  end

  defp filtered_contradictions(assigns) do
    contradictions = (assigns.dashboard && assigns.dashboard.contradictions) || []

    contradictions
    |> maybe_filter_by_entity(assigns.filter_entity)
    |> maybe_filter_by_status(assigns.filter_status)
  end

  defp maybe_filter_by_entity(contradictions, nil), do: contradictions

  defp maybe_filter_by_entity(contradictions, entity_id) do
    Enum.filter(contradictions, fn c ->
      c.claim_a.created_by == entity_id or c.claim_b.created_by == entity_id
    end)
  end

  defp maybe_filter_by_status(contradictions, "all"), do: contradictions

  defp maybe_filter_by_status(contradictions, "unresolved") do
    Enum.filter(contradictions, &(!&1.resolved))
  end

  defp maybe_filter_by_status(contradictions, "resolved") do
    Enum.filter(contradictions, & &1.resolved)
  end

  defp maybe_filter_by_status(contradictions, _), do: contradictions

  defp severity_class(severity) when severity >= 0.7, do: "bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-200"
  defp severity_class(severity) when severity >= 0.4, do: "bg-yellow-100 text-yellow-800 dark:bg-yellow-900 dark:text-yellow-200"
  defp severity_class(_), do: "bg-gray-100 text-gray-800 dark:bg-gray-900 dark:text-gray-200"

  defp severity_label(severity) when severity >= 0.7, do: "High"
  defp severity_label(severity) when severity >= 0.4, do: "Medium"
  defp severity_label(_), do: "Low"
end

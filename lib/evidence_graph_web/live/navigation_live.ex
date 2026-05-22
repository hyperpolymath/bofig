# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
defmodule EvidenceGraphWeb.NavigationLive do
  @moduledoc """
  Audience navigation path LiveView.

  Implements the "boundary objects" concept — different audiences navigate
  the same evidence in different ways. Uses `Navigation.auto_generate_path/2`
  and `get_path_with_nodes/1` to provide step-by-step navigation through
  claims and evidence, weighted by audience type.
  """
  use EvidenceGraphWeb, :live_view

  alias EvidenceGraph.Navigation
  alias EvidenceGraph.PromptScores

  @audience_types [:researcher, :policymaker, :skeptic, :activist, :affected_person, :journalist]

  @impl true
  def mount(%{"id" => investigation_id} = params, _session, socket) do
    audience =
      case Map.get(params, "audience") do
        nil -> :researcher
        a -> String.to_existing_atom(a)
      end

    {:ok,
     assign(socket,
       page_title: "Navigate: #{audience}",
       investigation_id: investigation_id,
       audience_types: @audience_types,
       selected_audience: audience,
       path_data: nil,
       current_step: 0,
       loading: true
     )}
  end

  @impl true
  def handle_params(%{"audience" => audience} = _params, _uri, socket) do
    audience_atom = String.to_existing_atom(audience)

    socket =
      socket
      |> assign(selected_audience: audience_atom, loading: true, current_step: 0)
      |> load_path()

    {:noreply, socket}
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, load_path(socket)}
  end

  @impl true
  def handle_event("next_step", _params, socket) do
    max_step = length(socket.assigns.path_data.nodes) - 1
    new_step = min(socket.assigns.current_step + 1, max_step)
    {:noreply, assign(socket, current_step: new_step)}
  end

  def handle_event("prev_step", _params, socket) do
    new_step = max(socket.assigns.current_step - 1, 0)
    {:noreply, assign(socket, current_step: new_step)}
  end

  def handle_event("go_to_step", %{"step" => step}, socket) do
    {:noreply, assign(socket, current_step: String.to_integer(step))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <.header>
        Navigation: {@investigation_id}
        <:subtitle>
          Audience-weighted path through the evidence
        </:subtitle>
      </.header>

      <%!-- Audience tabs --%>
      <div class="flex flex-wrap gap-2">
        <.link
          :for={audience <- @audience_types}
          patch={~p"/investigations/#{@investigation_id}/navigate/#{audience}"}
        >
          <.audience_badge type={audience} active={@selected_audience == audience} />
        </.link>
      </div>

      <div :if={@loading} class="text-center py-12">
        <p class="text-gray-500 dark:text-gray-400">Loading navigation path...</p>
      </div>

      <div :if={!@loading && @path_data} class="space-y-6">
        <%!-- Progress indicator --%>
        <div class="flex items-center gap-2">
          <span class="text-sm text-gray-600 dark:text-gray-400">
            Step {@current_step + 1} of {length(@path_data.nodes)}
          </span>
          <div class="flex-1 bg-gray-200 dark:bg-gray-700 rounded-full h-2">
            <div
              class="bg-blue-500 h-2 rounded-full transition-all duration-300"
              style={"width: #{progress_percent(@current_step, length(@path_data.nodes))}%"}
            >
            </div>
          </div>
        </div>

        <%!-- Step dots --%>
        <div class="flex flex-wrap gap-1">
          <button
            :for={{_node, idx} <- Enum.with_index(@path_data.nodes)}
            phx-click="go_to_step"
            phx-value-step={idx}
            class={[
              "navigation-step-dot",
              cond do
                idx == @current_step -> "active"
                idx < @current_step -> "completed"
                true -> "pending"
              end
            ]}
          />
        </div>

        <%!-- Current node display --%>
        <div :if={current_node = Enum.at(@path_data.nodes, @current_step)} class="space-y-4">
          <div :if={current_node.context} class="text-sm text-gray-600 dark:text-gray-400 italic">
            {current_node.context}
          </div>

          <div :if={match?({:claim, _}, current_node.entity)}>
            <.claim_card claim={elem(current_node.entity, 1)} />
          </div>

          <div :if={match?({:evidence, _}, current_node.entity)}>
            <.evidence_card evidence={elem(current_node.entity, 1)} />
          </div>

          <%!-- PROMPT scores for current node --%>
          <div class="p-4 bg-gray-50 dark:bg-gray-900 rounded-lg">
            <h4 class="text-xs font-semibold uppercase text-gray-500 mb-2 tracking-wider">
              PROMPT Scores
              <span class="normal-case font-normal">
                ({@selected_audience} weights)
              </span>
            </h4>
            <div class="flex flex-wrap gap-1">
              <%= for {dim, _weight} <- PromptScores.audience_weights(@selected_audience) do %>
                <.prompt_badge
                  dimension={to_string(dim)}
                  score={get_score(current_node.entity, dim)}
                />
              <% end %>
            </div>
          </div>
        </div>

        <%!-- Navigation buttons --%>
        <div class="flex items-center justify-between pt-4 border-t border-gray-200 dark:border-gray-700">
          <button
            phx-click="prev_step"
            disabled={@current_step == 0}
            class={[
              "px-4 py-2 text-sm font-medium rounded-lg",
              if(@current_step == 0,
                do: "text-gray-400 cursor-not-allowed",
                else: "text-gray-700 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-800"
              )
            ]}
          >
            Previous
          </button>

          <button
            phx-click="next_step"
            disabled={@current_step >= length(@path_data.nodes) - 1}
            class={[
              "px-4 py-2 text-sm font-medium rounded-lg",
              if(@current_step >= length(@path_data.nodes) - 1,
                do: "text-gray-400 cursor-not-allowed",
                else: "text-white bg-blue-600 hover:bg-blue-700"
              )
            ]}
          >
            Next
          </button>
        </div>
      </div>

      <div :if={!@loading && !@path_data} class="text-center py-12">
        <p class="text-gray-500 dark:text-gray-400">
          No navigation path available for this investigation.
        </p>
      </div>

      <.back navigate={~p"/"}>Back to dashboard</.back>
    </div>
    """
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp load_path(socket) do
    investigation_id = socket.assigns.investigation_id
    audience = socket.assigns.selected_audience

    # Try to find an existing path, or auto-generate one
    path_data =
      case Navigation.list_paths(investigation_id, audience_type: audience) do
        {:ok, [path | _]} ->
          case Navigation.get_path_with_nodes(path.id) do
            {:ok, data} -> data
            _ -> nil
          end

        {:ok, []} ->
          case Navigation.auto_generate_path(investigation_id, audience) do
            {:ok, path} ->
              case Navigation.get_path_with_nodes(path.id) do
                {:ok, data} -> data
                _ -> nil
              end

            _ ->
              nil
          end

        _ ->
          nil
      end

    assign(socket, path_data: path_data, loading: false)
  end

  defp progress_percent(current, total) when total > 0 do
    Float.round((current + 1) / total * 100, 0)
  end

  defp progress_percent(_, _), do: 0

  defp get_score({:claim, claim}, dimension) do
    Map.get(claim.prompt_scores, dimension, 0)
  end

  defp get_score({:evidence, evidence}, dimension) do
    Map.get(evidence.prompt_scores, dimension, 0)
  end

  defp get_score(_, _), do: 0
end

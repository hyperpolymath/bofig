# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
defmodule EvidenceGraphWeb.InvestigationLive.Show do
  @moduledoc """
  Investigation detail LiveView — shows claims with expandable
  supporting and contradicting evidence.
  """
  use EvidenceGraphWeb, :live_view

  alias EvidenceGraph.Claims
  alias EvidenceGraph.Evidence

  @impl true
  def mount(%{"id" => investigation_id}, _session, socket) do
    claims = fetch_claims(investigation_id)

    claims_with_evidence =
      Enum.map(claims, fn claim ->
        supporting = fetch_supporting(claim.id)
        contradicting = fetch_contradicting(claim.id)

        %{
          claim: claim,
          supporting: supporting,
          contradicting: contradicting,
          expanded: false
        }
      end)

    evidence = fetch_evidence(investigation_id)

    {:ok,
     assign(socket,
       page_title: "Investigation: #{investigation_id}",
       investigation_id: investigation_id,
       claims_with_evidence: claims_with_evidence,
       evidence: evidence
     )}
  end

  @impl true
  def handle_event("toggle_claim", %{"claim-id" => claim_id}, socket) do
    claims_with_evidence =
      Enum.map(socket.assigns.claims_with_evidence, fn entry ->
        if entry.claim.id == claim_id do
          %{entry | expanded: !entry.expanded}
        else
          entry
        end
      end)

    {:noreply, assign(socket, claims_with_evidence: claims_with_evidence)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <.header>
        {@investigation_id}
        <:subtitle>Detailed view of claims and supporting evidence</:subtitle>
        <:actions>
          <div class="flex gap-2">
            <.link navigate={~p"/investigations/#{@investigation_id}/graph"}>
              <.button>Graph</.button>
            </.link>
            <.link navigate={~p"/investigations/#{@investigation_id}/prompt"}>
              <.button>PROMPT</.button>
            </.link>
          </div>
        </:actions>
      </.header>

      <div class="space-y-4">
        <div :for={entry <- @claims_with_evidence} class="border border-gray-200 dark:border-gray-700 rounded-lg overflow-hidden">
          <%!-- Claim header (clickable to expand) --%>
          <button
            phx-click="toggle_claim"
            phx-value-claim-id={entry.claim.id}
            class="w-full text-left"
          >
            <.claim_card claim={entry.claim} class="rounded-none border-0" />
          </button>

          <%!-- Expandable evidence section --%>
          <div :if={entry.expanded} class="border-t border-gray-200 dark:border-gray-700 px-4 py-3 space-y-3">
            <%!-- Supporting evidence --%>
            <div :if={entry.supporting != []} class="space-y-2">
              <h4 class="text-xs font-semibold uppercase text-green-600 dark:text-green-400 tracking-wider">
                Supporting Evidence ({length(entry.supporting)})
              </h4>
              <div :for={item <- entry.supporting} class="ml-2">
                <.evidence_card evidence={item.evidence} />
                <.relationship_indicator
                  type={:supports}
                  weight={item.weight}
                  confidence={item.confidence}
                  class="mt-1"
                />
              </div>
            </div>

            <%!-- Contradicting evidence --%>
            <div :if={entry.contradicting != []} class="space-y-2">
              <h4 class="text-xs font-semibold uppercase text-red-600 dark:text-red-400 tracking-wider">
                Contradicting Evidence ({length(entry.contradicting)})
              </h4>
              <div :for={item <- entry.contradicting} class="ml-2">
                <.evidence_card evidence={item.evidence} />
                <.relationship_indicator
                  type={:contradicts}
                  weight={item.weight}
                  confidence={item.confidence}
                  class="mt-1"
                />
              </div>
            </div>

            <p
              :if={entry.supporting == [] && entry.contradicting == []}
              class="text-sm text-gray-500 italic"
            >
              No linked evidence yet.
            </p>
          </div>
        </div>
      </div>

      <.back navigate={~p"/"}>Back to dashboard</.back>
    </div>
    """
  end

  defp fetch_claims(investigation_id) do
    case Claims.list_claims(investigation_id) do
      {:ok, claims} -> claims
      _ -> []
    end
  end

  defp fetch_evidence(investigation_id) do
    case Evidence.list_evidence(investigation_id) do
      {:ok, evidence} -> evidence
      _ -> []
    end
  end

  defp fetch_supporting(claim_id) do
    case Claims.get_supporting_evidence(claim_id) do
      {:ok, evidence} -> evidence
      _ -> []
    end
  end

  defp fetch_contradicting(claim_id) do
    case Claims.get_contradicting_evidence(claim_id) do
      {:ok, evidence} -> evidence
      _ -> []
    end
  end
end

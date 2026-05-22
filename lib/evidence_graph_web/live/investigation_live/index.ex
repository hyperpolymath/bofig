# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
defmodule EvidenceGraphWeb.InvestigationLive.Index do
  @moduledoc """
  Dashboard LiveView — lists claims and evidence for an investigation.

  Renders a two-column grid of claim cards and evidence cards,
  with audience navigation badges linking to NavigationLive.
  """
  use EvidenceGraphWeb, :live_view

  alias EvidenceGraph.Claims
  alias EvidenceGraph.Evidence

  # Default investigation for the PoC test dataset
  @default_investigation "uk_inflation_2023"

  @audience_types [:researcher, :policymaker, :skeptic, :activist, :affected_person, :journalist]

  @impl true
  def mount(_params, _session, socket) do
    investigation_id = @default_investigation

    claims = fetch_claims(investigation_id)
    evidence = fetch_evidence(investigation_id)

    {:ok,
     assign(socket,
       page_title: "Dashboard",
       investigation_id: investigation_id,
       claims: claims,
       evidence: evidence,
       audience_types: @audience_types
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <.header>
        Investigation: {@investigation_id}
        <:subtitle>
          {length(@claims)} claims · {length(@evidence)} evidence items
        </:subtitle>
        <:actions>
          <.link navigate={~p"/investigations/#{@investigation_id}/graph"}>
            <.button>View Graph</.button>
          </.link>
        </:actions>
      </.header>

      <%!-- Audience navigation badges --%>
      <div class="flex flex-wrap gap-2">
        <.link
          :for={audience <- @audience_types}
          navigate={~p"/investigations/#{@investigation_id}/navigate/#{audience}"}
        >
          <.audience_badge type={audience} />
        </.link>
      </div>

      <%!-- Two-column grid: Claims | Evidence --%>
      <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <%!-- Claims column --%>
        <div class="space-y-4">
          <h2 class="text-base font-semibold text-gray-900 dark:text-gray-100">
            Claims
          </h2>
          <div class="space-y-3">
            <.link
              :for={claim <- @claims}
              navigate={~p"/investigations/#{@investigation_id}"}
              class="block"
            >
              <.claim_card claim={claim} />
            </.link>
          </div>
        </div>

        <%!-- Evidence column --%>
        <div class="space-y-4">
          <h2 class="text-base font-semibold text-gray-900 dark:text-gray-100">
            Evidence
          </h2>
          <div class="space-y-3">
            <.evidence_card :for={evidence <- @evidence} evidence={evidence} />
          </div>
        </div>
      </div>
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
end

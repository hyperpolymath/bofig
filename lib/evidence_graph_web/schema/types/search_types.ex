# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
defmodule EvidenceGraphWeb.Schema.Types.SearchTypes do
  @moduledoc """
  Absinthe type definitions for the unified Search module.
  """

  use Absinthe.Schema.Notation

  @desc "Unified search results across all collections"
  object :search_results do
    field :evidence, list_of(:search_evidence_result)
    field :claims, list_of(:search_claim_result)
    field :entities, list_of(:search_entity_result)
  end

  @desc "A search result from the evidence collection"
  object :search_evidence_result do
    field :item, :evidence
    field :score, :float
    field :highlight, :string
  end

  @desc "A search result from the claims collection"
  object :search_claim_result do
    field :item, :claim
    field :score, :float
    field :highlight, :string
  end

  @desc "A search result from the entities collection"
  object :search_entity_result do
    field :item, :entity
    field :score, :float
    field :highlight, :string
  end
end

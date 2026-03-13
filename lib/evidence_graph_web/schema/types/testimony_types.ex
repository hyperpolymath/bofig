# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
defmodule EvidenceGraphWeb.Schema.Types.TestimonyTypes do
  @moduledoc """
  Absinthe type definitions for the Testimony analysis module.
  """

  use Absinthe.Schema.Notation

  @desc "Cross-reference result for a single witness claim"
  object :cross_reference_result do
    field :claim, non_null(:claim)
    field :corroborating, list_of(:claim)
    field :contradicting, list_of(:claim)
    field :consistency_score, non_null(:float)
  end

  @desc "Witness reliability assessment"
  object :witness_reliability do
    field :reliability, non_null(:float)
    field :self_contradictions, non_null(:integer)
    field :corroboration_rate, non_null(:float)
    field :total_claims, non_null(:integer)
  end

  @desc "Self-contradiction (impeachment) finding"
  object :impeachment_result do
    field :claim_a, non_null(:claim)
    field :claim_b, non_null(:claim)
    field :contradiction_type, non_null(:string)
  end

  @desc "Timeline entry for a witness's testimony"
  object :testimony_timeline_entry do
    field :claim, non_null(:claim)
    field :timestamp, :datetime
    field :has_contradiction, non_null(:boolean)
    field :has_corroboration, non_null(:boolean)
    field :contradiction_ids, list_of(:string)
    field :corroboration_ids, list_of(:string)
  end
end

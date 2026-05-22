# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
defmodule EvidenceGraphWeb.Schema.Types.ContradictionTypes do
  @moduledoc """
  Absinthe type definitions for the Contradictions module.
  """

  use Absinthe.Schema.Notation

  @desc "A detected contradiction between two claims"
  object :contradiction do
    field :id, non_null(:string)
    field :claim_a, non_null(:claim)
    field :claim_b, non_null(:claim)
    field :type, non_null(:string)
    field :severity, non_null(:float)
    field :detected_by, non_null(:string)
    field :resolved, non_null(:boolean)
    field :resolution, :json
  end

  @desc "Contradiction dashboard aggregate data"
  object :contradiction_dashboard do
    field :total, non_null(:integer)
    field :unresolved, non_null(:integer)
    field :resolved, non_null(:integer)
    field :contradictions, list_of(:contradiction)
  end

  input_object :resolve_contradiction_input do
    field :contradiction_id, non_null(:string)
    field :status, non_null(:string)
    field :rationale, :string
    field :resolved_by, :string
  end
end

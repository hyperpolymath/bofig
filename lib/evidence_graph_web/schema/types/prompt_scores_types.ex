# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
defmodule EvidenceGraphWeb.Schema.Types.PromptScoresTypes do
  use Absinthe.Schema.Notation

  @desc "PROMPT epistemological scoring (6 dimensions)"
  object :prompt_scores do
    field :provenance, :integer, description: "Source credibility (0-100)"
    field :replicability, :integer, description: "Can others verify? (0-100)"
    field :objective, :integer, description: "Clear operational definitions (0-100)"
    field :methodology, :integer, description: "Research quality (0-100)"
    field :publication, :integer, description: "Peer review quality (0-100)"
    field :transparency, :integer, description: "Open data/methods (0-100)"
    field :overall, :float, description: "Weighted average"
  end

  input_object :prompt_scores_input do
    field :provenance, :integer
    field :replicability, :integer
    field :objective, :integer
    field :methodology, :integer
    field :publication, :integer
    field :transparency, :integer
  end
end

# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
defmodule EvidenceGraphWeb.ErrorHTML do
  @moduledoc """
  HTML error pages for the Evidence Graph web interface.
  """
  use EvidenceGraphWeb, :html

  embed_templates "error_html/*"

  @doc """
  Fallback for any status code not covered by a template.
  """
  def render(template, _assigns) do
    Phoenix.Controller.status_message_from_template(template)
  end
end

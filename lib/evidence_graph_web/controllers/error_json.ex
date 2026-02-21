# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
defmodule EvidenceGraphWeb.ErrorJSON do
  @moduledoc """
  JSON error responses for the Evidence Graph API.
  """

  @doc """
  Renders a JSON error response.

  By default uses the status message from the template name.
  """
  def render(template, _assigns) do
    %{errors: %{detail: Phoenix.Controller.status_message_from_template(template)}}
  end
end

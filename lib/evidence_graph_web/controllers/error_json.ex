# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
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

# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
defmodule EvidenceGraphWeb.Layouts do
  @moduledoc """
  Layout components for the Evidence Graph web interface.

  Provides the root HTML shell and the application layout wrapper.
  """
  use EvidenceGraphWeb, :html

  @dev_routes Application.compile_env(:evidence_graph, :dev_routes, false)
  def dev_routes?, do: @dev_routes

  embed_templates "layouts/root*"

  attr :flash, :map, default: %{}
  attr :current_scope, :any, default: nil
  attr :inner_content, :any, default: nil
  slot :inner_block

  def app(assigns) do
    ~H"""
    <main class="mx-auto max-w-7xl px-4 py-6 sm:px-6 lg:px-8">
      <.flash_group flash={@flash} />
      <%= if @inner_content do %>
        {@inner_content}
      <% else %>
        {render_slot(@inner_block)}
      <% end %>
    </main>
    """
  end
end

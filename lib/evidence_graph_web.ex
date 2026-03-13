# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>

defmodule EvidenceGraphWeb do
  @moduledoc """
  The unified entrypoint for the EvidenceGraph web interface.

  This module leverages Elixir macros to provide a consistent development 
  environment across all web components (Controllers, LiveViews, HTML Helpers). 
  It ensures that all necessary modules are imported and aliased in a 
  single `use EvidenceGraphWeb, :type` call.

  DESIGN PATTERN: "Context-Aware Dispatch"
  - `:controller`: Standard RESTful endpoints.
  - `:live_view`: Real-time interactive components via Phoenix LiveView.
  - `:html`: Functional HTML components using HEEx templates.
  """

  # Defines the public directories served as static assets.
  def static_paths, do: ~w(assets fonts images .well-known favicon.ico robots.txt)

  def router do
    quote do
      use Phoenix.Router, helpers: false
      import Plug.Conn
      import Phoenix.Controller
      import Phoenix.LiveView.Router
    end
  end

  def controller do
    quote do
      use Phoenix.Controller,
        formats: [:html, :json],
        layouts: [html: EvidenceGraphWeb.Layouts]

      import Plug.Conn
      use Gettext, backend: EvidenceGraphWeb.Gettext
      unquote(verified_routes())
    end
  end

  def live_view do
    quote do
      use Phoenix.LiveView,
        layout: {EvidenceGraphWeb.Layouts, :app}
      unquote(html_helpers())
    end
  end

  def html do
    quote do
      use Phoenix.Component
      unquote(html_helpers())
    end
  end

  def live_component do
    quote do
      use Phoenix.LiveComponent
      unquote(html_helpers())
    end
  end

  # SHARED HELPERS: Common functions available in all HTML-rendering contexts.
  defp html_helpers do
    quote do
      import Phoenix.HTML
      import Phoenix.HTML.Form
      import Plug.CSRFProtection, only: [get_csrf_token: 0, get_csrf_token_for: 1]
      import EvidenceGraphWeb.CoreComponents
      use Gettext, backend: EvidenceGraphWeb.Gettext
      alias Phoenix.LiveView.JS
      unquote(verified_routes())
    end
  end

  # COMPILE-TIME ROUTES: Enables the ~p sigil for type-safe URL generation.
  def verified_routes do
    quote do
      use Phoenix.VerifiedRoutes,
        endpoint: EvidenceGraphWeb.Endpoint,
        router: EvidenceGraphWeb.Router,
        statics: EvidenceGraphWeb.static_paths()
    end
  end

  @doc """
  DISPATCH MACRO: Routes the `use` call to the appropriate helper function.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end

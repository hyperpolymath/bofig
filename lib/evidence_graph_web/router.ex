# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
defmodule EvidenceGraphWeb.Router do
  use EvidenceGraphWeb, :router

  import EvidenceGraphWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {EvidenceGraphWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug Corsica, origins: ["http://localhost:4000", "http://localhost:3000"]
  end

  pipeline :public_api do
    plug :accepts, ["json"]
    plug Corsica, origins: "*"
    plug EvidenceGraphWeb.Plugs.ApiKeyAuth
  end

  scope "/", EvidenceGraphWeb do
    pipe_through [:browser, :require_authenticated_user]

    live "/", InvestigationLive.Index, :index
    live "/investigations/:id", InvestigationLive.Show, :show
    live "/investigations/:id/graph", GraphLive, :show
    live "/investigations/:id/prompt", PromptLive, :show
    live "/investigations/:id/timeline", TimelineLive, :show
    live "/investigations/:id/navigate", NavigationLive, :show
    live "/investigations/:id/navigate/:audience", NavigationLive, :audience
    live "/investigations/:id/contradictions", ContradictionsLive, :show
  end

  # Health check endpoint (unauthenticated, used by container health checks)
  scope "/api" do
    pipe_through :api

    get "/health", EvidenceGraphWeb.HealthController, :index
  end

  scope "/api", EvidenceGraphWeb do
    pipe_through :api

    # Zotero evidence REST endpoints
    post "/evidence/import", EvidenceApiController, :import
    post "/evidence/batch-import", EvidenceApiController, :batch_import
    get "/evidence/:id/export", EvidenceApiController, :export
    get "/investigations/:id/sync-status", EvidenceApiController, :sync_status

    # Lithoglyph pipeline import
    post "/evidence/lithoglyph-import", EvidenceApiController, :lithoglyph_import
    get "/evidence/lithoglyph-import/status", EvidenceApiController, :lithoglyph_import_status
  end

  pipeline :graphql do
    plug :accepts, ["json"]
    plug Corsica, origins: ["http://localhost:4000", "http://localhost:3000"]
    plug :fetch_session
    plug EvidenceGraphWeb.Plugs.GraphQLContext
  end

  scope "/api" do
    pipe_through :graphql

    forward "/graphql", Absinthe.Plug,
      schema: EvidenceGraphWeb.Schema,
      json_codec: Jason

    if Mix.env() == :dev do
      forward "/graphiql", Absinthe.Plug.GraphiQL,
        schema: EvidenceGraphWeb.Schema,
        interface: :playground,
        json_codec: Jason
    end
  end

  # Public API: API key-authenticated export endpoints
  scope "/api/export", EvidenceGraphWeb do
    pipe_through :public_api

    get "/:investigation_id/zotero", ExportController, :zotero
    get "/:investigation_id/csv/:collection", ExportController, :csv
    get "/:investigation_id/iiif", ExportController, :iiif
    get "/:investigation_id/graphml", ExportController, :graphml
    get "/:investigation_id/json-ld", ExportController, :json_ld
  end

  # Enable LiveDashboard in development
  if Application.compile_env(:evidence_graph, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: EvidenceGraphWeb.Telemetry
    end
  end

  ## Authentication routes

  scope "/", EvidenceGraphWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    get "/users/register", UserRegistrationController, :new
    post "/users/register", UserRegistrationController, :create
  end

  scope "/", EvidenceGraphWeb do
    pipe_through [:browser, :require_authenticated_user]

    get "/users/settings", UserSettingsController, :edit
    put "/users/settings", UserSettingsController, :update
    get "/users/settings/confirm-email/:token", UserSettingsController, :confirm_email
  end

  scope "/", EvidenceGraphWeb do
    pipe_through [:browser]

    get "/users/log-in", UserSessionController, :new
    get "/users/log-in/:token", UserSessionController, :confirm
    post "/users/log-in", UserSessionController, :create
    delete "/users/log-out", UserSessionController, :delete
  end
end

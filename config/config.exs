# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
import Config

config :evidence_graph, :scopes,
  user: [
    default: true,
    module: EvidenceGraph.Accounts.Scope,
    assign_key: :current_scope,
    access_path: [:user, :id],
    schema_key: :user_id,
    schema_type: :binary_id,
    schema_table: :users,
    test_data_fixture: EvidenceGraph.AccountsFixtures,
    test_setup_helper: :register_and_log_in_user
  ]

# General application configuration
config :evidence_graph,
  ecto_repos: [EvidenceGraph.Repo],
  generators: [timestamp_type: :utc_datetime]

# Configures the endpoint
config :evidence_graph, EvidenceGraphWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Phoenix.Endpoint.Cowboy2Adapter,
  render_errors: [
    formats: [html: EvidenceGraphWeb.ErrorHTML, json: EvidenceGraphWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: EvidenceGraph.PubSub,
  live_view: [signing_salt: "evidence_graph"]

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  default: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.3.2",
  default: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Silence Tesla soft-deprecation warning
config :tesla, disable_deprecated_builder_warning: true

# ArangoDB configuration (credentials set per-environment in dev.exs/test.exs/runtime.exs)
config :evidence_graph, EvidenceGraph.ArangoDB,
  client: Arangox.MintClient,
  endpoints: System.get_env("ARANGO_ENDPOINT") || "http://localhost:8529",
  database: System.get_env("ARANGO_DATABASE") || "evidence_graph"

# Zotero Web API v3 configuration
config :evidence_graph, EvidenceGraph.Zotero.Client,
  api_key: System.get_env("ZOTERO_API_KEY"),
  user_id: System.get_env("ZOTERO_USER_ID"),
  library_type: String.to_existing_atom(System.get_env("ZOTERO_LIBRARY_TYPE") || "user")

# Oban (background jobs) configuration
config :evidence_graph, Oban,
  repo: EvidenceGraph.Repo,
  queues: [sync: 10, default: 10],
  plugins: [
    {Oban.Plugins.Pruner, max_age: 60 * 60 * 24 * 7},
    {Oban.Plugins.Cron,
     crontab: [
       {"*/15 * * * *", EvidenceGraph.Workers.ZoteroSync}
     ]}
  ]

# Swoosh mailer configuration
config :evidence_graph, EvidenceGraph.Mailer, adapter: Swoosh.Adapters.Local

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"

import Config

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

# ArangoDB configuration
config :evidence_graph, EvidenceGraph.ArangoDB,
  endpoints: System.get_env("ARANGO_ENDPOINT") || "http://localhost:8529",
  database: System.get_env("ARANGO_DATABASE") || "evidence_graph",
  username: System.get_env("ARANGO_USERNAME") || "root",
  password: System.get_env("ARANGO_PASSWORD") || "dev"

# Oban (background jobs) configuration
config :evidence_graph, Oban,
  repo: EvidenceGraph.Repo,
  queues: [sync: 10, default: 10],
  plugins: [
    {Oban.Plugins.Pruner, max_age: 60 * 60 * 24 * 7},
    {Oban.Plugins.Cron,
     crontab: [
       # Sync Zotero every 15 minutes (Phase 2)
       # {"*/15 * * * *", EvidenceGraph.Workers.ZoteroSync}
     ]}
  ]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"

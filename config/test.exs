import Config

# Configure your database (Postgres for user auth only)
config :evidence_graph, EvidenceGraph.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "evidence_graph_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :evidence_graph, EvidenceGraphWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "test_secret_key_base_not_used_in_production",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Disable Oban during tests
config :evidence_graph, Oban, testing: :inline

# ArangoDB test settings
config :evidence_graph, EvidenceGraph.ArangoDB,
  endpoints: "http://localhost:8529",
  database: "evidence_graph_test#{System.get_env("MIX_TEST_PARTITION")}",
  username: "root",
  password: "dev",
  pool_size: 2

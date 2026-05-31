# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
import Config

test_secret_key_base =
  System.get_env("SECRET_KEY_BASE") ||
    String.duplicate("test_secret_key_base_", 4)

# Only in tests, remove the complexity from the password hashing algorithm
config :bcrypt_elixir, :log_rounds, 1

# Configure your database (Postgres for user auth only)
config :evidence_graph, EvidenceGraph.Repo,
  username: "postgres",
  password: System.get_env("POSTGRES_PASSWORD") || "postgres",
  hostname: "localhost",
  database: "evidence_graph_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :evidence_graph, EvidenceGraphWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: test_secret_key_base,
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Disable Oban during tests
config :evidence_graph, Oban, testing: :inline

# Disable Swoosh API client during tests
config :swoosh, :api_client, false

# Use test mailer adapter
config :evidence_graph, EvidenceGraph.Mailer, adapter: Swoosh.Adapters.Test

# ArangoDB test settings
config :evidence_graph, EvidenceGraph.ArangoDB,
  client: Arangox.MintClient,
  endpoints: "http://localhost:8529",
  database: "evidence_graph_test#{System.get_env("MIX_TEST_PARTITION")}",
  auth:
    {:basic, System.get_env("ARANGO_USERNAME") || "root",
     System.get_env("ARANGO_PASSWORD") || "dev"},
  pool_size: 2

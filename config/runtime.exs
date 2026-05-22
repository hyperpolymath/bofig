# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
import Config

# Runtime configuration (loads environment variables)
# This file is executed by releases and contains runtime configuration.

if config_env() == :prod do
  # ---------------------------------------------------------------------------
  # PostgreSQL (user authentication only)
  # ---------------------------------------------------------------------------
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  config :evidence_graph, EvidenceGraph.Repo,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    socket_options: maybe_ipv6

  # ---------------------------------------------------------------------------
  # Secret key base (must be at least 64 bytes)
  # Generate with: mix phx.gen.secret
  # ---------------------------------------------------------------------------
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  if byte_size(secret_key_base) < 64 do
    raise "SECRET_KEY_BASE must be at least 64 bytes. Current length: #{byte_size(secret_key_base)}"
  end

  # ---------------------------------------------------------------------------
  # Phoenix endpoint
  # ---------------------------------------------------------------------------
  host =
    System.get_env("PHX_HOST") ||
      raise """
      environment variable PHX_HOST is missing.
      Set it to your production domain, e.g. evidencegraph.org
      """

  port = String.to_integer(System.get_env("PORT") || "4000")

  config :evidence_graph, EvidenceGraphWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base,
    server: true

  # ---------------------------------------------------------------------------
  # ArangoDB (primary data store: documents + graph)
  # ---------------------------------------------------------------------------
  arango_username =
    System.get_env("ARANGO_USERNAME") ||
      raise("environment variable ARANGO_USERNAME is missing")

  arango_password =
    System.get_env("ARANGO_PASSWORD") ||
      raise("environment variable ARANGO_PASSWORD is missing")

  config :evidence_graph, EvidenceGraph.ArangoDB,
    client: Arangox.MintClient,
    endpoints:
      System.get_env("ARANGO_ENDPOINT") ||
        raise("environment variable ARANGO_ENDPOINT is missing"),
    database: System.get_env("ARANGO_DATABASE") || "evidence_graph",
    auth: {:basic, arango_username, arango_password},
    pool_size: String.to_integer(System.get_env("ARANGO_POOL_SIZE") || "10")

  # ---------------------------------------------------------------------------
  # Zotero Web API v3 (evidence import/sync)
  # ---------------------------------------------------------------------------
  if zotero_api_key = System.get_env("ZOTERO_API_KEY") do
    config :evidence_graph, EvidenceGraph.Zotero.Client,
      api_key: zotero_api_key,
      user_id: System.get_env("ZOTERO_USER_ID"),
      library_type:
        String.to_existing_atom(System.get_env("ZOTERO_LIBRARY_TYPE") || "user")
  end

  # ---------------------------------------------------------------------------
  # REST API authentication
  # ---------------------------------------------------------------------------
  if api_key = System.get_env("EVIDENCE_GRAPH_API_KEY") do
    config :evidence_graph, :api_key, api_key
  end

  # ---------------------------------------------------------------------------
  # Swoosh mailer (production email delivery)
  # ---------------------------------------------------------------------------
  # Default to Mailgun adapter; override MAILER_ADAPTER for others.
  # Set SWOOSH_API_CLIENT=false to disable outbound mail.
  if System.get_env("SWOOSH_API_CLIENT") != "false" do
    config :swoosh, :api_client, Swoosh.ApiClient.Finch

    config :evidence_graph, EvidenceGraph.Mailer,
      adapter: Swoosh.Adapters.Mailgun,
      api_key: System.get_env("MAILGUN_API_KEY"),
      domain: System.get_env("MAILGUN_DOMAIN")
  end

  # ---------------------------------------------------------------------------
  # Oban (background jobs) — production overrides
  # ---------------------------------------------------------------------------
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

  # ---------------------------------------------------------------------------
  # IPFS configuration (optional, Phase 2)
  # ---------------------------------------------------------------------------
  if ipfs_url = System.get_env("IPFS_API_URL") do
    config :evidence_graph, :ipfs_api_url, ipfs_url
  end
end

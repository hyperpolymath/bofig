import Config

# Runtime configuration (loads environment variables)
# This file is executed by releases and contains runtime configuration.

if config_env() == :prod do
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

  # The secret key base is used to sign/encrypt cookies and other secrets.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "evidencegraph.org"
  port = String.to_integer(System.get_env("PORT") || "4000")

  config :evidence_graph, EvidenceGraphWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base

  # ArangoDB production configuration
  config :evidence_graph, EvidenceGraph.ArangoDB,
    endpoints: System.get_env("ARANGO_ENDPOINT") ||
      raise("environment variable ARANGO_ENDPOINT is missing"),
    database: System.get_env("ARANGO_DATABASE") || "evidence_graph",
    username: System.get_env("ARANGO_USERNAME") ||
      raise("environment variable ARANGO_USERNAME is missing"),
    password: System.get_env("ARANGO_PASSWORD") ||
      raise("environment variable ARANGO_PASSWORD is missing"),
    pool_size: String.to_integer(System.get_env("ARANGO_POOL_SIZE") || "10")

  # IPFS configuration (optional, Phase 2)
  if System.get_env("IPFS_API_URL") do
    config :evidence_graph, :ipfs_api_url, System.get_env("IPFS_API_URL")
  end
end

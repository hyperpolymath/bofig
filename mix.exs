defmodule EvidenceGraph.MixProject do
  use Mix.Project

  def project do
    [
      app: :evidence_graph,
      version: "0.1.0",
      elixir: "~> 1.16",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {EvidenceGraph.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      # Phoenix Core
      {:phoenix, "~> 1.7.10"},
      {:phoenix_html, "~> 4.0"},
      {:phoenix_live_reload, "~> 1.4", only: :dev},
      {:phoenix_live_view, "~> 1.1.19"},
      {:phoenix_live_dashboard, "~> 0.8.3"},
      {:telemetry_metrics, "~> 0.6"},
      {:telemetry_poller, "~> 1.0"},

      # GraphQL
      {:absinthe, "~> 1.7"},
      {:absinthe_phoenix, "~> 2.0"},
      {:absinthe_plug, "~> 1.5"},
      {:dataloader, "~> 2.0"},

      # Database
      {:arangox, "~> 0.5.2"},
      {:ecto, "~> 3.11"},  # For changesets only, not SQL
      {:ecto_sql, "~> 3.11"},  # Minimal, for user auth only
      {:postgrex, ">= 0.0.0"},  # User auth storage only

      # Background Jobs
      {:oban, "~> 2.17"},

      # HTTP Clients
      {:tesla, "~> 1.8"},
      {:mint, "~> 1.5"},
      {:castore, "~> 1.0"},  # CA certificates
      {:jason, "~> 1.4"},

      # IPFS Integration (Phase 2)
      # {:ex_ipfs, "~> 0.1"},

      # Utilities
      {:floki, ">= 0.30.0", only: :test},
      {:esbuild, "~> 0.8", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.2", runtime: Mix.env() == :dev},
      {:gettext, "~> 1.0"},
      {:plug_cowboy, "~> 2.6"},
      {:corsica, "~> 2.1"},  # CORS for API

      # Development
      {:phoenix_copy, "~> 0.1.1", only: :dev},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["tailwind default", "esbuild default"],
      "assets.deploy": ["tailwind default --minify", "esbuild default --minify", "phx.digest"]
    ]
  end
end

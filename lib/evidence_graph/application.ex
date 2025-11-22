defmodule EvidenceGraph.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Telemetry supervisor
      EvidenceGraphWeb.Telemetry,
      # Start the Ecto repository (for user auth only)
      EvidenceGraph.Repo,
      # Start the PubSub system
      {Phoenix.PubSub, name: EvidenceGraph.PubSub},
      # Start ArangoDB connection pool
      {EvidenceGraph.ArangoDB, Application.get_env(:evidence_graph, EvidenceGraph.ArangoDB)},
      # Start Oban (background jobs)
      {Oban, Application.get_env(:evidence_graph, Oban)},
      # Start the Endpoint (http/https)
      EvidenceGraphWeb.Endpoint
      # Start a worker by calling: EvidenceGraph.Worker.start_link(arg)
      # {EvidenceGraph.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: EvidenceGraph.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    EvidenceGraphWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end

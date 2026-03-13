# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
defmodule Mix.Tasks.Arango.Reset do
  @moduledoc """
  Drops and recreates the ArangoDB database.

  ## Usage

      mix arango.reset

  This will drop the target database and then run `arango.setup`.
  """

  use Mix.Task

  @shortdoc "Drop and recreate ArangoDB database"

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.config")
    Application.ensure_all_started(:db_connection)
    Application.ensure_all_started(:mint)
    Application.ensure_all_started(:castore)
    Application.ensure_all_started(:jason)

    opts = Application.get_env(:evidence_graph, EvidenceGraph.ArangoDB)
    database = Keyword.get(opts, :database, "evidence_graph")

    Mix.shell().info("Dropping database '#{database}'...")

    # Connect to _system to drop the database
    username = extract_username(opts)
    password = extract_password(opts)
    auth = {:basic, username, password}

    system_opts =
      opts
      |> Keyword.drop([:database, :pool_size, :name, :username, :password])
      |> Keyword.put(:auth, auth)

    {:ok, conn} = Arangox.start_link(system_opts)

    case Arangox.request(conn, :delete, "/_api/database/#{database}") do
      {:ok, _req, %{status: status}} when status in [200, 201] ->
        Mix.shell().info("  Database dropped.")

      {:ok, _req, %{status: 404}} ->
        Mix.shell().info("  Database did not exist.")

      {:error, %{status: 404}} ->
        Mix.shell().info("  Database did not exist.")

      {:error, reason} ->
        Mix.shell().info("  Warning: #{inspect(reason)}")
    end

    GenServer.stop(conn)

    # Re-create
    Mix.Tasks.Arango.Setup.run(args)
  end

  defp extract_username(opts) do
    case Keyword.get(opts, :auth) do
      {:basic, username, _password} -> username
      _ -> Keyword.get(opts, :username, "root")
    end
  end

  defp extract_password(opts) do
    case Keyword.get(opts, :auth) do
      {:basic, _username, password} -> password
      _ -> Keyword.get(opts, :password, "")
    end
  end
end

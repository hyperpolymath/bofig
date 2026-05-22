# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
defmodule Mix.Tasks.Arango.Setup do
  @moduledoc """
  Creates the ArangoDB database, collections, and indexes.

  ## Usage

      mix arango.setup

  This task:
  1. Connects to the _system database
  2. Creates the target database (if it doesn't exist)
  3. Starts the application (connecting to the target database)
  4. Creates all required collections and indexes

  ## Configuration

  Reads ArangoDB settings from `config :evidence_graph, EvidenceGraph.ArangoDB`.
  """

  use Mix.Task

  @shortdoc "Set up ArangoDB database, collections, and indexes"

  @impl Mix.Task
  def run(_args) do
    # Ensure dependencies are started (SSL, HTTP clients, connection pool)
    Mix.Task.run("app.config")
    Application.ensure_all_started(:db_connection)
    Application.ensure_all_started(:mint)
    Application.ensure_all_started(:castore)
    Application.ensure_all_started(:jason)

    opts = Application.get_env(:evidence_graph, EvidenceGraph.ArangoDB)

    Mix.shell().info("Setting up ArangoDB...")
    Mix.shell().info("  Endpoint: #{Keyword.get(opts, :endpoints)}")
    Mix.shell().info("  Database: #{Keyword.get(opts, :database)}")

    # Step 1: Create the database via _system connection
    Mix.shell().info("\nCreating database...")

    case EvidenceGraph.ArangoDB.ensure_database(opts) do
      :ok ->
        Mix.shell().info("  Database ready.")

      {:error, reason} ->
        Mix.raise("Failed to create database: #{inspect(reason)}")
    end

    # Step 2: Start the application (pool connects to target database)
    Mix.shell().info("\nStarting application...")
    Mix.Task.run("app.start")

    # Step 3: Create collections and indexes
    Mix.shell().info("Creating collections and indexes...")

    case EvidenceGraph.ArangoDB.setup_database() do
      :ok ->
        Mix.shell().info("  Collections and indexes ready.")

      {:error, reason} ->
        Mix.raise("Failed to set up database: #{inspect(reason)}")
    end

    Mix.shell().info("\nArangoDB setup complete!")
  end
end

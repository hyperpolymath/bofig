# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
defmodule EvidenceGraphWeb.Plugs.ApiKeyAuth do
  @moduledoc """
  Plug for validating public API keys from the `X-API-Key` header.

  API keys are stored in the ArangoDB `api_keys` collection.  Each key
  has a set of scopes (`:read`, `:write`, `:admin`, `:export`) that
  control which endpoints the key can access.

  ## Rate Limiting

  Enforces a rate limit of 1000 requests per hour per API key, tracked
  via an ETS counter table.

  ## Usage in Router

      pipeline :public_api do
        plug :accepts, ["json"]
        plug EvidenceGraphWeb.Plugs.ApiKeyAuth
      end

  ## Scoped Access

  To require a specific scope, pass it as an option:

      plug EvidenceGraphWeb.Plugs.ApiKeyAuth, scope: :write
  """

  @behaviour Plug

  import Plug.Conn

  alias EvidenceGraph.ApiKeys

  @rate_limit 1000
  @rate_window_seconds 3600

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, opts) do
    required_scope = Keyword.get(opts, :scope)

    case get_req_header(conn, "x-api-key") do
      [key] ->
        validate_and_authorize(conn, key, required_scope)

      [] ->
        conn
        |> put_status(:unauthorized)
        |> Phoenix.Controller.json(%{errors: %{detail: "Missing X-API-Key header"}})
        |> halt()

      _ ->
        conn
        |> put_status(:bad_request)
        |> Phoenix.Controller.json(%{errors: %{detail: "Multiple X-API-Key headers not allowed"}})
        |> halt()
    end
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp validate_and_authorize(conn, key, required_scope) do
    case ApiKeys.validate_api_key(key) do
      {:ok, api_key_doc} ->
        # Check scope if required
        if required_scope && !has_scope?(api_key_doc, required_scope) do
          conn
          |> put_status(:forbidden)
          |> Phoenix.Controller.json(%{
            errors: %{detail: "Insufficient scope. Required: #{required_scope}"}
          })
          |> halt()
        else
          # Check rate limit
          case check_rate_limit(api_key_doc["_key"]) do
            :ok ->
              conn
              |> assign(:api_key, api_key_doc)
              |> assign(:api_key_user_id, api_key_doc["user_id"])

            :rate_limited ->
              conn
              |> put_status(:too_many_requests)
              |> put_resp_header("retry-after", to_string(@rate_window_seconds))
              |> Phoenix.Controller.json(%{
                errors: %{
                  detail: "Rate limit exceeded. Maximum #{@rate_limit} requests per hour."
                }
              })
              |> halt()
          end
        end

      {:error, :not_found} ->
        conn
        |> put_status(:unauthorized)
        |> Phoenix.Controller.json(%{errors: %{detail: "Invalid API key"}})
        |> halt()

      {:error, :revoked} ->
        conn
        |> put_status(:unauthorized)
        |> Phoenix.Controller.json(%{errors: %{detail: "API key has been revoked"}})
        |> halt()
    end
  end

  defp has_scope?(api_key_doc, required_scope) do
    scopes = api_key_doc["scopes"] || []
    scope_str = to_string(required_scope)
    scope_str in scopes or "admin" in scopes
  end

  defp check_rate_limit(api_key_id) do
    ensure_rate_limit_table()

    now = System.monotonic_time(:second)
    window_start = now - @rate_window_seconds

    # Clean expired entries and count current window
    case :ets.lookup(:bofig_rate_limits, api_key_id) do
      [{^api_key_id, timestamps}] ->
        # Filter to only timestamps within the current window
        valid_timestamps = Enum.filter(timestamps, &(&1 > window_start))

        if length(valid_timestamps) >= @rate_limit do
          :rate_limited
        else
          :ets.insert(:bofig_rate_limits, {api_key_id, [now | valid_timestamps]})
          :ok
        end

      [] ->
        :ets.insert(:bofig_rate_limits, {api_key_id, [now]})
        :ok
    end
  end

  defp ensure_rate_limit_table do
    case :ets.whereis(:bofig_rate_limits) do
      :undefined ->
        :ets.new(:bofig_rate_limits, [:named_table, :public, :set])

      _ref ->
        :ok
    end
  end
end

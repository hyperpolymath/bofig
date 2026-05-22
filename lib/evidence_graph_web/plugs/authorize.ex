# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
defmodule EvidenceGraphWeb.Plugs.Authorize do
  @moduledoc """
  Plug that checks RBAC access before investigation routes.

  Extracts the investigation ID from `conn.params["id"]` or
  `conn.params["investigation_id"]` and the current user from
  `conn.assigns.current_scope_for_user` (set by `UserAuth`).

  ## Usage in Router

      import EvidenceGraphWeb.Plugs.Authorize

      pipeline :authorized_investigation do
        plug :authorize_investigation, action: :view
      end

  Or for specific action checks per route:

      plug EvidenceGraphWeb.Plugs.Authorize, action: :edit

  ## Options

  - `:action` — The action to check (`:view`, `:edit`, `:delete`, `:manage`,
    `:export`, `:share`). Defaults to `:view`.
  """

  import Plug.Conn
  import Phoenix.Controller, only: [json: 2, put_flash: 3, redirect: 2]

  alias EvidenceGraph.Authorization

  @behaviour Plug

  @impl Plug
  def init(opts) do
    %{
      action: Keyword.get(opts, :action, :view)
    }
  end

  @impl Plug
  def call(conn, %{action: action}) do
    investigation_id =
      conn.params["id"] || conn.params["investigation_id"]

    user_scope = conn.assigns[:current_scope_for_user]

    cond do
      is_nil(investigation_id) ->
        # No investigation ID in route; skip authorization
        conn

      is_nil(user_scope) ->
        conn
        |> halt_unauthorized()

      true ->
        user_id = extract_user_id(user_scope)
        check_and_continue(conn, investigation_id, user_id, action)
    end
  end

  defp check_and_continue(conn, investigation_id, user_id, action) do
    case Authorization.check_access(investigation_id, user_id, action) do
      :ok ->
        assign(conn, :investigation_role, get_role(investigation_id, user_id))

      {:error, :forbidden} ->
        conn
        |> halt_forbidden()

      {:error, _reason} ->
        conn
        |> halt_unauthorized()
    end
  end

  defp get_role(investigation_id, user_id) do
    case Authorization.get_user_role(investigation_id, user_id) do
      {:ok, role} -> role
      _ -> nil
    end
  end

  defp extract_user_id(%{user: user}) when is_map(user) do
    Map.get(user, :id) || Map.get(user, "id")
  end

  defp extract_user_id(scope) when is_map(scope) do
    Map.get(scope, :id) || Map.get(scope, "id") || Map.get(scope, :user_id)
  end

  defp extract_user_id(_), do: nil

  defp halt_unauthorized(conn) do
    if is_api_request?(conn) do
      conn
      |> put_status(401)
      |> json(%{error: "unauthorized", message: "Authentication required"})
      |> halt()
    else
      conn
      |> put_flash(:error, "You must be logged in to access this page.")
      |> redirect(to: "/users/log-in")
      |> halt()
    end
  end

  defp halt_forbidden(conn) do
    if is_api_request?(conn) do
      conn
      |> put_status(403)
      |> json(%{error: "forbidden", message: "You do not have access to this investigation"})
      |> halt()
    else
      conn
      |> put_flash(:error, "You do not have permission to access this investigation.")
      |> redirect(to: "/")
      |> halt()
    end
  end

  defp is_api_request?(conn) do
    Enum.any?(get_req_header(conn, "accept"), &String.contains?(&1, "json")) or
      String.starts_with?(conn.request_path, "/api")
  end
end

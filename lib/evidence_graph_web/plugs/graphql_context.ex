# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
defmodule EvidenceGraphWeb.Plugs.GraphQLContext do
  @moduledoc """
  Plug that populates the Absinthe context with the authenticated user.

  Extracts the current user from the session (via `UserAuth.fetch_current_scope_for_user/2`)
  and places `current_user_id` into the Absinthe context so that resolvers can perform
  authorization checks.

  Also supports API key authentication: if the request was authenticated via
  `ApiKeyAuth`, the `api_key_user_id` assign is used instead.
  """

  @behaviour Plug

  import Plug.Conn

  alias EvidenceGraph.Accounts

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, _opts) do
    context = build_context(conn)
    Absinthe.Plug.put_options(conn, context: context)
  end

  defp build_context(conn) do
    # Priority 1: session-based auth (browser users)
    user_id = extract_session_user_id(conn)

    # Priority 2: API key auth (programmatic access)
    user_id = user_id || conn.assigns[:api_key_user_id]

    if user_id do
      %{current_user_id: to_string(user_id)}
    else
      %{}
    end
  end

  defp extract_session_user_id(conn) do
    with token when is_binary(token) <- get_session(conn, :user_token),
         {user, _inserted_at} <- Accounts.get_user_by_session_token(token) do
      user.id
    else
      _ -> nil
    end
  end
end

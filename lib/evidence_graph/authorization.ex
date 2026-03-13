# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
defmodule EvidenceGraph.Authorization do
  @moduledoc """
  Role-based access control (RBAC) for investigations.

  Roles: `:owner`, `:editor`, `:reviewer`, `:viewer`

  Each role grants a specific set of actions:

  | Role     | :view | :edit | :delete | :manage | :export | :share |
  |----------|-------|-------|---------|---------|---------|--------|
  | owner    |   Y   |   Y   |    Y    |    Y    |    Y    |    Y   |
  | editor   |   Y   |   Y   |    N    |    N    |    Y    |    Y   |
  | reviewer |   Y   |   N   |    N    |    N    |    Y    |    N   |
  | viewer   |   Y   |   N   |    N    |    N    |    N    |    N   |

  Access grants are stored in the `access_grants` ArangoDB collection.
  """

  alias EvidenceGraph.ArangoDB

  @roles ~w(owner editor reviewer viewer)a

  @role_permissions %{
    owner: MapSet.new([:view, :edit, :delete, :manage, :export, :share]),
    editor: MapSet.new([:view, :edit, :export, :share]),
    reviewer: MapSet.new([:view, :export]),
    viewer: MapSet.new([:view])
  }

  # ---------------------------------------------------------------------------
  # Grant / Revoke
  # ---------------------------------------------------------------------------

  @doc """
  Grant a role to a user for an investigation.

  If the user already has access, their role is updated.

  ## Examples

      iex> grant_access("inv_1", "user_42", :editor)
      {:ok, %{...}}
  """
  def grant_access(investigation_id, user_id, role) when role in @roles do
    now = DateTime.to_iso8601(DateTime.utc_now())

    # Upsert: update if exists, insert if not
    aql = """
    UPSERT {investigation_id: @investigation_id, user_id: @user_id}
    INSERT {
      _key: @key,
      investigation_id: @investigation_id,
      user_id: @user_id,
      role: @role,
      granted_at: @now,
      updated_at: @now
    }
    UPDATE {
      role: @role,
      updated_at: @now
    }
    IN access_grants
    RETURN NEW
    """

    key = "ag_#{investigation_id}_#{user_id}"

    case ArangoDB.query(aql, %{
           key: key,
           investigation_id: investigation_id,
           user_id: user_id,
           role: to_string(role),
           now: now
         }) do
      {:ok, [doc]} -> {:ok, format_grant(doc)}
      {:ok, []} -> {:error, :grant_failed}
      error -> error
    end
  end

  def grant_access(_investigation_id, _user_id, _role), do: {:error, :invalid_role}

  @doc """
  Revoke all access for a user on an investigation.
  """
  def revoke_access(investigation_id, user_id) do
    aql = """
    FOR grant IN access_grants
      FILTER grant.investigation_id == @investigation_id
      FILTER grant.user_id == @user_id
      REMOVE grant IN access_grants
      RETURN OLD
    """

    case ArangoDB.query(aql, %{investigation_id: investigation_id, user_id: user_id}) do
      {:ok, [_doc | _]} -> :ok
      {:ok, []} -> {:error, :not_found}
      error -> error
    end
  end

  # ---------------------------------------------------------------------------
  # Check access
  # ---------------------------------------------------------------------------

  @doc """
  Check if a user can perform a given action on an investigation.

  Returns `:ok` if allowed, `{:error, :forbidden}` otherwise.

  ## Examples

      iex> check_access("inv_1", "user_42", :edit)
      :ok

      iex> check_access("inv_1", "user_99", :delete)
      {:error, :forbidden}
  """
  def check_access(investigation_id, user_id, action) do
    case get_user_role(investigation_id, user_id) do
      {:ok, role} ->
        permissions = Map.get(@role_permissions, role, MapSet.new())

        if MapSet.member?(permissions, action) do
          :ok
        else
          {:error, :forbidden}
        end

      {:error, :not_found} ->
        {:error, :forbidden}

      error ->
        error
    end
  end

  @doc """
  Get the role a user has for a given investigation.

  Returns `{:ok, :editor}` etc. or `{:error, :not_found}`.
  """
  def get_user_role(investigation_id, user_id) do
    aql = """
    FOR grant IN access_grants
      FILTER grant.investigation_id == @investigation_id
      FILTER grant.user_id == @user_id
      LIMIT 1
      RETURN grant
    """

    case ArangoDB.query_read(aql, %{investigation_id: investigation_id, user_id: user_id}) do
      {:ok, [doc]} -> {:ok, String.to_existing_atom(doc["role"])}
      {:ok, []} -> {:error, :not_found}
      error -> error
    end
  end

  # ---------------------------------------------------------------------------
  # Listing
  # ---------------------------------------------------------------------------

  @doc """
  List all users with access to an investigation.

  Returns a list of:

      %{user_id: String.t(), role: atom(), granted_at: String.t()}
  """
  def list_collaborators(investigation_id) do
    aql = """
    FOR grant IN access_grants
      FILTER grant.investigation_id == @investigation_id
      SORT grant.granted_at ASC
      RETURN grant
    """

    case ArangoDB.query_read(aql, %{investigation_id: investigation_id}) do
      {:ok, docs} -> {:ok, Enum.map(docs, &format_grant/1)}
      error -> error
    end
  end

  @doc """
  List all investigations a user has access to.

  Returns a list of `%{investigation_id, role, granted_at}`.
  """
  def user_investigations(user_id) do
    aql = """
    FOR grant IN access_grants
      FILTER grant.user_id == @user_id
      SORT grant.granted_at DESC
      RETURN grant
    """

    case ArangoDB.query_read(aql, %{user_id: user_id}) do
      {:ok, docs} -> {:ok, Enum.map(docs, &format_grant/1)}
      error -> error
    end
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  @doc """
  All valid roles.
  """
  def valid_roles, do: @roles

  @doc """
  Get permissions for a given role.
  """
  def permissions_for(role) when role in @roles do
    Map.get(@role_permissions, role, MapSet.new())
  end

  def permissions_for(_), do: MapSet.new()

  defp format_grant(doc) do
    %{
      id: doc["_key"],
      investigation_id: doc["investigation_id"],
      user_id: doc["user_id"],
      role: String.to_existing_atom(doc["role"]),
      granted_at: doc["granted_at"],
      updated_at: doc["updated_at"]
    }
  end
end

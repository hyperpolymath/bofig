# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
defmodule EvidenceGraph.ApiKeys do
  @moduledoc """
  API Key management for the Evidence Graph public API.

  Provides CRUD operations for API keys stored in the ArangoDB `api_keys`
  collection.  Each key has:

  - A unique, cryptographically random token (the "key" itself)
  - A set of scopes controlling access (`:read`, `:write`, `:admin`, `:export`)
  - An owner (user_id) and human-readable name
  - Active/revoked status

  ## Key Format

  Keys are prefixed with `bg_` followed by 48 random bytes, Base62-encoded,
  giving approximately 256 bits of entropy.
  """

  alias EvidenceGraph.ArangoDB

  @valid_scopes [:read, :write, :admin, :export]

  @doc """
  Generate a new API key for a user.

  ## Parameters

  - `user_id` - The owning user's ID
  - `name` - Human-readable label for the key (e.g. "CI pipeline", "Research export")
  - `scopes` - List of access scopes (subset of #{inspect(@valid_scopes)})

  ## Returns

  `{:ok, %{key: string, doc: map}}` where `key` is the plaintext key
  (only returned at creation time).
  """
  def create_api_key(user_id, name, scopes) when is_list(scopes) do
    # Validate scopes
    invalid = Enum.reject(scopes, &(&1 in @valid_scopes))

    if invalid != [] do
      {:error, {:invalid_scopes, invalid, @valid_scopes}}
    else
      plaintext_key = generate_key()
      key_hash = hash_key(plaintext_key)

      document = %{
        _key: "apikey_" <> Ecto.UUID.generate(),
        key_hash: key_hash,
        key_prefix: String.slice(plaintext_key, 0, 8),
        user_id: user_id,
        name: name,
        scopes: Enum.map(scopes, &to_string/1),
        active: true,
        created_at: DateTime.to_iso8601(DateTime.utc_now()),
        last_used_at: nil,
        revoked_at: nil
      }

      case ArangoDB.insert("api_keys", document) do
        {:ok, doc} ->
          {:ok, %{key: plaintext_key, doc: doc}}

        error ->
          error
      end
    end
  end

  @doc """
  Validate an API key.

  Hashes the provided key and looks it up in the `api_keys` collection.
  Updates `last_used_at` on successful validation.

  ## Returns

  - `{:ok, api_key_doc}` if the key is valid and active
  - `{:error, :not_found}` if the key does not exist
  - `{:error, :revoked}` if the key has been revoked
  """
  def validate_api_key(plaintext_key) when is_binary(plaintext_key) do
    key_hash = hash_key(plaintext_key)

    aql = """
    FOR key IN api_keys
      FILTER key.key_hash == @key_hash
      LIMIT 1
      RETURN key
    """

    case ArangoDB.query_read(aql, %{key_hash: key_hash}) do
      {:ok, [doc]} ->
        if doc["active"] do
          # Update last_used_at (fire-and-forget, don't block validation)
          Task.start(fn ->
            ArangoDB.update("api_keys", doc["_key"], %{
              last_used_at: DateTime.to_iso8601(DateTime.utc_now())
            })
          end)

          {:ok, doc}
        else
          {:error, :revoked}
        end

      {:ok, []} ->
        {:error, :not_found}

      error ->
        error
    end
  end

  @doc """
  Revoke an API key by its document ID.

  Sets `active` to `false` and records the revocation timestamp.

  ## Returns

  `{:ok, updated_doc}` or `{:error, reason}`
  """
  def revoke_api_key(key_id) do
    ArangoDB.update("api_keys", key_id, %{
      active: false,
      revoked_at: DateTime.to_iso8601(DateTime.utc_now())
    })
  end

  @doc """
  List all API keys for a user.

  Returns key metadata (never the full key hash).  Keys are ordered
  by creation date, most recent first.

  ## Returns

  `{:ok, [api_key_summary]}` or `{:error, reason}`
  """
  def list_api_keys(user_id) do
    aql = """
    FOR key IN api_keys
      FILTER key.user_id == @user_id
      SORT key.created_at DESC
      RETURN {
        id: key._key,
        key_prefix: key.key_prefix,
        name: key.name,
        scopes: key.scopes,
        active: key.active,
        created_at: key.created_at,
        last_used_at: key.last_used_at,
        revoked_at: key.revoked_at
      }
    """

    ArangoDB.query_read(aql, %{user_id: user_id})
  end

  @doc """
  Returns the list of valid API key scopes.
  """
  def valid_scopes, do: @valid_scopes

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  # Generate a cryptographically random API key with a `bg_` prefix.
  defp generate_key do
    random_bytes = :crypto.strong_rand_bytes(48)
    encoded = Base.url_encode64(random_bytes, padding: false)
    "bg_" <> encoded
  end

  # Hash a plaintext key using SHA-256 for storage.
  # We never store plaintext keys — only the hash is persisted.
  defp hash_key(plaintext_key) do
    :crypto.hash(:sha256, plaintext_key)
    |> Base.encode16(case: :lower)
  end
end

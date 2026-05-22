# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
defmodule EvidenceGraph.Collaboration do
  @moduledoc """
  Real-Time Collaboration for the Evidence Graph.

  Provides presence tracking, change broadcasting, optimistic entity locking,
  and annotation management for investigation collaboration.  Backed by
  Phoenix.PubSub for real-time notifications and ArangoDB for persistent
  annotation and lock storage.

  ## Change Types

  Supported broadcast change types:
  - `:evidence_added`
  - `:claim_created`
  - `:entity_merged`
  - `:relationship_created`
  - `:annotation_added`
  """

  alias EvidenceGraph.ArangoDB

  @pubsub EvidenceGraph.PubSub
  @change_types [
    :evidence_added,
    :claim_created,
    :entity_merged,
    :relationship_created,
    :annotation_added
  ]

  @doc """
  Track a user joining an investigation.

  Stores presence in an ETS table for fast lookup and broadcasts
  the join event to all collaborators.
  """
  def join_investigation(investigation_id, user_id) do
    ensure_presence_table()

    key = {investigation_id, user_id}
    :ets.insert(:bofig_presence, {key, DateTime.utc_now()})

    Phoenix.PubSub.broadcast(
      @pubsub,
      "investigation:#{investigation_id}",
      {:user_joined, %{investigation_id: investigation_id, user_id: user_id}}
    )

    :ok
  end

  @doc """
  Track a user leaving an investigation.

  Removes presence and releases any entity locks held by the user.
  """
  def leave_investigation(investigation_id, user_id) do
    ensure_presence_table()

    key = {investigation_id, user_id}
    :ets.delete(:bofig_presence, key)

    # Release any locks held by this user for this investigation
    release_user_locks(investigation_id, user_id)

    Phoenix.PubSub.broadcast(
      @pubsub,
      "investigation:#{investigation_id}",
      {:user_left, %{investigation_id: investigation_id, user_id: user_id}}
    )

    :ok
  end

  @doc """
  List all users currently active in an investigation.

  Returns a list of `%{user_id: string, joined_at: DateTime.t()}`.
  """
  def active_users(investigation_id) do
    ensure_presence_table()

    :ets.select(:bofig_presence, [
      {
        {{investigation_id, :"$1"}, :"$2"},
        [],
        [%{user_id: :"$1", joined_at: :"$2"}]
      }
    ])
  end

  @doc """
  Broadcast a change event to all collaborators in an investigation.

  ## Parameters

  - `investigation_id` - The investigation scope
  - `change_type` - One of #{inspect(@change_types)}
  - `payload` - Arbitrary map with change details
  """
  def broadcast_change(investigation_id, change_type, payload)
      when change_type in @change_types do
    message = %{
      type: change_type,
      investigation_id: investigation_id,
      payload: payload,
      timestamp: DateTime.utc_now()
    }

    Phoenix.PubSub.broadcast(
      @pubsub,
      "investigation:#{investigation_id}",
      {:change, message}
    )

    :ok
  end

  def broadcast_change(_investigation_id, change_type, _payload) do
    {:error, {:invalid_change_type, change_type, @change_types}}
  end

  @doc """
  Acquire an optimistic lock on an entity for editing.

  Returns `:ok` if the lock was acquired, or `{:error, :locked, locking_user_id}`
  if another user already holds the lock.

  Locks expire after 5 minutes of inactivity.
  """
  def lock_entity(investigation_id, entity_id, user_id) do
    ensure_lock_table()

    lock_key = {investigation_id, entity_id}
    now = System.monotonic_time(:second)
    lock_ttl = 300  # 5 minutes

    case :ets.lookup(:bofig_entity_locks, lock_key) do
      [{^lock_key, ^user_id, _acquired_at}] ->
        # Same user, refresh the lock
        :ets.insert(:bofig_entity_locks, {lock_key, user_id, now})
        :ok

      [{^lock_key, other_user_id, acquired_at}] ->
        if now - acquired_at > lock_ttl do
          # Lock expired, take it
          :ets.insert(:bofig_entity_locks, {lock_key, user_id, now})
          :ok
        else
          {:error, :locked, other_user_id}
        end

      [] ->
        :ets.insert(:bofig_entity_locks, {lock_key, user_id, now})
        :ok
    end
  end

  @doc """
  Release an entity lock.

  Only the user who holds the lock can release it (or if the lock has expired).
  """
  def unlock_entity(investigation_id, entity_id, user_id) do
    ensure_lock_table()

    lock_key = {investigation_id, entity_id}

    case :ets.lookup(:bofig_entity_locks, lock_key) do
      [{^lock_key, ^user_id, _acquired_at}] ->
        :ets.delete(:bofig_entity_locks, lock_key)
        :ok

      [{^lock_key, _other_user_id, _acquired_at}] ->
        {:error, :not_lock_owner}

      [] ->
        :ok
    end
  end

  @doc """
  Create an annotation on any target entity (evidence, claim, entity, etc.).

  Annotations are stored in the ArangoDB `annotations` collection.

  ## Parameters

  - `target_id` - The `_key` of the target document
  - `target_type` - The collection name (e.g. "evidence", "claims", "entities")
  - `user_id` - The annotating user's ID
  - `text` - The annotation body text
  """
  def annotation_create(target_id, target_type, user_id, text) do
    document = %{
      _key: "ann_" <> Ecto.UUID.generate(),
      target_id: target_id,
      target_type: target_type,
      user_id: user_id,
      text: text,
      created_at: DateTime.to_iso8601(DateTime.utc_now()),
      updated_at: DateTime.to_iso8601(DateTime.utc_now())
    }

    case ArangoDB.insert("annotations", document) do
      {:ok, doc} ->
        {:ok, doc}

      error ->
        error
    end
  end

  @doc """
  List all annotations for a given target, ordered by creation date.

  ## Parameters

  - `target_id` - The `_key` of the target document
  - `target_type` - The collection name (e.g. "evidence", "claims", "entities")
  """
  def annotation_list(target_id, target_type) do
    aql = """
    FOR ann IN annotations
      FILTER ann.target_id == @target_id
      FILTER ann.target_type == @target_type
      SORT ann.created_at ASC
      RETURN ann
    """

    case ArangoDB.query_read(aql, %{target_id: target_id, target_type: target_type}) do
      {:ok, docs} -> {:ok, docs}
      error -> error
    end
  end

  @doc """
  Returns the list of supported change types.
  """
  def change_types, do: @change_types

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp ensure_presence_table do
    case :ets.whereis(:bofig_presence) do
      :undefined ->
        :ets.new(:bofig_presence, [:named_table, :public, :set])

      _ref ->
        :ok
    end
  end

  defp ensure_lock_table do
    case :ets.whereis(:bofig_entity_locks) do
      :undefined ->
        :ets.new(:bofig_entity_locks, [:named_table, :public, :set])

      _ref ->
        :ok
    end
  end

  defp release_user_locks(investigation_id, user_id) do
    ensure_lock_table()

    # Find and delete all locks held by this user for this investigation
    :ets.select_delete(:bofig_entity_locks, [
      {
        {{investigation_id, :_}, user_id, :_},
        [],
        [true]
      }
    ])
  end
end

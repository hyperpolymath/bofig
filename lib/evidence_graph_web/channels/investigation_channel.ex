# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
defmodule EvidenceGraphWeb.InvestigationChannel do
  @moduledoc """
  Phoenix Channel for real-time investigation collaboration.

  Handles join/leave with presence tracking, broadcasts entity changes,
  claim updates, and annotation additions to all connected clients.

  ## Topic Format

      "investigation:<investigation_id>"

  ## Incoming Events

  - `"lock_entity"` - Acquire an optimistic lock on an entity
  - `"unlock_entity"` - Release an entity lock
  - `"add_annotation"` - Create an annotation on a target
  - `"list_annotations"` - Fetch annotations for a target

  ## Outgoing Events

  - `"presence_state"` - Full presence state on join
  - `"user_joined"` - A user joined the investigation
  - `"user_left"` - A user left the investigation
  - `"change"` - An entity/claim/evidence change occurred
  - `"annotation_added"` - A new annotation was created
  """

  use Phoenix.Channel

  alias EvidenceGraph.Collaboration
  alias EvidenceGraph.Authorization

  @max_annotation_length 10_000

  @impl true
  def join("investigation:" <> investigation_id, _params, socket) do
    user_id = socket.assigns[:user_id]

    # Require authenticated user — reject anonymous channel joins
    if is_nil(user_id) do
      {:error, %{reason: "authentication_required"}}
    else
      # Verify user has at least viewer access to this investigation
      case Authorization.check_access(investigation_id, user_id, :view) do
        :ok ->
          Collaboration.join_investigation(investigation_id, user_id)

          Phoenix.PubSub.subscribe(EvidenceGraph.PubSub, "investigation:#{investigation_id}")

          socket =
            socket
            |> assign(:investigation_id, investigation_id)
            |> assign(:user_id, user_id)

          active = Collaboration.active_users(investigation_id)
          send(self(), {:after_join, active})

          {:ok, %{investigation_id: investigation_id, user_id: user_id}, socket}

        {:error, _} ->
          {:error, %{reason: "forbidden"}}
      end
    end
  end

  @impl true
  def terminate(_reason, socket) do
    investigation_id = socket.assigns[:investigation_id]
    user_id = socket.assigns[:user_id]

    if investigation_id && user_id do
      Collaboration.leave_investigation(investigation_id, user_id)
    end

    :ok
  end

  # ---------------------------------------------------------------------------
  # Incoming events
  # ---------------------------------------------------------------------------

  @impl true
  def handle_in("lock_entity", %{"entity_id" => entity_id}, socket) do
    investigation_id = socket.assigns.investigation_id
    user_id = socket.assigns.user_id

    case Collaboration.lock_entity(investigation_id, entity_id, user_id) do
      :ok ->
        {:reply, {:ok, %{status: "locked", entity_id: entity_id}}, socket}

      {:error, :locked, other_user_id} ->
        {:reply,
         {:error,
          %{
            status: "already_locked",
            entity_id: entity_id,
            locked_by: other_user_id
          }}, socket}
    end
  end

  @impl true
  def handle_in("unlock_entity", %{"entity_id" => entity_id}, socket) do
    investigation_id = socket.assigns.investigation_id
    user_id = socket.assigns.user_id

    case Collaboration.unlock_entity(investigation_id, entity_id, user_id) do
      :ok ->
        {:reply, {:ok, %{status: "unlocked", entity_id: entity_id}}, socket}

      {:error, :not_lock_owner} ->
        {:reply, {:error, %{status: "not_lock_owner", entity_id: entity_id}}, socket}
    end
  end

  @impl true
  def handle_in(
        "add_annotation",
        %{"target_id" => target_id, "target_type" => target_type, "text" => text},
        socket
      ) do
    user_id = socket.assigns.user_id
    investigation_id = socket.assigns.investigation_id

    if String.length(text) > @max_annotation_length do
      {:reply, {:error, %{reason: "annotation_too_long", max: @max_annotation_length}}, socket}
    else
    case Collaboration.annotation_create(target_id, target_type, user_id, text) do
      {:ok, annotation} ->
        # Broadcast the new annotation to all collaborators
        broadcast!(socket, "annotation_added", %{
          annotation: annotation,
          investigation_id: investigation_id
        })

        {:reply, {:ok, %{annotation: annotation}}, socket}

      {:error, reason} ->
        {:reply, {:error, %{reason: inspect(reason)}}, socket}
    end
    end
  end

  @impl true
  def handle_in(
        "list_annotations",
        %{"target_id" => target_id, "target_type" => target_type},
        socket
      ) do
    case Collaboration.annotation_list(target_id, target_type) do
      {:ok, annotations} ->
        {:reply, {:ok, %{annotations: annotations}}, socket}

      {:error, reason} ->
        {:reply, {:error, %{reason: inspect(reason)}}, socket}
    end
  end

  # Catch-all for unhandled events
  @impl true
  def handle_in(_event, _payload, socket) do
    {:noreply, socket}
  end

  # ---------------------------------------------------------------------------
  # PubSub and info handlers
  # ---------------------------------------------------------------------------

  @impl true
  def handle_info({:after_join, active_users}, socket) do
    push(socket, "presence_state", %{users: active_users})
    {:noreply, socket}
  end

  @impl true
  def handle_info({:user_joined, payload}, socket) do
    push(socket, "user_joined", payload)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:user_left, payload}, socket) do
    push(socket, "user_left", payload)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:change, message}, socket) do
    push(socket, "change", %{
      type: to_string(message.type),
      payload: message.payload,
      timestamp: DateTime.to_iso8601(message.timestamp)
    })

    {:noreply, socket}
  end

  @impl true
  def handle_info(_msg, socket) do
    {:noreply, socket}
  end
end

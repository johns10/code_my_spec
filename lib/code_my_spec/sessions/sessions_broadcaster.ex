defmodule CodeMySpec.Sessions.SessionsBroadcaster do
  @moduledoc """
  Centralized broadcasting for session-related events.

  Handles PubSub broadcasting for session lifecycle events, updates, and notifications
  to both account-level and user-level channels.
  """

  alias CodeMySpec.Sessions.{Session, SessionsRepository}
  alias CodeMySpec.Users.Scope

  @doc """
  Broadcasts a session creation event.
  """
  def broadcast_created(%Scope{} = scope, %Session{} = session) do
    session_with_display = SessionsRepository.populate_display_name(session)
    broadcast_to_channels(scope, {:created, session_with_display})
  end

  @doc """
  Broadcasts a session update event.
  """
  def broadcast_updated(%Scope{} = scope, %Session{} = session) do
    outbound_session =
      SessionsRepository.preload_session(scope, session)
      |> SessionsRepository.populate_display_name()
      |> IO.inspect()

    broadcast_to_channels(scope, {:updated, outbound_session})
  end

  @doc """
  Broadcasts a session deletion event.
  """
  def broadcast_deleted(%Scope{} = scope, %Session{} = session) do
    broadcast_to_channels(scope, {:deleted, session})
  end

  @doc """
  Broadcasts session activity (for event-based updates).
  """
  def broadcast_activity(%Scope{} = scope, session_id) do
    message = {:session_activity, %{session_id: session_id}}
    broadcast_to_channels(scope, message)
  end

  @doc """
  Broadcasts execution mode change notification.
  """
  def broadcast_mode_change(%Scope{} = scope, session_id, execution_mode) do
    message = {:session_mode_updated, %{session_id: session_id, execution_mode: execution_mode}}
    broadcast_to_channels(scope, message)
  end

  # Private helper to broadcast to both account and user channels
  defp broadcast_to_channels(%Scope{} = scope, message) do
    account_key = scope.active_account_id
    user_id = scope.user.id

    Phoenix.PubSub.broadcast(CodeMySpec.PubSub, "account:#{account_key}:sessions", message)
    Phoenix.PubSub.broadcast(CodeMySpec.PubSub, "user:#{user_id}:sessions", message)
  end
end

defmodule CodeMySpec.Sessions.EventHandler do
  @moduledoc """
  Processes incoming events from CLI/VSCode clients, persists them to the interaction_events table,
  applies session-level side effects, and broadcasts notifications to connected clients.

  Events are append-only and processed either individually or in batches with transactional
  guarantees. Side effects are applied based on event type, with most events having no
  side effects.
  """

  require Logger
  import Ecto.Query, warn: false

  alias CodeMySpec.Repo
  alias CodeMySpec.Users.Scope

  alias CodeMySpec.Sessions.{
    Session,
    Interaction,
    InteractionEvent,
    InteractionsRepository,
    SessionsRepository,
    SessionsBroadcaster,
    InteractionRegistry
  }

  @doc """
  Processes a single event for an interaction.

  ## Parameters
  - `scope` - User scope for authorization
  - `interaction_id` - ID of interaction to add event to
  - `event_attrs` - Event attributes including event_type, timestamp, data, etc.

  ## Returns
  - `{:ok, session}` - Event processed successfully, returns updated session
  - `{:error, :interaction_not_found}` - Interaction doesn't exist
  - `{:error, changeset}` - Event validation failed
  - `{:error, reason}` - Other persistence or processing error

  ## Examples

      iex> handle_event(scope, interaction_id, %{event_type: :tool_called, sent_at: ~U[2025-01-01 00:00:00Z], data: %{}})
      {:ok, %Session{}}

      iex> handle_event(scope, invalid_id, %{event_type: :tool_called, sent_at: ~U[2025-01-01 00:00:00Z], data: %{}})
      {:error, :interaction_not_found}
  """
  @spec handle_event(Scope.t(), binary(), map()) :: {:ok, Session.t()} | {:error, term()}

  def handle_event(%Scope{} = scope, interaction_id, event_attrs) do
    event_type = Map.get(event_attrs, "event_type") || Map.get(event_attrs, :event_type)
    Logger.debug("Handling event #{event_type} for interaction #{interaction_id}")

    with %Interaction{} = interaction <- InteractionsRepository.get(interaction_id),
         %Session{} = session <- SessionsRepository.get_session(scope, interaction.session_id) do
      process_single_event(scope, session, interaction, event_attrs)
    else
      nil ->
        Logger.warning("Event rejected: interaction #{interaction_id} not found")
        {:error, :interaction_not_found}

      error ->
        Logger.error("Event handling failed for interaction #{interaction_id}: #{inspect(error)}")
        error
    end
  end

  # Private Functions

  defp process_single_event(scope, session, interaction, event_attrs) do
    Repo.transaction(fn ->
      # Add interaction_id to event attributes
      event_attrs_with_interaction = Map.put(event_attrs, "interaction_id", interaction.id)

      with {:ok, event} <- build_and_validate_event(event_attrs_with_interaction),
           {:ok, session_updates} <- process_side_effects(scope, session, event),
           {:ok, _inserted_event} <- insert_event(event),
           {:ok, updated_session} <- apply_session_updates(scope, session, session_updates) do
        # Log event processing completion
        log_event_processed(session.id, event, session_updates)

        # Update interaction registry with runtime status
        update_interaction_registry(interaction.id, event)

        SessionsBroadcaster.broadcast_activity(scope, session.id)
        updated_session
      else
        {:error, reason} ->
          Logger.error("Event processing failed for session #{session.id}: #{inspect(reason)}")

          Repo.rollback(reason)
      end
    end)
  end

  defp build_and_validate_event(event_attrs) do
    changeset = InteractionEvent.changeset(%InteractionEvent{}, event_attrs)

    if changeset.valid? do
      {:ok, Ecto.Changeset.apply_changes(changeset)}
    else
      event_type = Map.get(event_attrs, "event_type") || Map.get(event_attrs, :event_type)

      Logger.warning("Event validation failed for #{event_type}: #{inspect(changeset.errors)}")

      {:error, changeset}
    end
  end

  defp insert_event(event) do
    event
    |> Ecto.Changeset.change()
    |> Repo.insert()
  end

  defp process_side_effects(scope, session, event) do
    case apply_side_effect(scope, session, event) do
      {:ok, updates} when map_size(updates) > 0 ->
        Logger.debug(
          "Side effects applied for event #{event.event_type} on session #{session.id}: #{inspect(Map.keys(updates))}"
        )

        {:ok, updates}

      {:ok, updates} ->
        {:ok, updates}

      {:error, reason} ->
        Logger.warning(
          "Side effect processing failed for event #{event.event_type} on session #{session.id}: #{inspect(reason)}"
        )

        {:ok, %{}}
    end
  end

  # Check for status change first (based on data content, not event type)
  defp apply_side_effect(_scope, %Session{} = _session, %InteractionEvent{data: data})
       when is_map_key(data, "new_status") do
    new_status = Map.get(data, "new_status")

    case parse_status(new_status) do
      {:ok, status_atom} -> {:ok, %{status: status_atom}}
      {:error, _} = error -> error
    end
  end

  # Check for conversation_id (session_start event)
  defp apply_side_effect(
         _scope,
         %Session{external_conversation_id: nil} = session,
         %InteractionEvent{event_type: :session_start, data: data}
       ) do
    case Map.get(data, "session_id", nil) do
      nil ->
        Logger.warning("session_start event missing session_id for session #{session.id}")
        {:error, :session_id_not_found}

      conversation_id ->
        Logger.info("Setting conversation_id #{conversation_id} for session #{session.id}")
        {:ok, %{external_conversation_id: conversation_id}}
    end
  end

  defp apply_side_effect(
         _scope,
         %Session{external_conversation_id: existing_id} = session,
         %InteractionEvent{event_type: :session_start, data: data}
       ) do
    conversation_id = Map.get(data, "session_id")

    if existing_id == conversation_id do
      {:ok, %{}}
    else
      Logger.warning(
        "Attempted to change conversation_id from #{existing_id} to #{conversation_id} for session #{session.id}"
      )

      {:ok, %{}}
    end
  end

  # Handle notification - broadcast to clients
  defp apply_side_effect(_scope, %Session{} = session, %InteractionEvent{
         event_type: :notification,
         data: data
       }) do
    notification_type = Map.get(data, "notification_type")

    Logger.info("Broadcasting notification (#{notification_type}) for session #{session.id}")

    payload = %{
      session_id: session.id,
      notification_type: notification_type,
      data: data
    }

    Phoenix.PubSub.broadcast(
      CodeMySpec.PubSub,
      "account:#{session.account_id}:sessions",
      {:notification, payload}
    )

    Phoenix.PubSub.broadcast(
      CodeMySpec.PubSub,
      "user:#{session.user_id}:sessions",
      {:notification, payload}
    )

    {:ok, %{}}
  end

  # Handle session_end - finalize session and broadcast
  defp apply_side_effect(
         %Scope{} = scope,
         %Session{} = session,
         %InteractionEvent{event_type: :session_end, interaction_id: interaction_id, data: data}
       ) do
    Logger.info("Processing session_end for session #{session.id}")

    # Extract result from event data, defaulting to empty map
    result =
      Map.get(data, "result", %{})
      |> Map.put("status", :ok)

    # Call Sessions.handle_result to process the result and update session
    case CodeMySpec.Sessions.handle_result(scope, session.id, interaction_id, result) do
      {:ok, _updated_session} ->
        Logger.info("Session #{session.id} ended successfully, broadcasting to clients")

        # Broadcast session_ended message to clients
        Phoenix.PubSub.broadcast(
          CodeMySpec.PubSub,
          "account:#{session.account_id}:sessions",
          {:session_ended, session.id}
        )

        Phoenix.PubSub.broadcast(
          CodeMySpec.PubSub,
          "user:#{session.user_id}:sessions",
          {:session_ended, session.id}
        )

        {:ok, %{}}

      {:error, reason} ->
        Logger.error(
          "Failed to handle result for session_end event on session #{session.id}: #{inspect(reason)}"
        )

        # Return success to allow event to be recorded even if result handling fails
        {:ok, %{}}
    end
  end

  # Default: no side effects
  defp apply_side_effect(_scope, %Session{} = _session, %InteractionEvent{} = _event) do
    {:ok, %{}}
  end

  defp parse_status(status) when is_atom(status), do: {:ok, status}
  defp parse_status("active"), do: {:ok, :active}
  defp parse_status("complete"), do: {:ok, :complete}
  defp parse_status("failed"), do: {:ok, :failed}
  defp parse_status("cancelled"), do: {:ok, :cancelled}
  defp parse_status(status), do: {:error, "Invalid status: #{inspect(status)}"}

  defp apply_session_updates(_scope, session, updates) when map_size(updates) == 0 do
    {:ok, session}
  end

  defp apply_session_updates(scope, session, updates) do
    case Session.changeset(session, updates, scope) |> Repo.update() do
      {:ok, updated_session} ->
        broadcast_session_updates(scope, session.id, updates)
        {:ok, updated_session}

      error ->
        error
    end
  end

  defp broadcast_session_updates(scope, session_id, updates) do
    account_key = scope.active_account_id
    user_id = scope.user.id

    Enum.each(updates, fn {field, value} ->
      message = build_update_message(session_id, field, value)

      channels =
        build_update_channels(field, %{
          session_id: session_id,
          account_key: account_key,
          user_id: user_id
        })

      Enum.map(channels, fn channel ->
        Phoenix.PubSub.broadcast(CodeMySpec.PubSub, channel, message)
      end)
    end)
  end

  defp build_update_message(session_id, :external_conversation_id, conversation_id) do
    {:conversation_id_set, %{session_id: session_id, conversation_id: conversation_id}}
  end

  defp build_update_message(session_id, :status, status) do
    {:session_status_changed, %{session_id: session_id, status: status}}
  end

  defp build_update_message(session_id, field, value) do
    {:session_updated, %{session_id: session_id, field: field, value: value}}
  end

  defp build_update_channels(_field, %{
         account_key: account_key,
         user_id: user_id
       }) do
    [
      "account:#{account_key}:sessions",
      "user:#{user_id}:sessions"
    ]
  end

  # Log event processing completion
  defp log_event_processed(session_id, event, session_updates)
       when map_size(session_updates) > 0 do
    Logger.info(
      "Event #{event.event_type} processed for session #{session_id}, updates: #{inspect(Map.keys(session_updates))}"
    )
  end

  defp log_event_processed(session_id, event, _session_updates) do
    Logger.debug("Event #{event.event_type} processed for session #{session_id}")
  end

  # Update interaction registry with runtime status based on event type
  defp update_interaction_registry(interaction_id, %InteractionEvent{
         event_type: :notification,
         data: data
       }) do
    InteractionRegistry.update_status(interaction_id, %{
      agent_state: "notification",
      last_notification: Map.put(data, "timestamp", DateTime.utc_now())
    })
  end

  defp update_interaction_registry(interaction_id, %InteractionEvent{
         event_type: :session_start,
         data: data
       }) do
    InteractionRegistry.update_status(interaction_id, %{
      agent_state: "started",
      conversation_id: Map.get(data, "session_id"),
      last_activity: %{
        event_type: :session_start,
        session_id: Map.get(data, "session_id"),
        timestamp: DateTime.utc_now()
      }
    })
  end

  defp update_interaction_registry(interaction_id, %InteractionEvent{
         event_type: :proxy_request,
         data: data
       })
       when is_map_key(data, "new_status") do
    # Status change event
    InteractionRegistry.update_status(interaction_id, %{
      agent_state: Map.get(data, "new_status")
    })
  end

  defp update_interaction_registry(interaction_id, %InteractionEvent{
         event_type: event_type,
         data: data
       })
       when event_type in [:proxy_request, :proxy_response] do
    # Tool activity
    InteractionRegistry.update_status(interaction_id, %{
      agent_state: "running",
      last_activity: %{
        event_type: event_type,
        tool_name: Map.get(data, "tool_name"),
        timestamp: DateTime.utc_now()
      }
    })
  end

  defp update_interaction_registry(interaction_id, %InteractionEvent{
         event_type: :post_tool_use,
         data: data
       }) do
    InteractionRegistry.update_status(interaction_id, %{
      agent_state: "running",
      last_activity: %{
        event_type: :post_tool_use,
        tool_name: Map.get(data, "tool_name"),
        tool_use_id: Map.get(data, "tool_use_id"),
        timestamp: DateTime.utc_now()
      }
    })
  end

  defp update_interaction_registry(interaction_id, %InteractionEvent{
         event_type: :user_prompt_submit,
         data: data
       }) do
    # Explicit nil values clear the fields via changeset
    InteractionRegistry.update_status(interaction_id, %{
      agent_state: "running",
      last_notification: nil,
      last_stopped: nil,
      last_activity: %{
        event_type: :user_prompt_submit,
        prompt_preview: String.slice(Map.get(data, "prompt", ""), 0, 100),
        timestamp: DateTime.utc_now()
      }
    })
  end

  defp update_interaction_registry(interaction_id, %InteractionEvent{
         event_type: :stop,
         data: data
       }) do
    InteractionRegistry.update_status(interaction_id, %{
      agent_state: "idle",
      last_stopped: %{
        timestamp: DateTime.utc_now(),
        stop_hook_active: Map.get(data, "stop_hook_active", false)
      }
    })
  end

  defp update_interaction_registry(interaction_id, %InteractionEvent{
         event_type: :session_end,
         data: data
       }) do
    InteractionRegistry.update_status(interaction_id, %{
      agent_state: "ended",
      last_activity: %{
        event_type: :session_end,
        reason: Map.get(data, "reason"),
        timestamp: DateTime.utc_now()
      }
    })
  end

  # Default: don't update registry for other event types
  defp update_interaction_registry(_interaction_id, _event), do: :ok
end

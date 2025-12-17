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
    InteractionRegistry,
    RuntimeInteraction
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
    with %Interaction{} = interaction <- InteractionsRepository.get(interaction_id),
         %Session{} = session <- SessionsRepository.get_session(scope, interaction.session_id) do
      process_single_event(scope, session, interaction, event_attrs)
    else
      nil -> {:error, :interaction_not_found}
      error -> error
    end
  end

  # Private Functions

  defp process_single_event(scope, session, interaction, event_attrs) do
    Repo.transaction(fn ->
      # Add interaction_id to event attributes
      event_attrs_with_interaction = Map.put(event_attrs, "interaction_id", interaction.id)

      with {:ok, event} <- build_and_validate_event(event_attrs_with_interaction),
           {:ok, session_updates} <- process_side_effects(session, event),
           {:ok, _inserted_event} <- insert_event(event),
           {:ok, updated_session} <- apply_session_updates(scope, session, session_updates) do
        Logger.info(inspect(updated_session))

        # Update interaction registry with runtime status
        update_interaction_registry(interaction.id, event)

        SessionsBroadcaster.broadcast_activity(scope, session.id)
        updated_session
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  defp build_and_validate_event(event_attrs) do
    changeset = InteractionEvent.changeset(%InteractionEvent{}, event_attrs)

    if changeset.valid? do
      {:ok, Ecto.Changeset.apply_changes(changeset)}
    else
      {:error, changeset}
    end
  end

  defp insert_event(event) do
    event
    |> Ecto.Changeset.change()
    |> Repo.insert()
  end

  defp process_side_effects(session, event) do
    case apply_side_effect(session, event) do
      {:ok, updates} ->
        {:ok, updates}

      {:error, reason} ->
        Logger.warning(
          "Side effect processing failed for event #{event.event_type}: #{inspect(reason)}"
        )

        {:ok, %{}}
    end
  end

  # Check for status change first (based on data content, not event type)
  defp apply_side_effect(%Session{} = _session, %InteractionEvent{data: data})
       when is_map_key(data, "new_status") do
    new_status = Map.get(data, "new_status")

    case parse_status(new_status) do
      {:ok, status_atom} -> {:ok, %{status: status_atom}}
      {:error, _} = error -> error
    end
  end

  # Check for conversation_id (session_start event)
  defp apply_side_effect(
         %Session{external_conversation_id: nil} = _session,
         %InteractionEvent{event_type: :session_start, data: data}
       ) do
    case Map.get(data, "session_id", nil) do
      nil -> {:error, :session_id_not_found}
      conversation_id -> {:ok, %{external_conversation_id: conversation_id}}
    end
  end

  defp apply_side_effect(
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

  # Handle notification_hook - broadcast to clients
  defp apply_side_effect(%Session{} = session, %InteractionEvent{
         event_type: :notification_hook,
         data: data
       }) do
    payload = %{
      session_id: session.id,
      notification_type: Map.get(data, "notification_type"),
      data: data
    }

    Phoenix.PubSub.broadcast(
      CodeMySpec.PubSub,
      "account:#{session.account_id}:sessions",
      {:notification_hook, payload}
    )

    Phoenix.PubSub.broadcast(
      CodeMySpec.PubSub,
      "user:#{session.user_id}:sessions",
      {:notification_hook, payload}
    )

    {:ok, %{}}
  end

  # Default: no side effects
  defp apply_side_effect(%Session{} = _session, %InteractionEvent{} = _event) do
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

  # Update interaction registry with runtime status based on event type
  defp update_interaction_registry(interaction_id, %InteractionEvent{
         event_type: :notification_hook,
         data: data
       }) do
    runtime =
      RuntimeInteraction.new(interaction_id, %{
        agent_state: "notification",
        last_notification: data
      })

    InteractionRegistry.register_status(runtime)
  end

  defp update_interaction_registry(interaction_id, %InteractionEvent{
         event_type: :session_start,
         data: data
       }) do
    runtime =
      RuntimeInteraction.new(interaction_id, %{
        agent_state: "started",
        conversation_id: Map.get(data, "session_id")
      })

    InteractionRegistry.register_status(runtime)
  end

  defp update_interaction_registry(interaction_id, %InteractionEvent{
         event_type: :proxy_request,
         data: data
       })
       when is_map_key(data, "new_status") do
    # Status change event
    runtime =
      RuntimeInteraction.new(interaction_id, %{
        agent_state: Map.get(data, "new_status")
      })

    InteractionRegistry.register_status(runtime)
  end

  defp update_interaction_registry(interaction_id, %InteractionEvent{
         event_type: event_type,
         data: data
       })
       when event_type in [:proxy_request, :proxy_response] do
    # Tool activity
    runtime =
      RuntimeInteraction.new(interaction_id, %{
        agent_state: "running",
        last_activity: %{
          event_type: event_type,
          tool_name: Map.get(data, "tool_name"),
          timestamp: DateTime.utc_now()
        }
      })

    InteractionRegistry.register_status(runtime)
  end

  # Default: don't update registry for other event types
  defp update_interaction_registry(_interaction_id, _event), do: :ok
end

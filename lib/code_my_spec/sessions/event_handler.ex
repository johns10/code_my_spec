defmodule CodeMySpec.Sessions.EventHandler do
  @moduledoc """
  Processes incoming events from VS Code clients, persists them to the session_events table,
  applies session-level side effects, and broadcasts notifications to connected clients.

  Events are append-only and processed either individually or in batches with transactional
  guarantees. Side effects are applied based on event type, with most events having no
  side effects.
  """

  require Logger
  import Ecto.Query, warn: false

  alias CodeMySpec.Repo
  alias CodeMySpec.Users.Scope
  alias CodeMySpec.Sessions.{Session, SessionEvent, SessionsRepository, SessionsBroadcaster}

  @doc """
  Processes a single event for a session.

  ## Parameters
  - `scope` - User scope for authorization
  - `session_id` - ID of session to add event to
  - `event_attrs` - Event attributes including event_type, timestamp, data, etc.

  ## Returns
  - `{:ok, session}` - Event processed successfully, returns updated session
  - `{:error, :session_not_found}` - Session doesn't exist or not accessible by scope
  - `{:error, changeset}` - Event validation failed
  - `{:error, reason}` - Other persistence or processing error

  ## Examples

      iex> handle_event(scope, session_id, %{event_type: :tool_called, sent_at: ~U[2025-01-01 00:00:00Z], data: %{}})
      {:ok, %Session{}}

      iex> handle_event(scope, invalid_id, %{event_type: :tool_called, sent_at: ~U[2025-01-01 00:00:00Z], data: %{}})
      {:error, :session_not_found}
  """
  @spec handle_event(Scope.t(), integer(), map()) :: {:ok, Session.t()} | {:error, term()}
  def handle_event(%Scope{} = scope, session_id, event_attrs) do
    case SessionsRepository.get_session(scope, session_id) do
      nil ->
        {:error, :session_not_found}

      session ->
        process_single_event(scope, session, event_attrs)
    end
  end

  @doc """
  Processes multiple events in a batch for a session.

  ## Parameters
  - `scope` - User scope for authorization
  - `session_id` - ID of session to add events to
  - `events_attrs` - List of event attribute maps

  ## Returns
  - `{:ok, session}` - All events processed successfully, returns updated session
  - `{:error, :session_not_found}` - Session doesn't exist or not accessible by scope
  - `{:error, changeset}` - First event validation that failed
  - `{:error, reason}` - Other persistence or processing error

  ## Examples

      iex> handle_events(scope, session_id, [%{event_type: :tool_called, ...}, %{event_type: :file_modified, ...}])
      {:ok, %Session{}}

      iex> handle_events(scope, session_id, [%{event_type: :invalid}, ...])
      {:error, %Ecto.Changeset{}}
  """
  @spec handle_events(Scope.t(), integer(), [map()]) :: {:ok, Session.t()} | {:error, term()}
  def handle_events(%Scope{} = scope, session_id, events_attrs) when is_list(events_attrs) do
    case SessionsRepository.get_session(scope, session_id) do
      nil ->
        {:error, :session_not_found}

      session ->
        process_batch_events(scope, session, events_attrs)
    end
  end

  @doc """
  Queries events for a session with optional filtering and pagination.

  ## Parameters
  - `scope` - User scope for authorization
  - `session_id` - ID of session to query events for
  - `opts` - Query options

  ## Options
  - `:event_type` - Filter by specific event type atom (e.g., `:tool_called`)
  - `:limit` - Maximum number of events to return
  - `:offset` - Number of events to skip (for pagination)
  - `:order` - `:asc` or `:desc` (default: `:asc` by timestamp)

  ## Returns
  List of SessionEvent structs (empty list if session not found or no events)

  ## Examples

      iex> get_events(scope, session_id)
      [%SessionEvent{}, ...]

      iex> get_events(scope, session_id, event_type: :tool_called, limit: 10)
      [%SessionEvent{}, ...]
  """
  @spec get_events(Scope.t(), integer(), keyword()) :: [SessionEvent.t()]
  def get_events(%Scope{} = scope, session_id, opts \\ []) do
    case SessionsRepository.get_session(scope, session_id) do
      nil ->
        []

      _session ->
        query_events(session_id, opts)
    end
  end

  # Private Functions

  defp process_single_event(scope, session, event_attrs) do
    Repo.transaction(fn ->
      with {:ok, event} <- build_and_validate_event(event_attrs),
           {:ok, session_updates} <- process_side_effects(session, event),
           {:ok, _inserted_event} <- insert_event(event),
           {:ok, updated_session} <- apply_session_updates(scope, session, session_updates) do
        SessionsBroadcaster.broadcast_activity(scope, session.id)
        updated_session
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  defp process_batch_events(scope, session, events_attrs) do
    Repo.transaction(fn ->
      with {:ok, events} <- build_and_validate_events(events_attrs),
           {:ok, session_updates} <- process_batch_side_effects(session, events),
           {:ok, _inserted_events} <- insert_events_with_return(events),
           {:ok, updated_session} <- apply_session_updates(scope, session, session_updates) do
        SessionsBroadcaster.broadcast_activity(scope, session.id)
        updated_session
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  defp build_and_validate_event(event_attrs) do
    changeset = SessionEvent.changeset(%SessionEvent{}, event_attrs)

    if changeset.valid? do
      {:ok, Ecto.Changeset.apply_changes(changeset)}
    else
      {:error, changeset}
    end
  end

  defp build_and_validate_events(events_attrs) do
    events_attrs
    |> Enum.reduce_while({:ok, []}, fn event_attrs, {:ok, acc} ->
      case build_and_validate_event(event_attrs) do
        {:ok, event} -> {:cont, {:ok, [event | acc]}}
        {:error, changeset} -> {:halt, {:error, changeset}}
      end
    end)
    |> case do
      {:ok, events} -> {:ok, Enum.reverse(events)}
      error -> error
    end
  end

  defp insert_event(event) do
    event
    |> Ecto.Changeset.change()
    |> Repo.insert()
  end

  defp insert_events_with_return(events) do
    events
    |> Enum.reduce_while({:ok, []}, fn event, {:ok, acc} ->
      case insert_event(event) do
        {:ok, inserted_event} -> {:cont, {:ok, [inserted_event | acc]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, inserted_events} -> {:ok, Enum.reverse(inserted_events)}
      error -> error
    end
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

  defp process_batch_side_effects(session, events) do
    events
    |> Enum.reduce({:ok, session, %{}}, fn event, {:ok, current_session, acc_updates} ->
      case apply_side_effect(current_session, event) do
        {:ok, updates} ->
          # Merge updates and apply them to session for next iteration
          merged_updates = Map.merge(acc_updates, updates)
          updated_session = Map.merge(current_session, merged_updates)
          {:ok, updated_session, merged_updates}

        {:error, reason} ->
          Logger.warning(
            "Side effect processing failed for event #{event.event_type}: #{inspect(reason)}"
          )

          {:ok, current_session, acc_updates}
      end
    end)
    |> case do
      {:ok, _final_session, updates} -> {:ok, updates}
    end
  end

  # Check for status change first (based on data content, not event type)
  defp apply_side_effect(%Session{} = _session, %SessionEvent{data: data})
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
         %SessionEvent{event_type: :session_start, data: data}
       ) do
    conversation_id = Map.get(data, "conversation_id")
    {:ok, %{external_conversation_id: conversation_id}}
  end

  defp apply_side_effect(
         %Session{external_conversation_id: existing_id} = session,
         %SessionEvent{event_type: :session_start, data: data}
       ) do
    conversation_id = Map.get(data, "conversation_id")

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
  defp apply_side_effect(%Session{} = session, %SessionEvent{
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
  defp apply_side_effect(%Session{} = _session, %SessionEvent{} = _event) do
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

  defp query_events(session_id, opts) do
    event_type = Keyword.get(opts, :event_type)
    limit = Keyword.get(opts, :limit)
    offset = Keyword.get(opts, :offset, 0)
    order = Keyword.get(opts, :order, :asc)

    SessionEvent
    |> where([e], e.session_id == ^session_id)
    |> maybe_filter_by_event_type(event_type)
    |> order_by_timestamp(order)
    |> maybe_apply_offset(offset)
    |> maybe_apply_limit(limit)
    |> Repo.all()
  end

  defp maybe_filter_by_event_type(query, nil), do: query

  defp maybe_filter_by_event_type(query, event_type) do
    where(query, [e], e.event_type == ^event_type)
  end

  defp order_by_timestamp(query, :asc), do: order_by(query, [e], asc: e.sent_at)
  defp order_by_timestamp(query, :desc), do: order_by(query, [e], desc: e.sent_at)

  defp maybe_apply_offset(query, 0), do: query

  defp maybe_apply_offset(query, offset) when is_integer(offset) and offset > 0 do
    offset(query, ^offset)
  end

  defp maybe_apply_limit(query, nil), do: query

  defp maybe_apply_limit(query, limit) when is_integer(limit) and limit > 0 do
    limit(query, ^limit)
  end
end

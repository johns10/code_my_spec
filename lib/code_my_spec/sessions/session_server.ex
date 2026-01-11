defmodule CodeMySpec.Sessions.SessionServer do
  @moduledoc """
  Manages session execution task lifecycle and message delivery.

  One server process per active session, registered by session_id.
  Creates interactions synchronously, then spawns task for execution.
  """
  use GenServer
  require Logger

  alias CodeMySpec.Sessions.{
    CommandResolver,
    InteractionContext,
    Executor,
    ResultHandler,
    Session,
    SessionsBroadcaster,
    SessionsRepository
  }

  @doc """
  Starts a SessionServer for the given session_id.

  Uses GenServer.start (not start_link) so the process isn't linked to the caller.
  The server will be registered via the SessionRegistry.
  """
  def start(session_id) do
    GenServer.start(__MODULE__, session_id, name: via_tuple(session_id))
  end

  # Server Callbacks

  @impl true
  def init(session_id) do
    {:ok, %{session_id: session_id, task: nil, scope: nil}}
  end

  @impl true
  def handle_call({:run, scope, opts}, _from, %{task: nil} = state) do
    Logger.info("SessionServer: Creating interaction for session #{state.session_id}")

    # 1. Create interaction synchronously (before spawning task)
    case CommandResolver.next_command(scope, state.session_id, opts) do
      {:ok, session} ->
        [interaction | _] = session.interactions

        # 2. Build reply with interaction info (will add task_pid after spawning)
        reply_base = %{
          interaction_id: interaction.id,
          command_module: interaction.command.module
        }

        # 3. Spawn ONE task that does full execution cycle
        task = Task.async(fn ->
          Logger.info("SessionServer: Task started, preparing context",
            session_id: state.session_id,
            interaction_id: interaction.id
          )

          with {:ok, context} <- InteractionContext.prepare(scope, session, opts) do
            execution_result = Executor.execute(context)

            # Handle different return types from executor
            {result, merged_opts} = case execution_result do
              # Async execution returns {result, delivered_opts}
              {result, delivered_opts} when is_list(delivered_opts) ->
                {result, Keyword.merge(opts, delivered_opts)}

              # Sync/Task execution returns just result
              result ->
                {result, opts}
            end

            ResultHandler.handle_result(scope, state.session_id, interaction.id, result, merged_opts)
          end
        end)

        Logger.info("SessionServer: Task spawned with pid #{inspect(task.pid)}",
          session_id: state.session_id,
          interaction_id: interaction.id
        )

        # Add task_pid to reply
        reply = Map.put(reply_base, :task_pid, task.pid)

        new_state = %{state | task: task, scope: scope}
        {:reply, {:ok, reply}, new_state}

      {:error, reason} = error ->
        Logger.error("SessionServer: Failed to create interaction",
          session_id: state.session_id,
          reason: inspect(reason)
        )

        {:reply, error, state}
    end
  end

  @impl true
  def handle_call({:run, _scope, _opts}, _from, state) do
    {:reply, {:error, :execution_in_progress}, state}
  end

  @impl true
  def handle_cast({:deliver_result, interaction_id, result, opts}, %{task: %Task{pid: pid}} = state)
      when not is_nil(pid) do
    Logger.info(
      "SessionServer: Delivering result to task #{inspect(pid)} for interaction #{interaction_id}"
    )

    send(pid, {:interaction_result, interaction_id, result, opts})
    {:noreply, state}
  end

  @impl true
  def handle_cast({:deliver_result, interaction_id, _result, _opts}, state) do
    Logger.warning(
      "SessionServer: No task running to deliver result for interaction #{interaction_id}"
    )

    {:noreply, state}
  end

  @impl true
  def handle_info(
        {ref, result},
        %{task: %Task{ref: task_ref}, scope: scope, session_id: session_id} = state
      )
      when ref == task_ref do
    Logger.info(
      "SessionServer: Task completed for session #{session_id} with #{inspect(elem(result, 0))} result"
    )

    # Task completed successfully, we got the result message
    Process.demonitor(ref, [:flush])

    # Broadcast step completion
    case result do
      {:ok, _session} when not is_nil(scope) ->
        Logger.info("SessionServer: Fetching session with interactions")
        # Fetch session with interactions to get the latest one
        session_with_interactions = SessionsRepository.get_session(scope, session_id)

        Logger.info(
          "SessionServer: Got session with #{length(session_with_interactions.interactions)} interactions"
        )

        # Get the latest interaction (the one that was just created/completed)
        case session_with_interactions.interactions do
          [latest | _] ->
            Logger.info("SessionServer: Broadcasting step_completed for interaction #{latest.id}")

            SessionsBroadcaster.broadcast_step_completed(
              scope,
              session_with_interactions,
              latest.id
            )

          _ ->
            Logger.warning("SessionServer: No interactions found, broadcasting generic update")
            # No interactions, fall back to generic update
            SessionsBroadcaster.broadcast_updated(scope, session_with_interactions)
        end

      _ ->
        Logger.warning("SessionServer: Result was not {:ok, session} or scope was nil")
        :ok
    end

    new_state = %{state | task: nil, scope: nil}

    # Check if should auto-continue
    check_auto_continuation(result)

    {:noreply, new_state}
  end

  @impl true
  def handle_info(
        {:DOWN, ref, :process, _pid, reason},
        %{task: %Task{ref: task_ref}} = state
      )
      when ref == task_ref do
    # Task failed
    Logger.error("SessionServer: Task failed",
      session_id: state.session_id,
      reason: inspect(reason)
    )

    new_state = %{state | task: nil, scope: nil}
    {:noreply, new_state}
  end

  @impl true
  def handle_info(:auto_continue, %{session_id: _session_id} = state) do
    # This is a simplified auto-continue trigger
    # In practice, you'd need to have scope available or fetch it
    # For now, this is a placeholder showing the pattern
    # Real implementation would need to:
    # 1. Get the session from DB to get scope info
    # 2. Call execute_step with proper scope
    # For now, we just log that we should continue
    {:noreply, state}
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  # Private Helpers

  defp via_tuple(session_id) do
    {:via, Registry, {CodeMySpec.Sessions.SessionRegistry, session_id}}
  end

  defp check_auto_continuation({:ok, session}) do
    # Check if should continue in auto mode
    # If session is active and has no pending interactions, continue
    if session.execution_mode == :auto and
         session.status == :active and
         Enum.empty?(Session.get_pending_interactions(session)) do
      # Continue the loop by casting to self
      # We'll need scope - for now we rely on it being available in the session/context
      # In practice, the Orchestrator will handle getting the next step
      Process.send_after(self(), :auto_continue, 0)
    end

    :ok
  end

  defp check_auto_continuation(_result), do: :ok
end

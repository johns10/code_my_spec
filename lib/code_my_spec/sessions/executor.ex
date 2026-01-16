defmodule CodeMySpec.Sessions.Executor do
  @moduledoc """
  Executes commands to completion, handling all concurrency patterns.

  Takes an InteractionContext and executes the command, handling:
  - Sync execution (immediate result)
  - Task execution (spawned by command, awaited here)
  - Async execution (external, wait for message)

  Always returns a final result, never a task or :ok.
  """

  alias CodeMySpec.Sessions.InteractionContext
  alias CodeMySpec.Environments

  require Logger

  @doc """
  Execute a command to completion.

  ## Process
  1. Run command via environment
  2. Handle execution result based on what command returned:
     - `{:ok, %Task{}}` - Command spawned task, await it
     - `{:ok, result}` - Sync result, return it
     - `:ok` - Async execution, wait for message
  3. Return final result

  ## Parameters
  - `context` - InteractionContext with command and environment prepared

  ## Returns
  - `result` - Final execution result (map)
  - `{:error, reason}` - Execution failed
  """
  @spec execute(InteractionContext.t()) :: map() | {:error, term()}
  def execute(%InteractionContext{} = context) do
    Logger.info("Executing command",
      session_id: context.session.id,
      interaction_id: context.interaction.id,
      command_module: context.command.module
    )

    # Run command via environment
    execution_result = Environments.run_command(
      context.environment,
      context.command,
      context.execution_opts
    )

    # Handle different execution patterns to completion
    handle_execution_result(execution_result, context)
  end

  # Private functions

  # Command spawned a task - await it
  defp handle_execution_result({:ok, %Task{} = task}, context) do
    Logger.info("Task spawned by command, awaiting completion",
      session_id: context.session.id,
      interaction_id: context.interaction.id,
      task_pid: task.pid
    )

    result = Task.await(task, :infinity)
    normalize_result(result)
  end

  # Sync execution - result available immediately
  defp handle_execution_result({:ok, result}, context) when is_map(result) do
    Logger.info("Sync execution completed",
      session_id: context.session.id,
      interaction_id: context.interaction.id
    )

    normalize_result(result)
  end

  # Async execution - wait for message
  defp handle_execution_result(:ok, context) do
    Logger.info("Async execution started, waiting for result message",
      session_id: context.session.id,
      interaction_id: context.interaction.id
    )

    receive do
      {:interaction_result, interaction_id, result_attrs, _delivered_opts}
      when interaction_id == context.interaction.id ->
        Logger.info("Received async result message",
          session_id: context.session.id,
          interaction_id: context.interaction.id
        )

        normalize_result(result_attrs)
    after
      # Timeout after 30 minutes
      1_800_000 ->
        Logger.error("Timeout waiting for async result",
          session_id: context.session.id,
          interaction_id: context.interaction.id
        )

        {:error, :async_result_timeout}
    end
  end

  # Execution failed
  defp handle_execution_result({:error, reason} = error, context) do
    Logger.error("Execution failed",
      session_id: context.session.id,
      interaction_id: context.interaction.id,
      reason: inspect(reason)
    )

    error
  end

  # Normalize various result formats into a consistent map
  defp normalize_result(result) when is_map(result) do
    # If already in expected format with :status, use as-is
    # Otherwise wrap in standard format
    if Map.has_key?(result, :status) or Map.has_key?(result, "status") do
      result
    else
      %{status: :ok, data: result}
    end
  end

  defp normalize_result({:error, _reason} = error), do: error
end

defmodule CodeMySpec.Sessions.Executor do
  @moduledoc """
  Unified execution for both sync and async session steps.

  Delegates to Orchestrator for command/interaction management,
  then handles execution and result processing.
  """

  alias CodeMySpec.Sessions.{Session, Orchestrator}
  alias CodeMySpec.Environments

  require Logger

  @doc """
  Execute the next step in a session.

  ## Parameters
  - `scope` - User scope
  - `session_id` - Session ID
  - `opts` - Options passed to step's get_command

  ## Returns
  - `{:ok, session}` - Execution result
  - `{:error, reason}` - Execution failed
  """
  def execute(scope, session_id, opts \\ []) do
    with {:ok, session} <- Orchestrator.next_command(scope, session_id, opts),
         {:ok, interaction} <- get_latest_interaction(session),
         {:ok, env} <- create_environment(session),
         result <- Environments.run_command(env, interaction.command) do
      handle_execution_result(scope, session_id, interaction.id, result)
    end
  end

  defp get_latest_interaction(%Session{interactions: []}), do: {:error, :no_interactions}

  defp get_latest_interaction(%Session{interactions: [latest | _]}), do: {:ok, latest}

  defp create_environment(%Session{environment: type, id: session_id}) do
    Environments.create(type, session_id: session_id)
  end

  defp handle_execution_result(scope, session_id, interaction_id, result) do
    case result do
      :ok ->
        # Async execution (CLI) - interaction is pending, waiting for user
        Logger.info("Async step executing in background",
          session_id: session_id,
          interaction_id: interaction_id
        )

        Orchestrator.get_session(scope, session_id)

      {:ok, output} when is_map(output) ->
        # Sync execution - got result, handle immediately
        Logger.info("Sync step completed, processing result",
          session_id: session_id,
          interaction_id: interaction_id
        )

        result_attrs = normalize_result(output)

        CodeMySpec.Sessions.ResultHandler.handle_result(
          scope,
          session_id,
          interaction_id,
          result_attrs
        )

      {:error, reason} ->
        Logger.error("Execution failed",
          session_id: session_id,
          interaction_id: interaction_id,
          reason: reason
        )

        {:error, reason}
    end
  end

  # Terminal execution result - has exit_code
  defp normalize_result(%{exit_code: exit_code} = output) do
    %{
      status: if(exit_code == 0, do: :ok, else: :error),
      stdout: Map.get(output, :stdout),
      stderr: Map.get(output, :stderr),
      code: exit_code
    }
  end

  # Data result (e.g., from read_file, list_directory, or empty commands)
  defp normalize_result(output) when is_map(output) do
    %{
      status: :ok,
      data: output
    }
  end
end

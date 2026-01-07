defmodule CodeMySpec.Sessions.Executor do
  @moduledoc """
  Unified execution for both sync and async session steps.

  Delegates to CommandResolver for command/interaction management,
  then handles execution and result processing.
  """

  alias CodeMySpec.Sessions.{Session, CommandResolver}
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
  def execute_command(scope, session_id, opts \\ []) do
    with {:ok, session} <- CommandResolver.next_command(scope, session_id, opts),
         {:ok, interaction} <- get_latest_interaction(session),
         {:ok, env} <- create_environment(session),
         result <-
           Environments.run_command(env, interaction.command,
             session_id: session.id,
             interaction_id: interaction.id
           ) do
      case result do
        :ok ->
          # Async execution (CLI) - interaction is pending, waiting for user
          Logger.info("Async step #{interaction.command.module} executing in background",
            session_id: session_id,
            interaction_id: interaction.id
          )

          CommandResolver.get_session(scope, session_id)

        {:ok, output} ->
          # Sync execution - got result, handle immediately
          Logger.info("Sync step completed, processing result",
            session_id: session_id,
            interaction_id: interaction.id
          )

          CodeMySpec.Sessions.ResultHandler.handle_result(
            scope,
            session_id,
            interaction.id,
            %{status: :ok, data: output},
            opts
          )

        {:error, reason} ->
          Logger.error("Execution failed",
            session_id: session_id,
            interaction_id: interaction.id,
            reason: reason
          )

          {:error, reason}
      end
    end
  end

  defp get_latest_interaction(%Session{interactions: []}), do: {:error, :no_interactions}

  defp get_latest_interaction(%Session{interactions: [latest | _]}), do: {:ok, latest}

  defp create_environment(%Session{environment: type, id: session_id, state: state}) do
    opts = [session_id: session_id]

    opts =
      if state && Map.has_key?(state, "working_dir"),
        do: Keyword.put(opts, :working_dir, state["working_dir"]),
        else: opts

    Environments.create(type, opts)
  end
end

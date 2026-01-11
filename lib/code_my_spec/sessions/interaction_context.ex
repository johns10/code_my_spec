defmodule CodeMySpec.Sessions.InteractionContext do
  @moduledoc """
  Context prepared for executing an interaction.

  Contains all necessary information for command execution including
  the environment, command details, and execution options.
  """

  alias CodeMySpec.Sessions.{Session, Interaction}
  alias CodeMySpec.Users.Scope

  defstruct [:environment, :command, :execution_opts, :session, :interaction]

  @type t :: %__MODULE__{
          environment: module(),
          command: struct(),
          execution_opts: keyword(),
          session: Session.t(),
          interaction: Interaction.t()
        }

  @doc """
  Prepares the execution context for an interaction.

  ## Parameters
  - `scope` - User scope
  - `session` - Session with interactions preloaded
  - `opts` - Execution options

  ## Returns
  - `{:ok, %InteractionContext{}}` - Context prepared successfully
  - `{:error, reason}` - Preparation failed
  """
  @spec prepare(Scope.t(), Session.t(), keyword()) :: {:ok, t()} | {:error, term()}
  def prepare(%Scope{} = _scope, %Session{} = session, opts \\ []) do
    with {:ok, interaction} <- get_latest_interaction(session),
         {:ok, environment} <- create_environment(session, interaction),
         command <- interaction.command do
      # Build execution options with session and interaction context
      execution_opts = opts
      |> Keyword.put(:session_id, session.id)
      |> Keyword.put(:interaction_id, interaction.id)

      context = %__MODULE__{
        environment: environment,
        command: command,
        execution_opts: execution_opts,
        session: session,
        interaction: interaction
      }

      {:ok, context}
    end
  end

  # Private functions

  defp get_latest_interaction(%Session{interactions: []}), do: {:error, :no_interactions}
  defp get_latest_interaction(%Session{interactions: [latest | _]}), do: {:ok, latest}

  # Create execution environment from session configuration
  defp create_environment(%Session{environment: type, id: session_id, state: state}, _interaction) do
    alias CodeMySpec.Environments

    opts = [session_id: session_id]

    opts =
      if state && Map.has_key?(state, "working_dir") do
        Keyword.put(opts, :working_dir, state["working_dir"])
      else
        opts
      end

    Environments.create(type, opts)
  end
end

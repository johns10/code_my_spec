defmodule CodeMySpec.ContextTestingSessions.Orchestrator do
  @moduledoc """
  Stateless orchestrator for context testing session workflows.

  Determines the next step in the context testing workflow based on
  the current interaction's result and module. Handles validation loops by
  cycling between SpawnComponentTestingSessions (which validates child sessions)
  and itself if validation fails.
  """

  @behaviour CodeMySpec.Sessions.OrchestratorBehaviour

  alias CodeMySpec.Sessions.{Result, Interaction, Utils, Session}
  alias CodeMySpec.ContextTestingSessions.Steps

  @steps [
    Steps.Initialize,
    Steps.SpawnComponentTestingSessions,
    Steps.Finalize
  ]

  @impl true
  @spec steps() :: [module()]
  def steps, do: @steps

  @impl true
  def complete?(%Session{interactions: [last_interaction | _]}), do: complete?(last_interaction)

  @impl true
  def complete?(%Interaction{command: %{module: Steps.Finalize}, result: %Result{status: :ok}}),
    do: true

  def complete?(%Interaction{}), do: false

  @impl true
  def get_next_interaction(nil), do: {:ok, Steps.Initialize}

  @impl true
  def get_next_interaction(%Session{} = session) do
    with %Interaction{} = interaction <- Utils.find_last_completed_interaction(session) do
      status = extract_status(interaction)
      module = interaction.command.module

      route(module, status)
    else
      nil -> {:ok, hd(@steps)}
    end
  end

  defp extract_status(%Interaction{result: %Result{status: status}}), do: status

  # Initialize routes
  defp route(Steps.Initialize, :ok), do: {:ok, Steps.SpawnComponentTestingSessions}
  defp route(Steps.Initialize, _), do: {:ok, Steps.Initialize}

  # SpawnComponentTestingSessions routes
  # On success, all child sessions completed and validated successfully -> Finalize
  # On error, validation failed (child sessions failed/cancelled or still running) -> retry SpawnComponentTestingSessions
  defp route(Steps.SpawnComponentTestingSessions, :ok), do: {:ok, Steps.Finalize}

  defp route(Steps.SpawnComponentTestingSessions, :error),
    do: {:ok, Steps.SpawnComponentTestingSessions}

  defp route(Steps.SpawnComponentTestingSessions, _),
    do: {:ok, Steps.SpawnComponentTestingSessions}

  # Finalize routes
  defp route(Steps.Finalize, :ok), do: {:error, :session_complete}
  defp route(Steps.Finalize, _), do: {:ok, Steps.Finalize}

  # Catch-all for invalid states
  defp route(step, _status) when step in @steps, do: {:error, :invalid_state}
  defp route(_step, _status), do: {:error, :invalid_interaction}
end

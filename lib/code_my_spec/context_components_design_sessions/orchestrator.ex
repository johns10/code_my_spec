defmodule CodeMySpec.ContextComponentsDesignSessions.Orchestrator do
  @moduledoc """
  Stateless orchestrator for context component design session workflows.

  Manages the sequence of steps for designing all components within a context,
  including child session spawning and validation loops. All state lives in the
  Session record and its embedded Interactions.
  """

  @behaviour CodeMySpec.Sessions.OrchestratorBehaviour

  alias CodeMySpec.Sessions.{Interaction, Result, Utils, Session}
  alias CodeMySpec.ContextComponentsDesignSessions.Steps

  @step_modules [
    Steps.Initialize,
    Steps.SpawnComponentSpecSessions,
    Steps.SpawnReviewSession,
    Steps.Finalize
  ]

  @impl true
  def steps(), do: @step_modules

  @impl true
  def complete?(%Session{interactions: [last_interaction | _]}), do: complete?(last_interaction)

  @impl true
  def complete?(%Interaction{command: %{module: Steps.Finalize}, result: %Result{status: :ok}}),
    do: true

  def complete?(%Interaction{}), do: false

  @impl true
  def get_next_interaction(%Session{} = session) do
    with %Interaction{} = interaction <- Utils.find_last_completed_interaction(session) do
      status = extract_status(interaction)
      module = interaction.command.module

      get_next_step(status, module)
    else
      nil -> {:ok, hd(@step_modules)}
    end
  end

  defp extract_status(%Interaction{result: %Result{status: status}}), do: status

  # Initialize step transitions
  defp get_next_step(:ok, Steps.Initialize), do: {:ok, Steps.SpawnComponentSpecSessions}
  defp get_next_step(_, Steps.Initialize), do: {:ok, Steps.Initialize}

  # SpawnComponentSpecSessions step transitions with validation loop
  defp get_next_step(:ok, Steps.SpawnComponentSpecSessions),
    do: {:ok, Steps.SpawnReviewSession}

  defp get_next_step(:error, Steps.SpawnComponentSpecSessions),
    do: {:ok, Steps.SpawnComponentSpecSessions}

  defp get_next_step(_, Steps.SpawnComponentSpecSessions),
    do: {:ok, Steps.SpawnComponentSpecSessions}

  # SpawnReviewSession step transitions with validation loop
  defp get_next_step(:ok, Steps.SpawnReviewSession), do: {:ok, Steps.Finalize}

  defp get_next_step(:error, Steps.SpawnReviewSession),
    do: {:ok, Steps.SpawnReviewSession}

  defp get_next_step(_, Steps.SpawnReviewSession), do: {:ok, Steps.SpawnReviewSession}

  # Finalize step transitions
  defp get_next_step(:ok, Steps.Finalize), do: {:error, :session_complete}
  defp get_next_step(_, Steps.Finalize), do: {:ok, Steps.Finalize}

  # Error handling for invalid states
  defp get_next_step(_status, module) when module not in @step_modules,
    do: {:error, :invalid_interaction}

  defp get_next_step(_status, _module), do: {:error, :invalid_state}
end

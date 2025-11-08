defmodule CodeMySpec.ContextDesignReviewSessions.Orchestrator do
  @moduledoc """
  Stateless orchestrator managing the sequence of context design review steps.

  Coordinates the execution flow between ExecuteReview and Finalize steps,
  determining the next interaction based on session state and handling session
  completion logic. All workflow state is persisted through the Sessions context
  via embedded Interactions in Session records.
  """

  @behaviour CodeMySpec.Sessions.OrchestratorBehaviour

  alias CodeMySpec.Sessions.{Interaction, Result, Utils, Session}
  alias CodeMySpec.ContextDesignReviewSessions.Steps

  @step_modules [
    Steps.ExecuteReview,
    Steps.Finalize
  ]

  @impl true
  def steps(), do: @step_modules

  @impl true
  def complete?(%Session{interactions: [last_interaction | _]}), do: complete?(last_interaction)
  def complete?(%Session{interactions: []}), do: false

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

  # After ExecuteReview succeeds, move to Finalize
  defp get_next_step(:ok, Steps.ExecuteReview), do: {:ok, Steps.Finalize}

  # After ExecuteReview fails, retry ExecuteReview
  defp get_next_step(:error, Steps.ExecuteReview), do: {:ok, Steps.ExecuteReview}

  # Any other status on ExecuteReview, retry
  defp get_next_step(_, Steps.ExecuteReview), do: {:ok, Steps.ExecuteReview}

  # After Finalize completes (success or error), session is complete
  defp get_next_step(:ok, Steps.Finalize), do: {:error, :session_complete}
  defp get_next_step(:error, Steps.Finalize), do: {:error, :session_complete}
  defp get_next_step(_, Steps.Finalize), do: {:error, :session_complete}

  # Unknown module not in steps list
  defp get_next_step(_status, module) when module not in @step_modules,
    do: {:error, :invalid_interaction}

  # Invalid state - unknown combination
  defp get_next_step(_status, _module), do: {:error, :invalid_state}
end

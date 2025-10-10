defmodule CodeMySpec.ContextDesignSessions.Orchestrator do
  @moduledoc """
  Stateless orchestrator for context design session workflows.
  All state lives in the Session record and its embedded Interactions.
  """

  @behaviour CodeMySpec.Sessions.OrchestratorBehaviour

  alias CodeMySpec.Sessions.{Interaction, Result, Utils, Session}
  alias CodeMySpec.ContextDesignSessions.Steps

  @step_modules [
    Steps.Initialize,
    Steps.GenerateContextDesign,
    Steps.ValidateDesign,
    Steps.ReviseDesign,
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

  defp get_next_step(:ok, Steps.Initialize), do: {:ok, Steps.GenerateContextDesign}
  defp get_next_step(_, Steps.Initialize), do: {:ok, Steps.Initialize}

  defp get_next_step(:ok, Steps.GenerateContextDesign), do: {:ok, Steps.ValidateDesign}
  defp get_next_step(_, Steps.GenerateContextDesign), do: {:ok, Steps.GenerateContextDesign}

  defp get_next_step(:ok, Steps.ValidateDesign), do: {:ok, Steps.Finalize}
  defp get_next_step(:error, Steps.ValidateDesign), do: {:ok, Steps.ReviseDesign}
  defp get_next_step(_, Steps.ValidateDesign), do: {:ok, Steps.ValidateDesign}

  defp get_next_step(:ok, Steps.ReviseDesign), do: {:ok, Steps.ValidateDesign}
  defp get_next_step(_, Steps.ReviseDesign), do: {:ok, Steps.ReviseDesign}

  defp get_next_step(:ok, Steps.Finalize), do: {:error, :session_complete}

  defp get_next_step(_status, module) when module not in @step_modules,
    do: {:error, :invalid_interaction}

  defp get_next_step(_status, _module), do: {:error, :invalid_state}
end

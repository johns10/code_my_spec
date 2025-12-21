defmodule CodeMySpec.ComponentDesignSessions.Orchestrator do
  @moduledoc """
  Stateless orchestrator for component design session workflows.
  All state lives in the Session record and its embedded Interactions.
  """

  @behaviour CodeMySpec.Sessions.OrchestratorBehaviour

  alias CodeMySpec.Sessions.{Interaction, Result, Utils, Session}
  alias CodeMySpec.ComponentDesignSessions.Steps

  @step_modules [
    Steps.Initialize,
    Steps.GenerateComponentSpec,
    Steps.ValidateSpec,
    Steps.ReviseSpec,
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

  defp get_next_step(:ok, Steps.Initialize), do: {:ok, Steps.GenerateComponentSpec}
  defp get_next_step(_, Steps.Initialize), do: {:ok, Steps.Initialize}

  defp get_next_step(:ok, Steps.GenerateComponentSpec), do: {:ok, Steps.ValidateSpec}
  defp get_next_step(_, Steps.GenerateComponentSpec), do: {:ok, Steps.GenerateComponentSpec}

  defp get_next_step(:ok, Steps.ValidateSpec), do: {:ok, Steps.Finalize}
  defp get_next_step(:error, Steps.ValidateSpec), do: {:ok, Steps.ReviseSpec}
  defp get_next_step(_, Steps.ValidateSpec), do: {:ok, Steps.ValidateSpec}

  defp get_next_step(:ok, Steps.ReviseSpec), do: {:ok, Steps.ValidateSpec}
  defp get_next_step(_, Steps.ReviseSpec), do: {:ok, Steps.ReviseSpec}

  defp get_next_step(:ok, Steps.Finalize), do: {:error, :session_complete}

  defp get_next_step(_status, module) when module not in @step_modules,
    do: {:error, :invalid_interaction}

  defp get_next_step(_status, _module), do: {:error, :invalid_state}
end

defmodule CodeMySpec.ComponentDesignSessions.Orchestrator do
  @moduledoc """
  Stateless orchestrator for component design session workflows.
  All state lives in the Session record and its embedded Interactions.
  """

  alias CodeMySpec.Sessions.{Interaction, Result, Utils, Session}
  alias CodeMySpec.ComponentDesignSessions.Steps

  @step_modules [
    Steps.Initialize,
    Steps.ReadContextDesign,
    Steps.GenerateComponentDesign,
    Steps.ValidateDesign,
    Steps.ReviseDesign,
    Steps.Finalize
  ]

  def steps(), do: @step_modules

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

  defp get_next_step(:ok, Steps.Initialize), do: {:ok, Steps.ReadContextDesign}
  defp get_next_step(_, Steps.Initialize), do: {:ok, Steps.Initialize}

  defp get_next_step(:ok, Steps.ReadContextDesign), do: {:ok, Steps.GenerateComponentDesign}
  defp get_next_step(_, Steps.ReadContextDesign), do: {:ok, Steps.ReadContextDesign}

  defp get_next_step(:ok, Steps.GenerateComponentDesign), do: {:ok, Steps.ValidateDesign}
  defp get_next_step(_, Steps.GenerateComponentDesign), do: {:ok, Steps.GenerateComponentDesign}

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

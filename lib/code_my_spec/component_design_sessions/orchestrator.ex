defmodule CodeMySpec.ComponentDesignSessions.Orchestrator do
  @moduledoc """
  Stateless orchestrator for component design session workflows.
  All state lives in the Session record and its embedded Interactions.
  """

  alias CodeMySpec.Sessions.{Interaction, Result}
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

  def get_next_interaction(nil), do: {:ok, hd(@step_modules)}

  def get_next_interaction(%Interaction{} = interaction) do
    status = extract_status(interaction)
    module = interaction.command.module

    get_next_step(status, module)
  end

  defp extract_status(%Interaction{result: nil}), do: :pending
  defp extract_status(%Interaction{result: %Result{status: :ok}}), do: :success
  defp extract_status(%Interaction{result: %Result{status: :error}}), do: :error

  defp get_next_step(:success, Steps.Initialize), do: {:ok, Steps.ReadContextDesign}
  defp get_next_step(_, Steps.Initialize), do: {:ok, Steps.Initialize}

  defp get_next_step(:success, Steps.ReadContextDesign), do: {:ok, Steps.GenerateComponentDesign}
  defp get_next_step(_, Steps.ReadContextDesign), do: {:ok, Steps.ReadContextDesign}

  defp get_next_step(:success, Steps.GenerateComponentDesign), do: {:ok, Steps.ValidateDesign}
  defp get_next_step(_, Steps.GenerateComponentDesign), do: {:ok, Steps.GenerateComponentDesign}

  defp get_next_step(:success, Steps.ValidateDesign), do: {:ok, Steps.Finalize}
  defp get_next_step(:error, Steps.ValidateDesign), do: {:ok, Steps.ReviseDesign}
  defp get_next_step(_, Steps.ValidateDesign), do: {:ok, Steps.ValidateDesign}

  defp get_next_step(:success, Steps.ReviseDesign), do: {:ok, Steps.ValidateDesign}
  defp get_next_step(_, Steps.ReviseDesign), do: {:ok, Steps.ReviseDesign}

  defp get_next_step(:success, Steps.Finalize), do: {:error, :session_complete}

  defp get_next_step(_status, module) when module not in @step_modules,
    do: {:error, :invalid_interaction}

  defp get_next_step(_status, _module), do: {:error, :invalid_state}
end

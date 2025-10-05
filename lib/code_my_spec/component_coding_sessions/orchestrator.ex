defmodule CodeMySpec.ComponentCodingSessions.Orchestrator do
  @moduledoc """
  Stateless orchestrator for component coding session workflows.

  Determines the next step in the implementation workflow based on
  the current interaction's result and module. Handles test failure loops by
  cycling between RunTests and FixTestFailures.
  """

  alias CodeMySpec.Sessions.{Result, Interaction, Utils, Session}
  alias CodeMySpec.ComponentCodingSessions.Steps

  @steps [
    Steps.Initialize,
    Steps.GenerateImplementation,
    Steps.RunTests,
    Steps.FixTestFailures,
    Steps.Finalize
  ]

  @spec steps() :: [module()]
  def steps, do: @steps

  @spec get_next_interaction(nil) :: {:ok, module()}
  def get_next_interaction(nil), do: {:ok, Steps.Initialize}

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

  defp route(Steps.Initialize, :ok), do: {:ok, Steps.GenerateImplementation}
  defp route(Steps.Initialize, _), do: {:ok, Steps.Initialize}

  defp route(Steps.GenerateImplementation, :ok), do: {:ok, Steps.RunTests}
  defp route(Steps.GenerateImplementation, _), do: {:ok, Steps.GenerateImplementation}

  defp route(Steps.RunTests, :ok), do: {:ok, Steps.Finalize}
  defp route(Steps.RunTests, :error), do: {:ok, Steps.FixTestFailures}
  defp route(Steps.RunTests, _), do: {:ok, Steps.RunTests}

  defp route(Steps.FixTestFailures, :ok), do: {:ok, Steps.RunTests}
  defp route(Steps.FixTestFailures, _), do: {:ok, Steps.FixTestFailures}

  defp route(Steps.Finalize, :ok), do: {:error, :session_complete}

  defp route(step, _status) when step in @steps, do: {:error, :invalid_state}
  defp route(_step, _status), do: {:error, :invalid_interaction}
end

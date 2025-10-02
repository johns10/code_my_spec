defmodule CodeMySpec.ComponentCodingSessions.Orchestrator do
  @moduledoc """
  Stateless orchestrator for component coding session workflows.

  Determines the next step in the test-driven development workflow based on
  the current interaction's result and module. Handles test failure loops by
  cycling between RunTests and FixTestFailures.
  """

  alias CodeMySpec.Sessions.Result
  alias CodeMySpec.Sessions.Interaction

  alias CodeMySpec.ComponentCodingSessions.Steps.{
    Initialize,
    ReadComponentDesign,
    GenerateTests,
    GenerateImplementation,
    RunTests,
    FixTestFailures,
    Finalize
  }

  @steps [
    Initialize,
    ReadComponentDesign,
    AnalyzeAndGenerateFixtures,
    GenerateTests,
    GenerateImplementation,
    RunTests,
    FixTestFailures,
    Finalize
  ]

  @spec steps() :: [module()]
  def steps, do: @steps

  @spec get_next_interaction(nil) :: {:ok, module()}
  def get_next_interaction(nil), do: {:ok, Initialize}

  @spec get_next_interaction(Interaction.t()) ::
          {:ok, module()} | {:error, :session_complete | :invalid_interaction | :invalid_state}
  def get_next_interaction(%Interaction{} = interaction) do
    status = extract_status(interaction)
    module = interaction.command.module
    route(module, status)
  end

  defp extract_status(%Interaction{result: %Result{status: status}}), do: status

  defp route(Initialize, :ok), do: {:ok, ReadComponentDesign}
  defp route(Initialize, _), do: {:ok, Initialize}

  defp route(ReadComponentDesign, :ok), do: {:ok, GenerateTests}
  defp route(ReadComponentDesign, _), do: {:ok, ReadComponentDesign}

  defp route(GenerateTests, :ok), do: {:ok, GenerateImplementation}
  defp route(GenerateTests, _), do: {:ok, GenerateTests}

  defp route(GenerateImplementation, :ok), do: {:ok, RunTests}
  defp route(GenerateImplementation, _), do: {:ok, GenerateImplementation}

  defp route(RunTests, :ok), do: {:ok, Finalize}
  defp route(RunTests, :error), do: {:ok, FixTestFailures}

  defp route(FixTestFailures, :ok), do: {:ok, RunTests}
  defp route(FixTestFailures, _), do: {:ok, FixTestFailures}

  defp route(Finalize, :ok), do: {:error, :session_complete}

  defp route(step, _status) when step in @steps, do: {:error, :invalid_state}
  defp route(_step, _status), do: {:error, :invalid_interaction}
end

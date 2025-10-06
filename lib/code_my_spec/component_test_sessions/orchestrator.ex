defmodule CodeMySpec.ComponentTestSessions.Orchestrator do
  @moduledoc """
  Stateless orchestrator for component test session workflows.
  All state lives in the Session record and its embedded Interactions.
  """

  alias CodeMySpec.Sessions.{Interaction, Result, Utils, Session}
  alias CodeMySpec.ComponentTestSessions.Steps

  @step_modules [
    Steps.Initialize,
    Steps.GenerateTestsAndFixtures,
    Steps.RunTests,
    Steps.FixCompilationErrors,
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

  defp get_next_step(:ok, Steps.Initialize), do: {:ok, Steps.GenerateTestsAndFixtures}
  defp get_next_step(_, Steps.Initialize), do: {:ok, Steps.Initialize}

  defp get_next_step(:ok, Steps.GenerateTestsAndFixtures), do: {:ok, Steps.RunTests}
  defp get_next_step(_, Steps.GenerateTestsAndFixtures), do: {:ok, Steps.GenerateTestsAndFixtures}

  defp get_next_step(:ok, Steps.RunTests), do: {:ok, Steps.Finalize}
  defp get_next_step(:error, Steps.RunTests), do: {:ok, Steps.FixCompilationErrors}
  defp get_next_step(_, Steps.RunTests), do: {:ok, Steps.RunTests}

  defp get_next_step(:ok, Steps.FixCompilationErrors), do: {:ok, Steps.RunTests}
  defp get_next_step(_, Steps.FixCompilationErrors), do: {:ok, Steps.FixCompilationErrors}

  defp get_next_step(:ok, Steps.Finalize), do: {:error, :session_complete}

  defp get_next_step(_status, module) when module not in @step_modules,
    do: {:error, :invalid_interaction}

  defp get_next_step(_status, _module), do: {:error, :invalid_state}
end

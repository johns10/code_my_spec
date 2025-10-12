defmodule CodeMySpec.ComponentTestSessions.Steps.FixCompilationErrors do
  @behaviour CodeMySpec.Sessions.StepBehaviour

  alias CodeMySpec.Sessions.Steps.Helpers

  @impl true
  def get_command(scope, session, opts \\ []) do
    with {:ok, test_failures} <- get_test_failures_from_previous_interaction(scope, session),
         prompt <- build_fix_prompt(test_failures),
         {:ok, command} <-
           Helpers.build_agent_command(
             __MODULE__,
             :test_writer,
             "component-test-error-fixer",
             prompt,
             Keyword.put(opts, :continue, true)
           ) do
      {:ok, command}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def handle_result(_scope, _session, result, _opts \\ []) do
    {:ok, %{}, result}
  end

  defp get_test_failures_from_previous_interaction(_scope, session) do
    case Enum.find(session.interactions, fn
           %{result: %{status: :error}} -> true
           _ -> false
         end) do
      %{result: %{error_message: failures}} when is_binary(failures) ->
        {:ok, failures}

      nil ->
        {:error, "no test failures found in previous interactions"}

      _ ->
        {:error, "test failures not accessible"}
    end
  end

  defp build_fix_prompt(test_failures) do
    """
    The tests failed with the following output:

    #{test_failures}

    Please fix the issues causing the test failures.
    """
  end
end

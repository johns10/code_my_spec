defmodule CodeMySpec.ComponentCodingSessions.Steps.FixTestFailures do
  @behaviour CodeMySpec.Sessions.StepBehaviour

  alias CodeMySpec.{Agents}
  alias CodeMySpec.Sessions.Command

  @impl true
  def get_command(scope, session, _opts \\ []) do
    with {:ok, test_failures} <- get_test_failures_from_previous_interaction(scope, session),
         {:ok, agent} <-
           Agents.create_agent(:unit_coder, "component-code-reviser", :claude_code),
         prompt <- build_fix_prompt(test_failures),
         {:ok, command_args} <- Agents.build_command_string(agent, prompt, %{"continue" => true}) do
      [prompt | command] = Enum.reverse(command_args)

      {:ok, Command.new(__MODULE__, command |> Enum.reverse() |> Enum.join(" "), prompt)}
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

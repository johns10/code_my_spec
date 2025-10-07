defmodule CodeMySpec.ComponentTestSessions.Steps.RunTests do
  @moduledoc """
  Test execution step for component test generation sessions.

  ## Design

  This step runs generated tests to verify they compile and execute properly.
  Unlike coding sessions, test failures are EXPECTED in test generation sessions
  following TDD principles - we're validating that tests are syntactically correct
  and will fail before implementation exists.

  ### Success Criteria
  - Tests compile without errors
  - Test runner executes successfully
  - Test results can be parsed from JSON output
  - Test run data validates against TestRun schema

  ### Error Conditions
  - Compilation failures
  - Malformed test output
  - Invalid JSON from test formatter
  - Test runner crashes

  Test failures (assertions failing) are NOT treated as errors - they're the
  expected state for newly generated tests in a TDD workflow.
  """

  @behaviour CodeMySpec.Sessions.StepBehaviour

  alias CodeMySpec.Sessions.{Command}
  alias CodeMySpec.{Sessions, Utils}
  alias CodeMySpec.Tests.TestRun
  require Logger

  def get_command(_scope, %{component: component, project: project}, opts) do
    %{test_file: test_file_path} = Utils.component_files(component, project)
    seed = if Keyword.get(opts, :seed, false), do: " --seed #{opts[:seed]}", else: ""
    command = "mix test #{test_file_path} --formatter ExUnitJsonFormatter" <> seed
    {:ok, Command.new(__MODULE__, command)}
  end

  def handle_result(scope, _session, result, _opts \\ []) do
    with {:ok, test_run_data} <- get_test_run_data(result),
         {:ok, test_run} <- validate_test_run(test_run_data),
         {:ok, result_with_test_run} <- Sessions.update_result(scope, result, %{data: test_run}) do
      state_updates = %{"test_run" => test_run}

      case test_run.stats do
        %{failures: failures, passes: 0} when failures > 0 ->
          {:ok, state_updates, result_with_test_run}

        %{failures: 0, passes: passes} when passes > 0 ->
          error_message = """
          Some tests are passing, but these tests are written against a non-existent module
          Ensure you are not calling components of the module, or non-applicable functions
          """

          updated_result = update_result_error(scope, result_with_test_run, error_message)
          {:ok, state_updates, updated_result}
      end
    else
      {:error, "invalid JSON in stdout"} ->
        updated_result = update_result_error(scope, result, result.stdout)
        {:ok, %{}, updated_result}

      {:error, reason} ->
        error_message = "Failed to parse test results: #{inspect(reason)}"
        updated_result = update_result_error(scope, result, error_message)
        {:ok, %{}, updated_result}
    end
  end

  defp get_test_run_data(%{data: data}) when is_map(data) and map_size(data) > 0, do: {:ok, data}

  defp get_test_run_data(%{stdout: stdout}) when is_binary(stdout) do
    json_string = extract_json_from_stdout(stdout)

    case Jason.decode(json_string) do
      {:ok, data} -> {:ok, data}
      {:error, _} -> {:error, "invalid JSON in stdout"}
    end
  end

  defp get_test_run_data(_result), do: {:error, "test run data not found in result"}

  defp extract_json_from_stdout(stdout) do
    # Extract JSON part from stdout (filter out compilation messages)
    # Search for {" to find start of JSON object (not Elixir tuples like {:ok, ...})
    json_start = :binary.match(stdout, "{\"")
    json_end_match = :binary.matches(stdout, "}")

    case {json_start, json_end_match} do
      {:nomatch, _} ->
        ""

      {_, []} ->
        ""

      {{start_pos, _}, matches} ->
        # Get the last "}" position
        {end_pos, _} = List.last(matches)
        json_end = end_pos + 1

        if start_pos >= json_end do
          ""
        else
          # Use binary_part since we're working with byte positions
          :binary.part(stdout, start_pos, json_end - start_pos)
        end
    end
  end

  defp validate_test_run(test_run_data) do
    case TestRun.changeset(%TestRun{}, test_run_data) do
      %{valid?: true} = changeset ->
        {:ok, Ecto.Changeset.apply_changes(changeset)}

      %{valid?: false} = changeset ->
        errors =
          changeset.errors
          |> Enum.map(fn {field, {message, _opts}} -> "#{field}: #{message}" end)
          |> Enum.join(", ")

        {:error, errors}
    end
  end

  defp update_result_error(scope, result, error_message) do
    attrs = %{status: :error, error_message: error_message}

    case Sessions.update_result(scope, result, attrs) do
      {:ok, updated} ->
        updated

      {:error, changeset} ->
        Logger.error("#{__MODULE__} failed to update result", changeset: changeset)
        result
    end
  end
end

defmodule CodeMySpec.ComponentTestSessions.Steps.RunTests do
  @behaviour CodeMySpec.Sessions.StepBehaviour

  alias CodeMySpec.Sessions.{Command}
  alias CodeMySpec.{Sessions, Tests, Utils}
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

      test_run
      |> Map.get(:stats)
      |> Map.get(:failures)
      |> case do
        0 ->
          {:ok, state_updates, result_with_test_run}

        count when count > 0 ->
          error_message = format_test_failures(test_run)
          updated_result = update_result_error(scope, result_with_test_run, error_message)
          {:ok, state_updates, updated_result}
      end
    else
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

  defp format_test_failures(%TestRun{failures: failures} = test_run) do
    failure_count = length(failures)

    failure_details =
      failures
      |> Enum.map(fn failure ->
        error_detail =
          case failure.error do
            %Tests.TestError{message: message} ->
              "Error: #{message}"

            nil ->
              "No error details available"
          end

        "#{failure.full_title}\n#{error_detail}"
      end)
      |> Enum.join("\n\n")

    """
    Test execution status: #{test_run.execution_status}
    #{failure_count} test(s) failed:

    #{failure_details}
    """
  end
end

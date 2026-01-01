defmodule CodeMySpec.ComponentCodingSessions.Steps.RunTests do
  @behaviour CodeMySpec.Sessions.StepBehaviour

  alias CodeMySpec.Sessions.{Command}
  alias CodeMySpec.{Sessions, Tests, Utils}
  alias CodeMySpec.Tests.TestRun
  require Logger

  def get_command(_scope, %{component: component, project: project}, opts) do
    %{test_file: test_file_path} = Utils.component_files(component, project)

    base_args = ["test", test_file_path, "--formatter", "ExUnitJsonFormatter"]

    args =
      case Keyword.get(opts, :seed) do
        nil -> base_args
        seed -> base_args ++ ["--seed", to_string(seed)]
      end

    {:ok, Command.new(__MODULE__, "mix_test", metadata: %{args: args})}
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

  defp get_test_run_data(%{stdout: test_results}) when is_binary(test_results) do
    case Jason.decode(test_results) do
      {:ok, data} ->
        {:ok, data}

      {:error, _} ->
        {:error,
         "Found JSON-like output but failed to parse. Extracted: #{String.slice(test_results, 0..200)}..."}
    end
  end

  defp get_test_run_data(_result), do: {:error, "test run data not found in result"}

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

defmodule CodeMySpec.Quality.Tdd do
  @moduledoc """
  Validates test execution state for TDD workflows.

  Handles parsing test results, validating test run data, and checking that
  tests are in the expected state (all failing for TDD test generation).
  """

  alias CodeMySpec.Quality.Result
  alias CodeMySpec.Tests.TestRun

  @doc """
  Checks test execution state from a command result.

  Parses test results, validates the test run data, and ensures all tests
  are failing (correct TDD state for test generation).

  Returns a binary score:
  - 1.0 if all tests are failing (correct TDD state)
  - 0.0 if validation fails or any tests are passing

  ## Examples

      iex> result = %{data: %{test_results: valid_json_with_failures}}
      iex> check_tdd_state(result)
      %Result{score: 1.0, errors: []}
  """
  def check_tdd_state(result, opts \\ []) do
    with full_tdd_mode = Keyword.get(opts, :tdd_mode, true),
         {:ok, test_run_data} <- get_test_run_data(result),
         {:ok, test_run} <- validate_test_run(test_run_data),
         :ok <- verify(test_run, full_tdd_mode) do
      Result.ok()
    else
      {:error, errors} when is_list(errors) ->
        Result.error(errors)

      {:error, error} ->
        Result.error([error])
    end
  end

  defp get_test_run_data(%{data: %{test_results: test_results}}) when is_binary(test_results) do
    case Jason.decode(test_results) do
      {:ok, data} ->
        {:ok, data}

      {:error, _error} ->
        {:error, "Invalid JSON in test results output"}
    end
  end

  defp get_test_run_data(%{data: data}) when is_map(data) and map_size(data) > 0,
    do: {:ok, data}

  defp get_test_run_data(_result), do: {:error, "Test run data not found in result"}

  defp validate_test_run(test_run_data) do
    case TestRun.changeset(%TestRun{}, test_run_data) do
      %{valid?: true} = changeset ->
        {:ok, Ecto.Changeset.apply_changes(changeset)}

      %{valid?: false} = changeset ->
        errors =
          changeset.errors
          |> Enum.map(fn {field, {message, _opts}} -> "#{field}: #{message}" end)

        {:error, errors}
    end
  end

  defp verify(%TestRun{stats: %{failures: _failures, passes: _passes}}, false) do
    :ok
  end

  defp verify(%TestRun{stats: %{failures: failures, passes: 0}}, true)
       when failures > 0 do
    :ok
  end

  defp verify(%TestRun{stats: %{failures: _, passes: passes}}, true) when passes > 0 do
    {:error,
     """
     #{passes} test(s) are passing, but these tests are written against a non-existent module.
     Ensure you are not calling components of the module, or non-applicable functions.
     All tests should be failing in TDD mode before implementation exists.
     """}
  end

  defp verify(%TestRun{stats: %{failures: 0, passes: 0}}, _) do
    {:error, "No tests were executed"}
  end
end

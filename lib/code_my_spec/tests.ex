defmodule CodeMySpec.Tests do
  @moduledoc """
  Tests context for executing and parsing ExUnit test results.
  Provides a clean functional interface for test execution and result analysis.
  """

  alias CodeMySpec.Tests.{CommandBuilder, ProcessExecutor, JsonParser, TestRun, TestResult}

  @type run_opts :: [
          timeout: pos_integer(),
          include: [atom()],
          exclude: [atom()],
          seed: non_neg_integer(),
          max_failures: pos_integer(),
          trace: boolean()
        ]

  @type execution_status :: :success | :failure | :timeout | :error

  @spec run_tests(String.t(), run_opts()) :: {:ok, TestRun.t()} | {:error, term()}
  def run_tests(project_path, opts \\ []) do
    with {:ok, command} <- build_command(opts),
         {:ok, execution_result} <- ProcessExecutor.execute(command, project_path, opts),
         {:ok, test_run} <- parse_execution_result(execution_result, project_path, command) do
      {:ok, test_run}
    end
  end

  @spec run_tests_async(String.t(), run_opts()) :: Task.t()
  def run_tests_async(project_path, opts \\ []) do
    Task.async(fn -> run_tests(project_path, opts) end)
  end

  @spec parse_json_output(String.t()) :: {:ok, TestRun.t()} | {:error, term()}
  def parse_json_output(json_output) do
    JsonParser.parse_json_output(json_output)
  end

  @spec from_project_path(String.t()) :: {:ok, TestRun.t()} | {:error, :no_results | term()}
  def from_project_path(project_path) do
    case run_tests(project_path) do
      {:ok, test_run} -> {:ok, test_run}
      {:error, _} -> {:error, :no_results}
    end
  end

  @spec failed_tests(TestRun.t()) :: [TestResult.t()]
  def failed_tests(%TestRun{results: results}) do
    Enum.filter(results, &(&1.status == :failed))
  end

  @spec passed_tests(TestRun.t()) :: [TestResult.t()]
  def passed_tests(%TestRun{results: results}) do
    Enum.filter(results, &(&1.status == :passed))
  end

  @spec success?(TestRun.t()) :: boolean()
  def success?(%TestRun{execution_status: :success, stats: nil}), do: true
  def success?(%TestRun{execution_status: :success, stats: %{failures: 0}}), do: true
  def success?(%TestRun{}), do: false

  defp build_command(opts) do
    case CommandBuilder.validate_opts(opts) do
      :ok -> {:ok, CommandBuilder.build_command(opts)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp parse_execution_result(execution_result, project_path, command) do
    metadata = %{
      project_path: project_path,
      command: command,
      exit_code: execution_result.exit_code,
      execution_status: execution_result.execution_status,
      raw_output: execution_result.output,
      executed_at: execution_result.executed_at
    }

    JsonParser.parse_json_output(execution_result.output)
    |> case do
      {:ok, test_run} ->
        enhanced_test_run = %{
          test_run
          | project_path: project_path,
            command: command,
            exit_code: execution_result.exit_code,
            execution_status: execution_result.execution_status,
            raw_output: execution_result.output,
            executed_at: execution_result.executed_at
        }

        {:ok, enhanced_test_run}

      {:error, _reason} ->
        # If JSON parsing fails, create a TestRun with execution metadata
        basic_test_run = JsonParser.build_test_run_from_events([], metadata)
        {:ok, basic_test_run}
    end
  end
end

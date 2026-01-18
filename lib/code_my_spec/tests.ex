defmodule CodeMySpec.Tests do
  @moduledoc """
  Tests context for executing and parsing ExUnit test results.
  Provides a clean functional interface for test execution and result analysis.
  """

  require Logger

  alias CodeMySpec.Tests.TestRun

  @doc """
  Execute mix test synchronously with real-time streaming and result parsing.

  ## Parameters

  - `args` - List of arguments to pass to mix test (e.g., ["test", "--only", "integration"])
  - `interaction_id` - Interaction identifier for status updates

  ## Returns

  `{:ok, %TestRun{}}` - Parsed test run with stats, failures, etc.
  `{:error, {:parse_error, raw_output}}` - If JSON parsing fails

  ## Example

      {:ok, test_run} = Tests.execute(["test", "test/my_test.exs"], interaction_id)
      test_run.stats.failures  # => 0
  """
  @spec execute(args :: [String.t()], interaction_id :: String.t()) ::
          {:ok, TestRun.t()} | {:error, {:parse_error, String.t()}}
  def execute(args, interaction_id) do
    # Create temp file for clean JSON test results
    {:ok, temp_file} = Briefly.create()

    # Build the command string for the test run record
    command = "mix " <> Enum.join(args, " ")

    # Extract file_path from args (first arg that looks like a path)
    file_path = extract_file_path(args)

    # Open port with EXUNIT_JSON_OUTPUT_FILE to separate test JSON from other output
    port =
      Port.open({:spawn_executable, System.find_executable("mix")}, [
        :binary,
        :exit_status,
        :stderr_to_stdout,
        :use_stdio,
        {:line, 2048},
        {:args, args},
        {:env,
         [
           {~c"MIX_ENV", ~c"test"},
           {~c"EXUNIT_JSON_OUTPUT_FILE", String.to_charlist(temp_file)},
           {~c"EXUNIT_JSON_STREAMING", ~c"true"}
         ]}
      ])

    # Stream stdout (compiler warnings, progress, etc.) and capture exit status
    {raw_output, exit_code} = stream_test_output(port, interaction_id, [], nil)

    # Read clean JSON from file
    json_content =
      case File.read(temp_file) do
        {:ok, content} ->
          File.rm(temp_file)
          content

        {:error, reason} ->
          Logger.warning("Failed to read test results file #{temp_file}: #{inspect(reason)}")
          File.rm(temp_file)
          "{}"
      end

    # Parse JSON and build TestRun struct
    parse_test_results(json_content, %{
      file_path: file_path,
      command: command,
      exit_code: exit_code,
      raw_output: raw_output,
      ran_at: DateTime.utc_now()
    })
  end

  # Stream output from port, updating InteractionRegistry in real-time
  defp stream_test_output(port, interaction_id, acc, exit_code) do
    receive do
      {^port, {:data, {:eol, line}}} ->
        # Try to parse line as JSON and update InteractionRegistry
        case Jason.decode(line) do
          {:ok, json_message} ->
            CodeMySpec.Sessions.InteractionRegistry.update_status(interaction_id, %{
              last_activity:
                Map.merge(json_message, %{
                  event_type: :test_event,
                  timestamp: DateTime.utc_now()
                })
            })

          {:error, _} ->
            # Not JSON, skip
            :ok
        end

        # Accumulate line and continue streaming
        stream_test_output(port, interaction_id, [line | acc], exit_code)

      {^port, {:data, {:noeol, partial}}} ->
        # Partial line without newline, accumulate and continue
        stream_test_output(port, interaction_id, [partial | acc], exit_code)

      {^port, {:exit_status, status}} ->
        # Port exited, return accumulated output and exit code
        output =
          acc
          |> Enum.reverse()
          |> Enum.join("\n")

        {output, status}
    end
  end

  defp extract_file_path(args) do
    # Find the first argument that looks like a file path
    Enum.find(args, "unknown", fn arg ->
      String.contains?(arg, "/") or String.ends_with?(arg, ".exs") or
        String.ends_with?(arg, ".ex")
    end)
  end

  defp parse_test_results(json_string, metadata) do
    case Jason.decode(json_string) do
      {:ok, data} ->
        build_test_run(data, metadata)

      {:error, _} ->
        {:error, {:parse_error, json_string}}
    end
  end

  defp build_test_run(data, metadata) do
    # Determine execution status from the data
    execution_status = determine_execution_status(data, metadata.exit_code)

    attrs =
      data
      |> Map.merge(%{
        "file_path" => metadata.file_path,
        "command" => metadata.command,
        "exit_code" => metadata.exit_code,
        "execution_status" => execution_status,
        "raw_output" => metadata.raw_output,
        "ran_at" => metadata.ran_at
      })

    changeset = TestRun.parse_changeset(%TestRun{}, attrs)

    if changeset.valid? do
      {:ok, Ecto.Changeset.apply_changes(changeset)}
    else
      errors =
        changeset.errors
        |> Enum.map(fn {field, {message, _opts}} -> "#{field}: #{message}" end)
        |> Enum.join(", ")

      Logger.warning("Failed to build TestRun: #{errors}")
      {:error, {:parse_error, "Invalid test run data: #{errors}"}}
    end
  end

  defp determine_execution_status(data, exit_code) do
    cond do
      exit_code == 0 -> :success
      get_in(data, ["stats", "failures"]) && get_in(data, ["stats", "failures"]) > 0 -> :failure
      exit_code != nil && exit_code != 0 -> :error
      true -> :error
    end
  end
end

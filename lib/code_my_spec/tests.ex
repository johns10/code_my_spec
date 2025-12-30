defmodule CodeMySpec.Tests do
  @moduledoc """
  Tests context for executing and parsing ExUnit test results.
  Provides a clean functional interface for test execution and result analysis.
  """

  require Logger

  @doc """
  Execute mix test asynchronously with real-time streaming and result handling.

  ## Parameters

  - `args` - List of arguments to pass to mix test (e.g., ["test", "--only", "integration"])
  - `session_id` - Session identifier for tracking
  - `interaction_id` - Interaction identifier for status updates
  - `on_complete` - Callback function invoked with test results: `(result :: map() -> any())`
    Result structure: `%{status: :ok | :error, data: %{test_results: json_string}}`

  ## Returns

  `:ok` - Test execution started successfully in background task

  ## Example

      Tests.execute_async(
        ["test"],
        session_id,
        interaction_id,
        fn result ->
          # Handle completion - could chain more operations, call handle_result, etc.
          Sessions.handle_result(scope, session_id, interaction_id, result)
        end
      )
  """
  @spec execute(
          args :: [String.t()],
          interaction_id :: String.t()
        ) :: map()
  def execute(args, interaction_id) do
    # Set initial state

    # Create temp file for clean JSON test results
    {:ok, temp_file} = Briefly.create()

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

    # Stream stdout (compiler warnings, progress, etc.)
    _stdout = stream_test_output(port, interaction_id, [])

    # Read clean JSON from file
    test_results =
      case File.read(temp_file) do
        {:ok, json_content} ->
          File.rm(temp_file)
          json_content

        {:error, reason} ->
          Logger.warning("Failed to read test results file #{temp_file}: #{inspect(reason)}")
          # Fall back to empty results
          "{}"
      end

    # Build result and invoke callback
    %{
      status: :ok,
      data: %{test_results: test_results}
    }
  end

  # Stream output from port, updating RuntimeInteraction in real-time
  defp stream_test_output(port, interaction_id, acc) do
    receive do
      {^port, {:data, {:eol, line}}} ->
        # Try to parse line as JSON and update RuntimeInteraction
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
        stream_test_output(port, interaction_id, [line | acc])

      {^port, {:data, {:noeol, partial}}} ->
        # Partial line without newline, accumulate and continue
        stream_test_output(port, interaction_id, [partial | acc])

      {^port, {:exit_status, _status}} ->
        # Port exited, return accumulated output
        acc
        |> Enum.reverse()
        |> Enum.join("\n")
    end
  end
end

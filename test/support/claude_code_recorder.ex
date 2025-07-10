defmodule CodeMySpec.Agents.Implementations.ClaudeCode.Recorder do
  @moduledoc """
  Simple recording/replay for Claude Code CLI interactions.
  Records raw CLI output and replays it through mocks.
  """

  @fixtures_dir "test/fixtures/recordings"

  @doc """
  Record a CLI command and its raw output to a fixture file
  """
  def record(command, raw_output, name) do
    ensure_fixtures_dir()

    recording = %{
      command: command,
      output: raw_output,
      recorded_at: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    file_path = Path.join(@fixtures_dir, "#{name}.json")

    case Jason.encode(recording, pretty: true) do
      {:ok, json} ->
        File.write!(file_path, json)
        {:ok, file_path}

      error ->
        error
    end
  end

  @doc """
  Load a recorded fixture by name
  """
  def load(name) do
    file_path = Path.join(@fixtures_dir, "#{name}.json")

    case File.read(file_path) do
      {:ok, content} ->
        Jason.decode(content)

      error ->
        error
    end
  end

  @doc """
  Use a recording pattern for tests.
  If recording exists, replay it. If not, make real call and record it.
  """
  def use_recording(recording_name, test_fn) do
    import Mox

    # Set up the mock to check for recordings and record/replay
    expect(CodeMySpec.Agents.Implementations.ClaudeCode.MockCLIAdapter, :run, fn command,
                                                                                 _stream_processor ->
      case load(recording_name) do
        {:ok, %{"command" => recorded_command, "output" => _recorded_output}} ->
          # Recording exists - check if command matches
          if command == recorded_command do
            {:ok, :completed}
          else
            raise """
            Test command changed but recording exists!

            Recorded command: #{inspect(recorded_command)}
            Current command:  #{inspect(command)}

            Delete test/fixtures/recordings/#{recording_name}.json to re-record with new command.
            """
          end

        {:error, _} ->
          # No recording - check if Claude available and record
          case System.cmd("claude", ["--version"], stderr_to_stdout: true) do
            {_output, 0} ->
              # Claude available - make real call and record
              case CodeMySpec.Agents.Implementations.ClaudeCode.CLIAdapter.run(command, fn _ ->
                     :ok
                   end) do
                {:ok, output} = result ->
                  # Record this for next time
                  record(command, output, recording_name)
                  result

                error ->
                  error
              end

            {_error, _code} ->
              {:error, :claude_unavailable, "Claude CLI not available for recording"}
          end
      end
    end)

    test_fn.()
  end

  @doc """
  Manually record a specific query for later replay
  """
  def record_query(prompt, options \\ [], recording_name) do
    # Use the Client to build the command properly
    command = CodeMySpec.Agents.Implementations.ClaudeCode.build_command(prompt, options)

    case CodeMySpec.Agents.Implementations.ClaudeCode.CLIAdapter.run(command, fn _ -> :ok end) do
      {:ok, output} ->
        record(command, output, recording_name)

      error ->
        error
    end
  end

  defp ensure_fixtures_dir do
    File.mkdir_p!(@fixtures_dir)
  end
end

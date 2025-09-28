defmodule CodeMySpec.Support.CLIRecorder do
  @moduledoc """
  VCR-like recorder for CLI commands.

  Records CLI command executions to fixture files and replays them in tests.
  Eliminates the need for real CLI dependencies during testing.
  """

  @fixtures_dir "test/fixtures/cli_recordings"

  @doc """
  Execute a command with VCR-like recording/replay behavior.

  If a recording exists for the command, replay it.
  If not, execute the real command and record the result.
  """
  def with_recording(command, opts_or_recording_name \\ [])

  def with_recording(command, opts) when is_list(opts) do
    # When called with opts, determine recording name from current cassette or generate one
    recording_name =
      case current_cassette() do
        nil -> generate_recording_name(command)
        cassette_name -> cassette_name
      end

    with_recording(command, recording_name, opts)
  end

  def with_recording(command, recording_name) when is_binary(recording_name) do
    with_recording(command, recording_name, [])
  end

  def with_recording(command, recording_name, opts) do
    command_key = command_to_key(command)

    case load_recording(recording_name) do
      {:ok, recordings} ->
        case Map.get(recordings, command_key) do
          nil ->
            # Command not found in recording, execute and add to recording
            record_and_add_to_existing(command, command_key, recording_name, recordings, opts)

          recording ->
            verify_command_match!(recording["command"], command, recording_name, command_key)
            replay_recording(recording)
        end

      {:error, :not_found} ->
        record_and_execute(command, command_key, recording_name, opts)
    end
  end

  @doc """
  Force re-record a command, overwriting any existing recording.
  """
  def record(command, recording_name, opts \\ []) do
    command_key = command_to_key(command)
    record_and_execute(command, command_key, recording_name, opts)
  end

  @doc """
  Execute commands within a cassette context, similar to ExVCR.

  Usage:
    use_cassette "my_command" do
      Environment.cmd(:test, "echo", ["hello"], [])
    end
  """
  defmacro use_cassette(cassette_name, do: block) do
    quote do
      old_cassette = Process.get(:cli_cassette_name)
      Process.put(:cli_cassette_name, unquote(cassette_name))

      try do
        unquote(block)
      after
        if old_cassette do
          Process.put(:cli_cassette_name, old_cassette)
        else
          Process.delete(:cli_cassette_name)
        end
      end
    end
  end

  @doc """
  Get the current cassette name from process dictionary.
  """
  def current_cassette do
    Process.get(:cli_cassette_name)
  end

  @doc """
  Load a recording by name without executing anything.
  """
  def load_recording(name) do
    file_path = recording_path(name)

    case File.read(file_path) do
      {:ok, content} -> Jason.decode(content)
      {:error, :enoent} -> {:error, :not_found}
      error -> error
    end
  end

  @doc """
  Delete a recording file.
  """
  def delete_recording(name) do
    file_path = recording_path(name)
    File.rm(file_path)
  end

  @doc """
  List all available recordings.
  """
  def list_recordings do
    case File.ls(@fixtures_dir) do
      {:ok, files} ->
        files
        |> Enum.filter(&String.ends_with?(&1, ".json"))
        |> Enum.map(&String.replace_suffix(&1, ".json", ""))

      {:error, :enoent} ->
        []
    end
  end

  # Private functions

  defp record_and_execute(command, command_key, recording_name, opts) do
    ensure_fixtures_dir()

    [binary | args] = command
    system_opts = build_system_opts(opts)

    # Just use System.cmd directly - store raw result
    {output, exit_code} = System.cmd(binary, args, system_opts)

    recording = %{
      command: command,
      output: output,
      exit_code: exit_code,
      recorded_at: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    # Format result for return
    result =
      case exit_code do
        0 -> {:ok, output}
        _ -> {:error, :process_failed, {exit_code, output}}
      end

    # Save as a map with command_key
    recordings = %{command_key => recording}
    save_recording(recordings, recording_name)
    result
  end

  defp record_and_add_to_existing(command, command_key, recording_name, existing_recordings, opts) do
    ensure_fixtures_dir()

    [binary | args] = command
    system_opts = build_system_opts(opts)

    # Just use System.cmd directly - store raw result
    {output, exit_code} = System.cmd(binary, args, system_opts)

    recording = %{
      command: command,
      output: output,
      exit_code: exit_code,
      recorded_at: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    # Format result for return
    result =
      case exit_code do
        0 -> {:ok, output}
        _ -> {:error, :process_failed, {exit_code, output}}
      end

    # Add to existing recordings
    updated_recordings = Map.put(existing_recordings, command_key, recording)
    save_recording(updated_recordings, recording_name)
    result
  end

  defp command_to_key(command) do
    command
    |> Enum.join(" ")
  end

  defp generate_recording_name(command) do
    command
    |> Enum.join("_")
    |> String.replace(~r/[^a-zA-Z0-9_]/, "_")
    |> String.slice(0, 50)
  end

  defp replay_recording(%{"output" => output, "exit_code" => exit_code}) do
    case exit_code do
      0 -> {:ok, output}
      _ -> {:error, :process_failed, {exit_code, output}}
    end
  end

  defp build_system_opts(opts) do
    # Default options for System.cmd
    default_opts = [stderr_to_stdout: true]
    Keyword.merge(default_opts, opts)
  end

  defp verify_command_match!(recorded_command, current_command, recording_name, command_key) do
    if recorded_command != current_command do
      raise """
      Command mismatch in recording '#{recording_name}' for command '#{command_key}'!

      Recorded: #{inspect(recorded_command)}
      Current:  #{inspect(current_command)}

      Delete the recording to re-record with the new command:
      rm #{recording_path(recording_name)}
      """
    end
  end

  defp save_recording(recording, name) do
    file_path = recording_path(name)

    case Jason.encode(recording, pretty: true) do
      {:ok, json} ->
        File.write!(file_path, json)
        {:ok, file_path}

      error ->
        error
    end
  end

  defp recording_path(name) do
    Path.join(@fixtures_dir, "#{name}.json")
  end

  defp ensure_fixtures_dir do
    File.mkdir_p!(@fixtures_dir)
  end
end

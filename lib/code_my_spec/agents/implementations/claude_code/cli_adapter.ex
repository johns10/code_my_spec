defmodule CodeMySpec.Agents.Implementations.ClaudeCode.CLIAdapter do
  @moduledoc """
  Production implementation of CLIAdapterBehaviour that executes Claude CLI commands
  and streams output line-by-line to a handler function.
  """

  @behaviour CodeMySpec.Agents.Implementations.ClaudeCode.CLIAdapterBehaviour

  @impl true
  def run(command, stream_handler) do
    [cmd | args] = command

    case System.cmd(cmd, args,
           stderr_to_stdout: true,
           env: [{"CLAUDE_CODE_ENTRYPOINT", "sdk-py"}],
           into: stream_processor(stream_handler)
         ) do
      {_output, 0} -> {:ok, :completed}
      {error, code} -> map_exit_code_to_error(code, error)
    end
  rescue
    error in ErlangError ->
      case error.original do
        :enoent -> {:error, :command_not_found, "Binary not found"}
        :eacces -> {:error, :permission_denied, "Permission denied"}
        other -> {:error, :system_error, other}
      end

    error ->
      {:error, :system_error, error}
  end

  defp stream_processor(stream_handler) do
    IO.stream(:stdio, :line)
    |> Stream.each(stream_handler)
  end

  defp map_exit_code_to_error(code, stderr) do
    case code do
      1 -> {:error, :invalid_args, stderr}
      2 -> {:error, :authentication_error, stderr}
      126 -> {:error, :permission_denied, stderr}
      127 -> {:error, :command_not_found, stderr}
      other -> {:error, :process_failed, {other, stderr}}
    end
  end
end

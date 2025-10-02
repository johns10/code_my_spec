defmodule CodeMySpec.Support.RecordingEnvironment do
  @moduledoc """
  Environment implementation that automatically records CLI commands.
  Used with stub_with to provide automatic recording without explicit expectations.
  """

  alias CodeMySpec.Support.CLIRecorder

  @behaviour CodeMySpec.Environments.EnvironmentsBehaviour

  @impl true
  def environment_setup_command(%{branch_name: branch_name, working_dir: working_dir}) do
    "git -C #{working_dir} switch -C #{branch_name}"
  end

  @impl true
  def docs_environment_teardown_command(%{
        context_name: context_name,
        working_dir: working_dir,
        design_file_name: design_file_name,
        branch_name: branch_name
      }) do
    """
    git -C #{working_dir} add #{design_file_name} && \
    git -C #{working_dir} commit -m "created context design for #{context_name}" && \
    git -C #{working_dir} switch main && \
    git -C #{working_dir} merge #{branch_name}
    """
  end

  @impl true
  def code_environment_teardown_command(%{
        context_name: context_name,
        working_dir: working_dir,
        code_file_name: code_file_name,
        test_file_name: test_file_name
      }) do
    """
    git -C #{working_dir} add #{code_file_name} #{test_file_name} && \
    git -C #{working_dir} commit -m "implemented #{context_name}"
    """
  end

  @impl true
  def cmd(command, args, opts) do
    full_command = [command | args]

    case CLIRecorder.with_recording(full_command, opts) do
      {:ok, output} ->
        {clean_terminal_output(output), 0}

      {:error, :process_failed, {exit_code, output}} ->
        {clean_terminal_output(output), exit_code}
    end
  end

  defp clean_terminal_output(output) do
    output
    |> remove_ansi_codes()
    |> ensure_valid_utf8()
    |> String.trim()
  end

  # Remove ANSI escape codes (colors, formatting, etc.)
  defp remove_ansi_codes(text) do
    String.replace(text, ~r/\x1b\[[0-9;]*m/, "")
  end

  # Ensure the string contains only valid UTF-8 characters
  defp ensure_valid_utf8(text) do
    text
    |> remove_null_bytes()
    |> remove_control_characters()
    |> ensure_printable_utf8()
  end

  # Remove null bytes that PostgreSQL can't handle
  defp remove_null_bytes(text) do
    String.replace(text, <<0>>, "")
  end

  # Remove other problematic control characters
  defp remove_control_characters(text) do
    # Remove control characters except for common ones like \n, \t, \r
    String.replace(text, ~r/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/, "")
  end

  # Ensure we have valid printable UTF-8
  defp ensure_printable_utf8(text) do
    case String.valid?(text) do
      true ->
        text

      false ->
        # Force conversion to valid UTF-8, replacing invalid sequences
        text
        |> :unicode.characters_to_binary(:latin1, :utf8)
        |> case do
          binary when is_binary(binary) -> binary
          # If all else fails, return empty string
          _ -> ""
        end
    end
  end
end

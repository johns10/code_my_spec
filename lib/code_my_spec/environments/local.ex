defmodule CodeMySpec.Environments.Local do
  @behaviour CodeMySpec.Environments.EnvironmentsBehaviour

  def environment_setup_command(%{
        repo_url: repo_url,
        branch_name: branch_name,
        working_dir: working_dir
      }) do
    project_name = extract_project_name(repo_url)

    """
    cd #{working_dir} && \
    git clone #{repo_url} #{project_name} && \
    cd #{project_name} && \
    git switch -C #{branch_name} && \
    mix deps.get
    """
  end

  def docs_environment_teardown_command(%{
        context_name: context_name,
        context_type: context_type,
        working_dir: working_dir,
        design_file_name: design_file_name,
        branch_name: branch_name
      }) do
    """
    git -C #{working_dir} add #{design_file_name} && \
    git -C #{working_dir} commit -m "created #{context_type} design for #{context_name}" && \
    git -C #{working_dir} switch main && \
    git -C #{working_dir} merge #{branch_name}
    """
  end

  def cmd(command, args, opts) do
    case System.cmd(command, args, opts) do
      {output, 0} -> {:ok, clean_terminal_output(output)}
      {output, exit_code} -> {:error, :process_failed, {exit_code, clean_terminal_output(output)}}
    end
  end

  defp extract_project_name(repo_url) do
    repo_url
    |> String.split("/")
    |> List.last()
    |> String.replace(".git", "")
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

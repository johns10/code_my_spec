defmodule CodeMySpec.StaticAnalysis.Analyzers.Dialyzer do
  @moduledoc """
  Runs Dialyzer for type checking and discrepancy detection.

  Implements the AnalyzerBehaviour to execute `mix dialyzer --format short`
  against a project codebase and transform the output into normalized Problem
  structs. The `--format short` option outputs warnings in Elixir term format,
  which can be reliably parsed using Code.eval_string/1. Dialyzer performs
  success typing analysis to detect type inconsistencies, unreachable code,
  and contract violations without requiring explicit type annotations.
  """

  @behaviour CodeMySpec.StaticAnalysis.AnalyzerBehaviour

  alias CodeMySpec.Problems.{Problem, ProblemConverter}
  alias CodeMySpec.Users.Scope

  require Logger

  @impl true
  @spec name() :: String.t()
  def name, do: "dialyzer"

  @impl true
  @spec available?(Scope.t()) :: boolean()
  def available?(%Scope{active_project: project}) do
    with false <- is_nil(project),
         false <- is_nil(project.code_repo),
         true <- File.dir?(project.code_repo),
         true <- File.exists?(Path.join(project.code_repo, "mix.exs")),
         true <- File.dir?(Path.join(project.code_repo, "deps/dialyxir")) do
      true
    else
      _ -> false
    end
  rescue
    _ -> false
  end

  @impl true
  @spec run(Scope.t(), keyword()) :: {:ok, [Problem.t()]} | {:error, String.t()}
  def run(_scope, opts \\ []) do
    project_dir = Keyword.get(opts, :cwd, File.cwd!())

    unless File.dir?(project_dir) do
      {:error, "Project directory does not exist: #{project_dir}"}
    else
      case System.find_executable("mix") do
        nil ->
          {:error, "mix executable not found in system PATH"}

        _mix_path ->
          execute_dialyzer(project_dir)
      end
    end
  end

  # Private functions

  defp execute_dialyzer(project_dir) do
    cmd_opts = [
      stderr_to_stdout: true,
      cd: project_dir,
      env: [{"MIX_ENV", "test"}]
    ]

    args = ["dialyzer", "--format", "short", "--quiet"]

    try do
      case System.cmd("mix", args, cmd_opts) do
        {output, 0} ->
          # Exit status 0 means no warnings
          parse_output(output)

        {output, 2} ->
          # Exit status 2 means warnings found
          parse_output(output)

        {output, exit_code} ->
          {:error, "Dialyzer exited with code #{exit_code}: #{output}"}
      end
    rescue
      e ->
        {:error, "Failed to execute dialyzer: #{Exception.message(e)}"}
    end
  end

  defp parse_output(output) when is_binary(output) do
    # Look for lines that contain Elixir term warnings
    # Dialyzer --format short outputs warnings as Elixir terms
    problems =
      output
      |> String.split("\n", trim: true)
      |> Enum.filter(&looks_like_dialyzer_warning?/1)
      |> Enum.flat_map(&parse_warning_line/1)
      |> Enum.map(&ProblemConverter.from_dialyzer/1)

    {:ok, problems}
  rescue
    error ->
      Logger.error("Failed to parse dialyzer output: #{inspect(error)}")
      {:ok, []}
  end

  defp looks_like_dialyzer_warning?(line) do
    # Dialyzer short format warnings contain file paths and line numbers
    # Typically look like: {file, line, {warning_type, ...}}
    # or contain "lib/" or "test/" paths with .ex or .exs extensions
    String.contains?(line, [".ex:", ".exs:"]) or
      (String.contains?(line, "{") and String.contains?(line, "}"))
  end

  defp parse_warning_line(line) do
    # Only try to eval lines that look like dialyzer warning tuples
    # (start with { and contain a file path pattern)
    # This avoids eval'ing code snippets from compiler warnings which print errors
    trimmed = String.trim(line)

    if String.starts_with?(trimmed, "{") and
         (String.contains?(trimmed, ".ex\"") or String.contains?(trimmed, ".exs\"")) do
      try_eval_warning(line)
    else
      parse_warning_with_regex(line)
    end
  end

  defp try_eval_warning(line) do
    case Code.eval_string(line) do
      {{file, line_num, {type, message}}, _binding}
      when is_binary(file) and is_integer(line_num) ->
        [
          %{
            file: file,
            line: line_num,
            type: type,
            message: format_message(type, message)
          }
        ]

      {{file, line_num, type, message}, _binding} when is_binary(file) and is_integer(line_num) ->
        [
          %{
            file: file,
            line: line_num,
            type: type,
            message: format_message(type, message)
          }
        ]

      _ ->
        # Valid syntax but not a warning tuple, try regex
        parse_warning_with_regex(line)
    end
  rescue
    _ ->
      # If eval fails, try regex
      parse_warning_with_regex(line)
  end

  defp parse_warning_with_regex(line) do
    # Match patterns like: lib/some/file.ex:123: warning message
    case Regex.run(~r/^(.+\.exs?):(\d+):\s*(.+)$/, line) do
      [_full, file, line_num, message] ->
        [
          %{
            file: file,
            line: String.to_integer(line_num),
            type: :unknown,
            message: String.trim(message)
          }
        ]

      _ ->
        []
    end
  end

  defp format_message(_type, message) when is_binary(message), do: message

  defp format_message(_type, message) when is_list(message) do
    case List.to_string(message) do
      str when is_binary(str) -> str
    end
  rescue
    _ -> inspect(message)
  end

  defp format_message(type, message), do: "#{type}: #{inspect(message)}"
end

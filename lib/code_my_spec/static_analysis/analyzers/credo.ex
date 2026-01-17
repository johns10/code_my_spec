defmodule CodeMySpec.StaticAnalysis.Analyzers.Credo do
  @moduledoc """
  Runs Credo static analysis for code consistency and style checks.

  Executes `mix credo suggest --format json --all --all-priorities`, captures stdout
  to a temporary file for reliable JSON parsing, then converts to Problems. Implements
  the AnalyzerBehaviour to provide pluggable static analysis capabilities with
  consistent error handling and result normalization.
  """

  @behaviour CodeMySpec.StaticAnalysis.AnalyzerBehaviour

  alias CodeMySpec.Problems
  alias CodeMySpec.Users.Scope

  require Logger

  @impl true
  @spec name() :: String.t()
  def name, do: "credo"

  @impl true
  @spec available?(Scope.t()) :: boolean()
  def available?(%Scope{active_project: project}) do
    with false <- is_nil(project),
         false <- is_nil(project.code_repo),
         true <- File.dir?(project.code_repo),
         true <- File.exists?(Path.join(project.code_repo, "mix.exs")),
         true <- File.dir?(Path.join(project.code_repo, "deps/credo")) do
      true
    else
      _ -> false
    end
  rescue
    _ -> false
  end

  @impl true
  @spec run(Scope.t(), keyword()) :: {:ok, [Problems.Problem.t()]} | {:error, String.t()}
  def run(%Scope{active_project: project} = scope, opts \\ []) do
    with {:ok, code_repo} <- validate_project(project),
         {:ok, temp_file} <- create_temp_file() do
      result = execute_and_parse(code_repo, temp_file, scope, opts)
      cleanup_temp_file(temp_file)
      result
    end
  rescue
    exception ->
      Logger.error("Credo analyzer crashed: #{inspect(exception)}")
      {:error, "Credo analyzer crashed: #{Exception.message(exception)}"}
  end

  # Private functions

  defp validate_project(%{code_repo: nil}), do: {:error, "Project has no code_repo configured"}
  defp validate_project(%{code_repo: code_repo}), do: {:ok, code_repo}
  defp validate_project(nil), do: {:error, "No project in scope"}

  defp create_temp_file do
    temp_dir = System.tmp_dir!()
    unique_id = System.unique_integer([:positive])
    temp_file = Path.join(temp_dir, "credo_output_#{unique_id}.json")
    {:ok, temp_file}
  rescue
    exception ->
      {:error, "Failed to create temporary file: #{Exception.message(exception)}"}
  end

  defp execute_and_parse(code_repo, temp_file, scope, opts) do
    with {:ok, json_output} <- execute_credo(code_repo, temp_file, opts),
         {:ok, issues} <- parse_json_output(json_output),
         problems <- convert_to_problems(issues, scope) do
      {:ok, problems}
    else
      {:error, _reason} = error ->
        error

      error ->
        {:error, "Unexpected error: #{inspect(error)}"}
    end
  end

  defp execute_credo(code_repo, temp_file, opts) do
    args = build_credo_args(opts)

    case System.cmd("mix", args, cd: code_repo, stderr_to_stdout: true) do
      {output, exit_code} when exit_code <= 128 ->
        # Credo exit codes vary based on issue counts/priorities, accept any normal exit
        # We write stdout to temp file for reliable parsing
        case File.write(temp_file, output) do
          :ok ->
            {:ok, output}

          {:error, reason} ->
            {:error, "Failed to write output to temp file: #{inspect(reason)}"}
        end

      {output, _exit_code} ->
        {:error, "Credo command failed: #{output}"}
    end
  rescue
    exception ->
      {:error, "Failed to execute Credo: #{Exception.message(exception)}"}
  end

  defp build_credo_args(opts) do
    base_args = ["credo", "suggest", "--format", "json", "--all", "--all-priorities"]

    case Keyword.get(opts, :config_file) do
      nil -> base_args
      config_file -> base_args ++ ["--config-file", config_file]
    end
  end

  defp parse_json_output(output) do
    case Jason.decode(output) do
      {:ok, %{"issues" => issues}} when is_list(issues) ->
        {:ok, issues}

      {:ok, %{}} ->
        # No issues key, return empty list
        {:ok, []}

      {:ok, _other} ->
        {:error, "Unexpected JSON structure from Credo output"}

      {:error, %Jason.DecodeError{} = error} ->
        {:error, "Failed to parse Credo JSON output: #{Exception.message(error)}"}
    end
  end

  defp convert_to_problems(issues, %Scope{active_project_id: project_id}) do
    Enum.map(issues, fn issue ->
      issue
      |> Problems.from_credo()
      |> Map.put(:project_id, project_id)
    end)
  end

  defp cleanup_temp_file(temp_file) do
    if File.exists?(temp_file) do
      File.rm(temp_file)
    end
  rescue
    _ -> :ok
  end
end

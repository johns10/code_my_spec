defmodule CodeMySpecCli.Hooks.ValidateEdits do
  @moduledoc """
  Claude Code stop hook handler that validates files written or edited during an agent session.

  Validates:
  - Spec files (.spec.md) - ensures they conform to the expected schema
  - Code/test files (.ex/.exs) - runs Credo static analysis to catch style and consistency issues
  """

  require Logger

  alias CodeMySpec.Documents
  alias CodeMySpec.FileEdits
  alias CodeMySpec.Problems
  alias CodeMySpec.Problems.ProblemRenderer

  @doc """
  Validate files edited during a session.

  Retrieves edited files from FileEdits (tracked by TrackEdits hook during PostToolUse)
  and validates:
  - Spec files (.spec.md) against their expected schema
  - Code/test files (.ex/.exs) using Credo static analysis
  """
  @spec run(String.t()) :: {:ok, :valid} | {:error, [String.t()]}
  def run(session_id) do
    Logger.info("[ValidateEdits] Starting validation for session: #{session_id}")

    all_files = FileEdits.get_edited_files(session_id)
    Logger.info("[ValidateEdits] All edited files: #{inspect(all_files)}")

    spec_files = Enum.filter(all_files, &spec_file?/1)
    code_files = Enum.filter(all_files, &elixir_file?/1)
    Logger.info("[ValidateEdits] Spec files to validate: #{inspect(spec_files)}")
    Logger.info("[ValidateEdits] Code files to check with Credo: #{inspect(code_files)}")

    spec_errors = get_spec_errors(spec_files)
    credo_problems = get_credo_problems(code_files)

    all_errors = spec_errors ++ format_credo_problems(credo_problems)
    Logger.info("[ValidateEdits] Total errors: #{length(all_errors)}")

    case all_errors do
      [] -> {:ok, :valid}
      errors -> {:error, errors}
    end
  end

  @doc """
  Run validation and output JSON result to stdout.
  """
  @spec run_and_output(String.t()) :: :ok
  def run_and_output(session_id) do
    result = run(session_id)
    json = Jason.encode!(format_output(result))
    Logger.info("[ValidateEdits] JSON output: #{json}")
    IO.puts(json)
    :ok
  end

  defp validate_with_path(path) do
    Logger.info("[ValidateEdits] Validating spec file: #{path}")

    case validate_spec_file(path) do
      :ok ->
        Logger.info("[ValidateEdits] File valid: #{path}")
        :ok

      {:error, reason} ->
        Logger.error("[ValidateEdits] File invalid: #{path} - #{reason}")
        {:error, path, reason}
    end
  end

  @spec validate_spec_file(Path.t()) :: :ok | {:error, String.t()}
  def validate_spec_file(file_path) do
    with {:ok, content} <- read_file(file_path),
         :ok <- validate_not_empty(content),
         doc_type <- document_type_from_path(file_path),
         {:ok, _doc} <- Documents.create_dynamic_document(content, doc_type) do
      :ok
    else
      {:error, reason} when is_binary(reason) -> {:error, reason}
    end
  end

  defp read_file(path) do
    case File.read(path) do
      {:ok, content} -> {:ok, content}
      {:error, :enoent} -> {:error, "File not found"}
      {:error, reason} -> {:error, "Failed to read file: #{inspect(reason)}"}
    end
  end

  defp validate_not_empty(""), do: {:error, "File is empty"}
  defp validate_not_empty(_content), do: :ok

  @spec document_type_from_path(Path.t()) :: String.t()
  def document_type_from_path(file_path) do
    # Pattern: docs/spec/<project>/<context>.spec.md -> context_spec
    # Pattern: docs/spec/<project>/<context>/<component>.spec.md -> spec
    # Pattern: docs/spec/<file>.spec.md -> spec (no project nesting)
    # Pattern: anything else -> spec

    case extract_segments_after_docs_spec(file_path) do
      # docs/spec/<project>/<context>.spec.md - exactly 2 segments
      [_project_dir, _file] -> "context_spec"
      # Everything else is a component spec
      _ -> "spec"
    end
  end

  defp extract_segments_after_docs_spec(file_path) do
    parts = Path.split(file_path)

    case Enum.find_index(parts, &(&1 == "spec")) do
      nil ->
        # No "spec" directory found, return all parts
        parts

      index ->
        # Check if preceding part is "docs"
        if index > 0 and Enum.at(parts, index - 1) == "docs" do
          # Return everything after "docs/spec"
          Enum.drop(parts, index + 1)
        else
          # "spec" exists but not preceded by "docs"
          parts
        end
    end
  end

  @spec spec_file?(Path.t()) :: boolean()
  def spec_file?(file_path) do
    String.ends_with?(file_path, ".spec.md")
  end

  @spec elixir_file?(Path.t()) :: boolean()
  def elixir_file?(file_path) do
    String.ends_with?(file_path, ".ex") or String.ends_with?(file_path, ".exs")
  end

  # Extract spec validation errors as a list of strings
  defp get_spec_errors([]), do: []

  defp get_spec_errors(spec_paths) do
    spec_paths
    |> Enum.map(&validate_with_path/1)
    |> Enum.reject(&(&1 == :ok))
    |> Enum.map(fn {:error, path, reason} -> "#{path}: #{reason}" end)
  end

  # Run Credo on specific files and return Problem structs
  defp get_credo_problems([]), do: []

  defp get_credo_problems(file_paths) do
    Logger.info("[ValidateEdits] Running Credo on #{length(file_paths)} files")

    # Determine project root (cwd) from the first file path
    cwd = find_project_root(hd(file_paths))

    case cwd do
      nil ->
        Logger.warning("[ValidateEdits] Could not determine project root, skipping Credo")
        []

      project_root ->
        run_credo_on_files(file_paths, project_root)
    end
  end

  defp find_project_root(file_path) do
    # Walk up the directory tree to find mix.exs
    file_path
    |> Path.dirname()
    |> find_mix_exs_dir()
  end

  defp find_mix_exs_dir("/"), do: nil
  defp find_mix_exs_dir(""), do: nil

  defp find_mix_exs_dir(dir) do
    if File.exists?(Path.join(dir, "mix.exs")) do
      dir
    else
      parent = Path.dirname(dir)

      if parent == dir do
        nil
      else
        find_mix_exs_dir(parent)
      end
    end
  end

  defp run_credo_on_files(file_paths, project_root) do
    # Check if Credo is available
    credo_dir = Path.join(project_root, "deps/credo")

    if File.dir?(credo_dir) do
      execute_credo(file_paths, project_root)
    else
      Logger.info("[ValidateEdits] Credo not installed, skipping static analysis")
      []
    end
  end

  defp execute_credo(file_paths, project_root) do
    # Build credo command with specific files
    args = ["credo", "suggest", "--format", "json", "--all-priorities" | file_paths]
    Logger.info("[ValidateEdits] Running: mix #{Enum.join(args, " ")}")

    case System.cmd("mix", args, cd: project_root, stderr_to_stdout: true) do
      {output, exit_code} when exit_code <= 128 ->
        parse_credo_output(output)

      {output, exit_code} ->
        Logger.error("[ValidateEdits] Credo failed with exit code #{exit_code}: #{output}")
        []
    end
  rescue
    exception ->
      Logger.error("[ValidateEdits] Credo execution error: #{Exception.message(exception)}")
      []
  end

  defp parse_credo_output(output) do
    case Jason.decode(output) do
      {:ok, %{"issues" => issues}} when is_list(issues) ->
        Enum.map(issues, &Problems.from_credo/1)

      {:ok, %{}} ->
        []

      {:error, %Jason.DecodeError{} = error} ->
        Logger.error("[ValidateEdits] Failed to parse Credo JSON: #{Exception.message(error)}")
        []
    end
  end

  # Format Problem structs into a single feedback string using the renderer
  defp format_credo_problems([]), do: []

  defp format_credo_problems(problems) do
    feedback =
      ProblemRenderer.render_for_feedback(problems,
        context: "Credo static analysis found issues in edited files:",
        max_problems: 20
      )

    [feedback]
  end

  @spec format_output({:ok, :valid} | {:error, [String.t()]}) :: map()
  def format_output({:ok, :valid}) do
    %{}
  end

  # File not found means nothing to validate - allow rather than block
  def format_output({:error, [:file_not_found]}) do
    %{}
  end

  def format_output({:error, errors}) when is_list(errors) do
    reason =
      case errors do
        [single] -> single
        multiple -> "Validation errors:\n" <> Enum.map_join(multiple, "\n", &"- #{&1}")
      end

    %{"decision" => "block", "reason" => reason}
  end
end

defmodule CodeMySpecCli.Hooks.ValidateEdits do
  @moduledoc """
  Claude Code stop hook handler that validates spec files written or edited during an agent session.
  Ensures all spec files conform to the expected schema.
  """

  require Logger

  alias CodeMySpec.Documents
  alias CodeMySpec.Transcripts

  @spec run(Path.t()) :: {:ok, :valid} | {:error, [String.t()]}
  def run(transcript_path) do
    Logger.info("[ValidateEdits] Starting validation for transcript: #{transcript_path}")

    with {:ok, transcript} <- parse_transcript(transcript_path) do
      all_files = Transcripts.extract_edited_files(transcript)
      Logger.info("[ValidateEdits] All edited files: #{inspect(all_files)}")

      spec_files = Enum.filter(all_files, &spec_file?/1)
      Logger.info("[ValidateEdits] Spec files to validate: #{inspect(spec_files)}")

      result = validate_spec_files(spec_files)
      Logger.info("[ValidateEdits] Validation result: #{inspect(result)}")

      result
    end
  end

  @doc """
  Run validation and output JSON result to stdout.
  """
  @spec run_and_output(Path.t()) :: :ok
  def run_and_output(transcript_path) do
    result = run(transcript_path)
    json = Jason.encode!(format_output(result))
    Logger.info("[ValidateEdits] JSON output: #{json}")
    IO.puts(json)
    :ok
  end

  defp parse_transcript(path) do
    Logger.info("[ValidateEdits] Parsing transcript at: #{path}")

    case Transcripts.parse(path) do
      {:ok, transcript} ->
        Logger.info("[ValidateEdits] Transcript parsed successfully")
        {:ok, transcript}

      {:error, :file_not_found} ->
        Logger.error("[ValidateEdits] Transcript file not found: #{path}")
        {:error, [:file_not_found]}

      {:error, reason} ->
        Logger.error("[ValidateEdits] Failed to parse transcript: #{inspect(reason)}")
        {:error, ["Failed to parse transcript"]}
    end
  end

  defp validate_spec_files([]), do: {:ok, :valid}

  defp validate_spec_files(spec_paths) do
    errors =
      spec_paths
      |> Enum.map(&validate_with_path/1)
      |> Enum.reject(&(&1 == :ok))
      |> Enum.map(fn {:error, path, reason} -> "#{path}: #{reason}" end)

    case errors do
      [] -> {:ok, :valid}
      errors -> {:error, errors}
    end
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

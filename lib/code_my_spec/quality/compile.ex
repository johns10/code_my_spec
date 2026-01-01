defmodule CodeMySpec.Quality.Compile do
  @moduledoc """
  Validates compilation results from mix compile output.

  Parses JSON compiler diagnostics in raw format and checks for errors and warnings.
  """

  alias CodeMySpec.Quality.Result
  alias CodeMySpec.Compile.Diagnostic

  @doc """
  Checks compilation state from a command result.

  Parses compiler JSON output and validates compilation succeeded.

  Scoring:
  - 1.0 for clean compile (no errors or warnings)
  - Decreases by 0.1 per warning (0.9 for 1 warning, 0.8 for 2, etc.)
  - Floor of 0.0 for 10+ warnings
  - 0.0 if any compilation errors present

  ## Examples

      iex> result = %{data: %{compiler: valid_json_no_errors}}
      iex> check_compilation(result)
      %Result{score: 1.0, errors: []}

      iex> result = %{data: %{compiler: valid_json_with_errors}}
      iex> check_compilation(result)
      %Result{score: 0.0, errors: ["compilation error messages..."]}
  """
  def check_compilation(result) do
    with {:ok, compiler_data} <- get_compiler_data(result),
         {:ok, diagnostics} <- parse_diagnostics(compiler_data) do
      evaluate_diagnostics(diagnostics)
    else
      {:error, error} ->
        Result.error([error])
    end
  end

  @doc """
  Calculates quality score based on number of warnings.

  Score decreases by 0.1 per warning, with a floor of 0.0 at 10+ warnings.

  ## Examples

      iex> quality_score(0)
      1.0

      iex> quality_score(1)
      0.9

      iex> quality_score(10)
      0.0
  """
  def quality_score(warning_count) do
    score = max(0.0, 1.0 - warning_count * 0.1)
    Float.round(score, 1)
  end

  defp get_compiler_data(%{data: %{compiler_results: compiler_output}})
       when is_binary(compiler_output) do
    {:ok, compiler_output}
  end

  defp get_compiler_data(%{data: %{compiler_results: data}}) when is_list(data) do
    {:ok, Jason.encode!(data)}
  end

  defp get_compiler_data(_result), do: {:error, "Compiler data missing"}

  defp parse_diagnostics(json) when is_binary(json) do
    Diagnostic.parse_json(json)
  end

  defp evaluate_diagnostics(diagnostics) do
    errors = Diagnostic.filter_by_severity(diagnostics, :error)
    warnings = Diagnostic.filter_by_severity(diagnostics, :warning)

    cond do
      length(errors) > 0 ->
        # Compilation failed - score 0.0
        error_messages = Diagnostic.format_list("Compilation Error", errors)
        warning_messages = Diagnostic.format_list("Compilation Warning", warnings)
        Result.error(error_messages ++ warning_messages)

      length(warnings) > 0 ->
        # Compilation succeeded with warnings - use quality_score
        warning_messages = Diagnostic.format_list("Compilation Warning", warnings)

        %Result{
          score: quality_score(length(warnings)),
          errors: warning_messages
        }

      true ->
        # Clean compilation - score 1.0
        Result.ok()
    end
  end
end

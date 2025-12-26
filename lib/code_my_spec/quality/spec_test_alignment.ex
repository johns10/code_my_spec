defmodule CodeMySpec.Quality.SpecTestAlignment do
  alias CodeMySpec.Code.ElixirAst
  alias CodeMySpec.Quality.Result
  alias CodeMySpec.Utils

  @doc """
  Validates that test implementations align with Test Assertions defined in the spec.

  Checks that:
  - All Test Assertions from the spec are implemented as tests
  - Tests are organized in describe blocks matching function signatures
  - No extra tests exist that aren't in the spec

  Returns a `%Quality.Result{}` with a score of 1.0 if aligned, or 0.0 with error details if misaligned.

  ## Options

  - `:cwd` - Base directory path to prepend to file paths (default: current directory)
  """
  def spec_test_alignment(component, project, opts \\ []) do
    cwd = Keyword.get(opts, :cwd, ".")

    %{test_file: test_file_path, spec_file: spec_file_path} =
      Utils.component_files(component, project)

    test_file_path = Path.join(cwd, test_file_path)
    spec_file_path = Path.join(cwd, spec_file_path)

    with {:ok, spec_content} <- File.read(spec_file_path),
         {:ok, expected_by_function} <- parse_spec_test_assertions(spec_content),
         {:ok, actual_tests} <- ElixirAst.get_test_assertions(test_file_path) do
      actual_by_function = group_tests_by_function(actual_tests)

      compare_assertions(expected_by_function, actual_by_function)
    else
      {:error, :enoent} ->
        Result.error(["Spec or test file not found"])

      {:error, reason} ->
        Result.error([
          """
          The tests are not aligned with the spec.
          Make sure you ONLY write the tests defined in the specification.
          Name the describe blocks according to the function, and the tests according to the spec, for example:

          describe "get_test_assertions/1" do
            test "extracts test names from test blocks", %{tmp_dir: tmp_dir} do
              ...test code
            end
          end

          Misalignment details:
          #{inspect(reason)}
          """
        ])
    end
  end

  # ============================================================================
  # Private Functions - Spec Parsing
  # ============================================================================

  defp parse_spec_test_assertions(spec_content) do
    # Parse markdown to extract functions and their test assertions
    # Format:
    # ### function_name/arity
    # ...
    # **Test Assertions**:
    # - assertion 1
    # - assertion 2

    function_sections = Regex.scan(~r/###\s+([^\n]+)\n(.*?)(?=###|\z)/s, spec_content)

    assertions_by_function =
      function_sections
      |> Enum.map(fn [_full, function_sig, content] ->
        function_sig = String.trim(function_sig)
        assertions = extract_test_assertions_from_content(content)
        {function_sig, assertions}
      end)
      |> Enum.reject(fn {_func, assertions} -> Enum.empty?(assertions) end)
      |> Enum.into(%{})

    {:ok, assertions_by_function}
  end

  defp extract_test_assertions_from_content(content) do
    # Find the **Test Assertions**: section and extract bullet points
    case Regex.run(~r/\*\*Test Assertions\*\*:\n((?:- [^\n]+\n?)+)/s, content) do
      [_full, assertions_block] ->
        assertions_block
        |> String.split("\n")
        |> Enum.map(&String.trim/1)
        |> Enum.filter(&String.starts_with?(&1, "- "))
        |> Enum.map(&String.trim_leading(&1, "- "))
        |> Enum.reject(&(&1 == ""))

      nil ->
        []
    end
  end

  # ============================================================================
  # Private Functions - Test Grouping
  # ============================================================================

  defp group_tests_by_function(tests) do
    tests
    |> Enum.group_by(&extract_function_from_test/1)
    |> Enum.map(fn {function, tests} ->
      test_names = Enum.map(tests, & &1.test_name)
      {function, test_names}
    end)
    |> Enum.reject(fn {func, _tests} -> is_nil(func) end)
    |> Enum.into(%{})
  end

  defp extract_function_from_test(%{describe_blocks: []}), do: nil

  defp extract_function_from_test(%{describe_blocks: [first_describe | _]}) do
    # Extract function signature from describe block
    # Format: "function_name/arity" or "function_name/arity - category"
    # We want just the "function_name/arity" part
    case String.split(first_describe, " - ", parts: 2) do
      [function_sig | _] -> String.trim(function_sig)
      _ -> String.trim(first_describe)
    end
  end

  # ============================================================================
  # Private Functions - Comparison
  # ============================================================================

  defp compare_assertions(expected_by_function, actual_by_function) do
    all_functions =
      MapSet.union(
        MapSet.new(Map.keys(expected_by_function)),
        MapSet.new(Map.keys(actual_by_function))
      )

    {error_strings, matching_count, missing_count, extra_count} =
      all_functions
      |> Enum.reduce({[], 0, 0, 0}, fn function, {errors, matching, missing_total, extra_total} ->
        expected = Map.get(expected_by_function, function, []) |> MapSet.new()
        actual = Map.get(actual_by_function, function, []) |> MapSet.new()

        matching_tests = MapSet.intersection(expected, actual)
        missing_tests = MapSet.difference(expected, actual) |> MapSet.to_list() |> Enum.sort()
        extra_tests = MapSet.difference(actual, expected) |> MapSet.to_list() |> Enum.sort()

        function_errors = build_function_error_strings(function, missing_tests, extra_tests)

        {
          errors ++ function_errors,
          matching + MapSet.size(matching_tests),
          missing_total + length(missing_tests),
          extra_total + length(extra_tests)
        }
      end)

    total_tests = matching_count + missing_count + extra_count

    quality =
      if total_tests == 0 do
        1.0
      else
        matching_count / total_tests
      end

    if Enum.empty?(error_strings) do
      Result.ok()
    else
      Result.partial(quality, error_strings)
    end
  end

  defp build_function_error_strings(function, missing, extra) do
    error_strings = []

    error_strings =
      if Enum.any?(missing) do
        missing_msg =
          "Function `#{function}`: Missing test assertions (defined in spec but not implemented): #{Enum.join(missing, ", ")}"

        [missing_msg | error_strings]
      else
        error_strings
      end

    error_strings =
      if Enum.any?(extra) do
        extra_msg =
          "Function `#{function}`: Extra tests found (not defined in spec): #{Enum.join(extra, ", ")}"

        [extra_msg | error_strings]
      else
        error_strings
      end

    error_strings
  end
end

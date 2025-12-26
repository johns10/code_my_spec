defmodule CodeMySpec.Quality.SpecTestAlignment do
  alias CodeMySpec.Code.ElixirAst
  alias CodeMySpec.Utils

  @doc """
  Validates that test implementations align with Test Assertions defined in the spec.

  Checks that:
  - All Test Assertions from the spec are implemented as tests
  - Tests are organized in describe blocks matching function signatures
  - No extra tests exist that aren't in the spec

  Returns `:ok` if aligned, or `{:error, message}` with details of misalignment.
  """
  def spec_test_alignment(component, project) do
    %{test_file: test_file_path, spec_file: spec_file_path} =
      Utils.component_files(component, project)

    with {:ok, spec_content} <- File.read(spec_file_path),
         {:ok, expected_by_function} <- parse_spec_test_assertions(spec_content),
         {:ok, actual_tests} <- ElixirAst.get_test_assertions(test_file_path) do
      actual_by_function = group_tests_by_function(actual_tests)

      compare_assertions(expected_by_function, actual_by_function)
    else
      {:error, :enoent} ->
        {:error, "Spec or test file not found"}

      {:error, reason} ->
        {:error, "Failed to parse files: #{inspect(reason)}"}
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

    errors =
      all_functions
      |> Enum.flat_map(fn function ->
        expected = Map.get(expected_by_function, function, []) |> MapSet.new()
        actual = Map.get(actual_by_function, function, []) |> MapSet.new()

        missing = MapSet.difference(expected, actual) |> MapSet.to_list() |> Enum.sort()
        extra = MapSet.difference(actual, expected) |> MapSet.to_list() |> Enum.sort()

        build_function_errors(function, missing, extra)
      end)

    if Enum.empty?(errors) do
      :ok
    else
      error_message = format_error_message(errors)
      {:error, error_message}
    end
  end

  defp build_function_errors(function, missing, extra) do
    errors = []

    errors =
      if Enum.any?(missing) do
        [
          %{
            function: function,
            type: :missing,
            assertions: missing
          }
          | errors
        ]
      else
        errors
      end

    errors =
      if Enum.any?(extra) do
        [
          %{
            function: function,
            type: :extra,
            assertions: extra
          }
          | errors
        ]
      else
        errors
      end

    errors
  end

  defp format_error_message(errors) do
    grouped = Enum.group_by(errors, & &1.type)

    lines = []

    lines =
      if missing_errors = grouped[:missing] do
        missing_section =
          missing_errors
          |> Enum.map(fn %{function: func, assertions: assertions} ->
            assertion_lines = Enum.map(assertions, fn a -> "  - #{a}" end)
            ["Function `#{func}`:" | assertion_lines]
          end)
          |> List.flatten()

        lines ++
          ["Missing test assertions (defined in spec but not implemented):"] ++ missing_section
      else
        lines
      end

    lines =
      if lines != [] do
        lines ++ [""]
      else
        lines
      end

    lines =
      if extra_errors = grouped[:extra] do
        extra_section =
          extra_errors
          |> Enum.map(fn %{function: func, assertions: assertions} ->
            assertion_lines = Enum.map(assertions, fn a -> "  - #{a}" end)
            ["Function `#{func}`:" | assertion_lines]
          end)
          |> List.flatten()

        lines ++ ["Extra tests found (not defined in spec):"] ++ extra_section
      else
        lines
      end

    Enum.join(lines, "\n")
  end
end

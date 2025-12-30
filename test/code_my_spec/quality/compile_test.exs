defmodule CodeMySpec.Quality.CompileTest do
  use ExUnit.Case, async: true

  alias CodeMySpec.Quality.Compile
  alias CodeMySpec.Quality.Result

  # Fixtures

  defp compiler_result_fixture(diagnostics) when is_list(diagnostics) do
    # Raw format - direct array of diagnostics
    %{
      data: %{
        compiler_results: diagnostics
      }
    }
  end

  defp compiler_result_with_json_string_fixture(diagnostics) when is_list(diagnostics) do
    # Raw format - JSON array of diagnostics (not wrapped in "diagnostics" key)
    json_string = Jason.encode!(diagnostics)

    %{
      data: %{
        compiler_results: json_string
      }
    }
  end

  defp diagnostic_fixture(severity, message, file, line) do
    %{
      "severity" => severity,
      "message" => message,
      "file" => file,
      "position" => %{"line" => line}
    }
  end

  defp error_diagnostic_fixture(message, file, line) do
    diagnostic_fixture("error", message, file, line)
  end

  defp warning_diagnostic_fixture(message, file, line) do
    diagnostic_fixture("warning", message, file, line)
  end

  # Tests for quality_score/1

  describe "quality_score/1" do
    test "returns 1.0 for 0 warnings" do
      assert Compile.quality_score(0) == 1.0
    end

    test "returns 0.9 for 1 warning" do
      assert Compile.quality_score(1) == 0.9
    end

    test "returns 0.8 for 2 warnings" do
      assert Compile.quality_score(2) == 0.8
    end

    test "returns 0.1 for 9 warnings" do
      assert Compile.quality_score(9) == 0.1
    end

    test "returns 0.0 for 10 warnings" do
      assert Compile.quality_score(10) == 0.0
    end

    test "returns 0.0 for 15 warnings (floor applied)" do
      assert Compile.quality_score(15) == 0.0
    end

    test "returns 0.0 for 100 warnings (floor applied)" do
      assert Compile.quality_score(100) == 0.0
    end
  end

  # Tests for check_compilation/1

  describe "check_compilation/1" do
    test "returns Result with score 1.0 and empty errors for clean compilation (no diagnostics)" do
      result = compiler_result_fixture([])

      assert %Result{score: 1.0, errors: []} = Compile.check_compilation(result)
    end

    test "returns Result with score 0.9 and formatted warnings when 1 warning present" do
      diagnostics = [
        warning_diagnostic_fixture("unused variable foo", "lib/example.ex", 10)
      ]

      result = compiler_result_fixture(diagnostics)

      assert %Result{score: 0.9, errors: errors} = Compile.check_compilation(result)
      assert length(errors) == 1
      assert hd(errors) == "Compilation Warning (lib/example.ex:10: unused variable foo)"
    end

    test "returns Result with score 0.8 and formatted warnings when 2 warnings present" do
      diagnostics = [
        warning_diagnostic_fixture("unused variable foo", "lib/example.ex", 10),
        warning_diagnostic_fixture("unused variable bar", "lib/example.ex", 20)
      ]

      result = compiler_result_fixture(diagnostics)

      assert %Result{score: 0.8, errors: errors} = Compile.check_compilation(result)
      assert length(errors) == 2
      assert "Compilation Warning (lib/example.ex:10: unused variable foo)" in errors
      assert "Compilation Warning (lib/example.ex:20: unused variable bar)" in errors
    end

    test "returns Result with score 0.5 and formatted warnings when 5 warnings present" do
      diagnostics = [
        warning_diagnostic_fixture("warning 1", "lib/example.ex", 1),
        warning_diagnostic_fixture("warning 2", "lib/example.ex", 2),
        warning_diagnostic_fixture("warning 3", "lib/example.ex", 3),
        warning_diagnostic_fixture("warning 4", "lib/example.ex", 4),
        warning_diagnostic_fixture("warning 5", "lib/example.ex", 5)
      ]

      result = compiler_result_fixture(diagnostics)

      assert %Result{score: 0.5, errors: errors} = Compile.check_compilation(result)
      assert length(errors) == 5
    end

    test "returns Result with score 0.0 and formatted warnings when 10 warnings present" do
      diagnostics =
        Enum.map(1..10, fn i ->
          warning_diagnostic_fixture("warning #{i}", "lib/example.ex", i)
        end)

      result = compiler_result_fixture(diagnostics)

      assert %Result{score: +0.0, errors: errors} = Compile.check_compilation(result)
      assert length(errors) == 10
    end

    test "returns Result with score 0.0 and formatted warnings when more than 10 warnings present (floor enforced)" do
      diagnostics =
        Enum.map(1..15, fn i ->
          warning_diagnostic_fixture("warning #{i}", "lib/example.ex", i)
        end)

      result = compiler_result_fixture(diagnostics)

      assert %Result{score: +0.0, errors: errors} = Compile.check_compilation(result)
      assert length(errors) == 15
    end

    test "returns Result with score 0.0 and formatted errors when compilation errors exist" do
      diagnostics = [
        error_diagnostic_fixture("undefined function foo/1", "lib/example.ex", 15)
      ]

      result = compiler_result_fixture(diagnostics)

      assert %Result{score: +0.0, errors: errors} = Compile.check_compilation(result)
      assert length(errors) == 1
      assert hd(errors) == "Compilation Error (lib/example.ex:15: undefined function foo/1)"
    end

    test "returns Result with score 0.0 and both errors and warnings when both are present" do
      diagnostics = [
        error_diagnostic_fixture("undefined function foo/1", "lib/example.ex", 15),
        warning_diagnostic_fixture("unused variable bar", "lib/example.ex", 20)
      ]

      result = compiler_result_fixture(diagnostics)

      assert %Result{score: +0.0, errors: errors} = Compile.check_compilation(result)
      assert length(errors) == 2
      assert "Compilation Error (lib/example.ex:15: undefined function foo/1)" in errors
      assert "Compilation Warning (lib/example.ex:20: unused variable bar)" in errors
    end

    test "handles compiler output as JSON string and decodes successfully" do
      diagnostics = [
        warning_diagnostic_fixture("unused variable foo", "lib/example.ex", 10)
      ]

      result = compiler_result_with_json_string_fixture(diagnostics)

      assert %Result{score: 0.9, errors: errors} = Compile.check_compilation(result)
      assert length(errors) == 1
      assert hd(errors) == "Compilation Warning (lib/example.ex:10: unused variable foo)"
    end

    test "handles compiler output as already-parsed map" do
      diagnostics = [
        warning_diagnostic_fixture("unused variable foo", "lib/example.ex", 10)
      ]

      result = compiler_result_fixture(diagnostics)

      assert %Result{score: 0.9, errors: errors} = Compile.check_compilation(result)
      assert length(errors) == 1
      assert hd(errors) == "Compilation Warning (lib/example.ex:10: unused variable foo)"
    end

    test "returns error Result when compiler data is missing from result map" do
      result = %{data: %{}}

      assert %Result{score: +0.0, errors: errors} = Compile.check_compilation(result)
      assert length(errors) == 1
      assert hd(errors) =~ "Compiler data missing"
    end

    test "returns error Result when JSON decoding fails" do
      result = %{
        data: %{
          compiler_results: "invalid json {{"
        }
      }

      assert %Result{score: +0.0, errors: errors} = Compile.check_compilation(result)
      assert length(errors) == 1
      assert hd(errors) =~ "Failed to parse"
    end

    test "returns error Result when diagnostics key is missing from compiler output" do
      result = %{
        data: %{
          compiler_results: Jason.encode!(%{"some_other_key" => "value"})
        }
      }

      assert %Result{score: +0.0, errors: errors} = Compile.check_compilation(result)
      assert length(errors) == 1
      assert hd(errors) =~ "JSON must contain an array of diagnostics"
    end

    test "formats error messages with file path, line number, and message content" do
      diagnostics = [
        error_diagnostic_fixture(
          "undefined function calculate/2",
          "lib/my_app/calculator.ex",
          42
        )
      ]

      result = compiler_result_fixture(diagnostics)

      assert %Result{score: +0.0, errors: errors} = Compile.check_compilation(result)

      assert hd(errors) ==
               "Compilation Error (lib/my_app/calculator.ex:42: undefined function calculate/2)"
    end

    test "formats warning messages with \"Compilation Warning\" prefix" do
      diagnostics = [
        warning_diagnostic_fixture("unused variable x", "lib/example.ex", 5)
      ]

      result = compiler_result_fixture(diagnostics)

      assert %Result{score: 0.9, errors: errors} = Compile.check_compilation(result)
      assert hd(errors) =~ "Compilation Warning"
    end

    test "formats error messages with \"Compilation Error\" prefix" do
      diagnostics = [
        error_diagnostic_fixture("syntax error", "lib/example.ex", 5)
      ]

      result = compiler_result_fixture(diagnostics)

      assert %Result{score: +0.0, errors: errors} = Compile.check_compilation(result)
      assert hd(errors) =~ "Compilation Error"
    end

    test "categorizes diagnostics correctly by severity field (error vs warning)" do
      diagnostics = [
        %{
          "severity" => "error",
          "message" => "error message",
          "file" => "lib/a.ex",
          "position" => %{"line" => 1}
        },
        %{
          "severity" => "warning",
          "message" => "warning message",
          "file" => "lib/b.ex",
          "position" => %{"line" => 2}
        }
      ]

      result = compiler_result_fixture(diagnostics)

      assert %Result{score: +0.0, errors: errors} = Compile.check_compilation(result)
      assert length(errors) == 2
      assert Enum.any?(errors, &String.contains?(&1, "Compilation Error"))
      assert Enum.any?(errors, &String.contains?(&1, "Compilation Warning"))
    end
  end
end

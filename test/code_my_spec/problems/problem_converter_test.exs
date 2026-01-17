defmodule CodeMySpec.Problems.ProblemConverterTest do
  use ExUnit.Case, async: true

  alias CodeMySpec.Problems.ProblemConverter
  alias CodeMySpec.Tests.TestError

  # ============================================================================
  # Fixtures - Credo Data
  # ============================================================================

  defp credo_high_priority do
    %{
      "priority" => 10,
      "category" => :readability,
      "check" => "Credo.Check.Readability.ModuleDoc",
      "message" => "Modules should have a @moduledoc tag.",
      "filename" => "lib/my_app/some_module.ex",
      "line_no" => 1,
      "column" => nil,
      "trigger" => "MyApp.SomeModule",
      "scope" => "MyApp.SomeModule"
    }
  end

  defp credo_medium_priority do
    %{
      "priority" => 5,
      "category" => :warning,
      "check" => "Credo.Check.Warning.UnusedEnumOperation",
      "message" => "There should be no unused Enum operations.",
      "filename" => "lib/my_app/controller.ex",
      "line_no" => 42,
      "column" => 5,
      "trigger" => "Enum.map",
      "scope" => "MyApp.Controller.index"
    }
  end

  defp credo_low_priority do
    %{
      "priority" => 1,
      "category" => :refactor,
      "check" => "Credo.Check.Refactor.Nesting",
      "message" => "Function is too deeply nested.",
      "filename" => "lib/my_app/helper.ex",
      "line_no" => 15,
      "column" => 3,
      "trigger" => nil,
      "scope" => "MyApp.Helper.deep_function"
    }
  end

  # ============================================================================
  # Fixtures - Dialyzer Data
  # ============================================================================

  defp dialyzer_function_has_no_local_return do
    %{
      "type" => :warn_return_no_exit,
      "file" => "lib/my_app/calculations.ex",
      "line" => 23,
      "message" => "Function calculate/2 has no local return.",
      "message_data" => %{
        "function" => "calculate",
        "arity" => 2
      }
    }
  end

  defp dialyzer_type_mismatch do
    %{
      "type" => :warn_contract_types,
      "file" => "lib/my_app/user.ex",
      "line" => 56,
      "message" =>
        "Type specification is not equal to the success typing: (integer()) -> binary().",
      "message_data" => %{
        "spec" => "(String.t()) -> integer()",
        "success_typing" => "(integer()) -> binary()"
      }
    }
  end

  defp dialyzer_unknown_function do
    %{
      "type" => :warn_callgraph,
      "file" => "lib/my_app/api.ex",
      "line" => 101,
      "message" => "Call to unknown function NonExistent.do_something/1.",
      "message_data" => %{
        "function" => "NonExistent.do_something",
        "arity" => 1
      }
    }
  end

  # ============================================================================
  # Fixtures - Compiler Data
  # ============================================================================

  defp compiler_warning_unused_variable do
    %{
      "severity" => "warning",
      "file" => "lib/my_app/service.ex",
      "line" => 34,
      "message" => "variable \"result\" is unused (if the variable is not meant to be used, prefix it with an underscore)"
    }
  end

  defp compiler_warning_undefined_function do
    %{
      "severity" => "warning",
      "file" => "lib/my_app/workflow.ex",
      "line" => 72,
      "message" => "MyApp.NonExistent.do_work/1 is undefined or private"
    }
  end

  defp compiler_error do
    %{
      "severity" => "error",
      "file" => "lib/my_app/broken.ex",
      "line" => 12,
      "message" => "undefined function foo/2"
    }
  end

  defp compiler_multiline_error do
    %{
      "severity" => "error",
      "file" => "lib/my_app/syntax_error.ex",
      "line" => 5,
      "message" => """
      syntax error before: ')'
      Expected one of the following tokens:
        - end
        - ')'
      """
    }
  end

  # ============================================================================
  # Fixtures - Test Failure Data
  # ============================================================================

  defp test_failure_basic do
    %TestError{
      file: "test/my_app/user_test.exs",
      line: 45,
      message: """
      test user creation creates valid user
      Assertion with == failed
      code:  assert user.name == "John"
      left:  "Jane"
      right: "John"
      """
    }
  end

  # ============================================================================
  # from_credo/1 Tests
  # ============================================================================

  describe "from_credo/1" do
    test "correctly maps Credo priorities to severity levels" do
      high = ProblemConverter.from_credo(credo_high_priority())
      assert high.severity == :error

      medium = ProblemConverter.from_credo(credo_medium_priority())
      assert medium.severity == :warning

      low = ProblemConverter.from_credo(credo_low_priority())
      assert low.severity == :info
    end

    test "extracts file path and line number" do
      problem = ProblemConverter.from_credo(credo_high_priority())
      assert problem.file_path == "lib/my_app/some_module.ex"
      assert problem.line == 1
    end

    test "preserves original Credo check name in rule field" do
      problem = ProblemConverter.from_credo(credo_high_priority())
      assert problem.rule == "Credo.Check.Readability.ModuleDoc"
    end

    test "stores Credo-specific metadata" do
      problem = ProblemConverter.from_credo(credo_high_priority())
      assert is_map(problem.metadata)
      assert problem.metadata["check"] == "Credo.Check.Readability.ModuleDoc"
      assert problem.metadata["priority"] == 10
      assert problem.metadata["category"] == :readability
    end
  end

  # ============================================================================
  # from_dialyzer/1 Tests
  # ============================================================================

  describe "from_dialyzer/1" do
    test "sets severity to :warning" do
      no_return = ProblemConverter.from_dialyzer(dialyzer_function_has_no_local_return())
      assert no_return.severity == :warning

      type_mismatch = ProblemConverter.from_dialyzer(dialyzer_type_mismatch())
      assert type_mismatch.severity == :warning

      unknown_fn = ProblemConverter.from_dialyzer(dialyzer_unknown_function())
      assert unknown_fn.severity == :warning
    end

    test "extracts location information correctly" do
      problem = ProblemConverter.from_dialyzer(dialyzer_function_has_no_local_return())
      assert problem.file_path == "lib/my_app/calculations.ex"
      assert problem.line == 23
    end

    test "categorizes all Dialyzer output as type Problems" do
      no_return = ProblemConverter.from_dialyzer(dialyzer_function_has_no_local_return())
      assert no_return.category == "type"

      type_mismatch = ProblemConverter.from_dialyzer(dialyzer_type_mismatch())
      assert type_mismatch.category == "type"

      unknown_fn = ProblemConverter.from_dialyzer(dialyzer_unknown_function())
      assert unknown_fn.category == "type"
    end

    test "preserves full warning message" do
      problem = ProblemConverter.from_dialyzer(dialyzer_function_has_no_local_return())
      assert problem.message == "Function calculate/2 has no local return."

      problem2 = ProblemConverter.from_dialyzer(dialyzer_type_mismatch())

      assert problem2.message ==
               "Type specification is not equal to the success typing: (integer()) -> binary()."
    end
  end

  # ============================================================================
  # from_compiler/1 Tests
  # ============================================================================

  describe "from_compiler/1" do
    test "distinguishes between compiler warnings and errors" do
      warning = ProblemConverter.from_compiler(compiler_warning_unused_variable())
      assert warning.severity == :warning

      error = ProblemConverter.from_compiler(compiler_error())
      assert error.severity == :error
    end

    test "handles compilation errors with appropriate severity" do
      problem = ProblemConverter.from_compiler(compiler_error())
      assert problem.severity == :error
      assert problem.message == "undefined function foo/2"
    end

    test "extracts multiline error messages" do
      problem = ProblemConverter.from_compiler(compiler_multiline_error())
      assert problem.severity == :error
      assert String.contains?(problem.message, "syntax error before: ')'")
      assert String.contains?(problem.message, "Expected one of the following tokens")
    end

    test "categorizes unused variable warnings separately from other Problems" do
      unused_var = ProblemConverter.from_compiler(compiler_warning_unused_variable())
      assert unused_var.category == "unused_variable"

      undefined_fn = ProblemConverter.from_compiler(compiler_warning_undefined_function())
      assert undefined_fn.category != "unused_variable"
    end
  end

  # ============================================================================
  # from_test_failure/1 Tests
  # ============================================================================

  describe "from_test_failure/1" do
    test "sets severity to :error for all test failures" do
      problem = ProblemConverter.from_test_failure(test_failure_basic())
      assert problem.severity == :error
    end

    test "extracts test file location" do
      problem = ProblemConverter.from_test_failure(test_failure_basic())
      assert problem.file_path == "test/my_app/user_test.exs"
      assert problem.line == 45
    end

    test "includes test name in message" do
      problem = ProblemConverter.from_test_failure(test_failure_basic())
      assert String.contains?(problem.message, "test user creation creates valid user")
    end

    test "preserves assertion details in metadata" do
      problem = ProblemConverter.from_test_failure(test_failure_basic())
      assert is_map(problem.metadata)
      assert problem.metadata["full_message"] == test_failure_basic().message
    end

    test "categorizes as \"test_failure\"" do
      problem = ProblemConverter.from_test_failure(test_failure_basic())
      assert problem.category == "test_failure"
    end
  end
end

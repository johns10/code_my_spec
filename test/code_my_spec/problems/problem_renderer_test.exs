defmodule CodeMySpec.Problems.ProblemRendererTest do
  use ExUnit.Case, async: true

  alias CodeMySpec.Problems.Problem
  alias CodeMySpec.Problems.ProblemRenderer

  describe "render/2" do
    test "renders problem with file path and line number" do
      problem = build_problem(file_path: "lib/my_app/foo.ex", line: 42)

      result = ProblemRenderer.render(problem)

      assert result =~ "lib/my_app/foo.ex:42"
    end

    test "renders problem without line number" do
      problem = build_problem(file_path: "lib/my_app/foo.ex", line: nil)

      result = ProblemRenderer.render(problem)

      assert result =~ "lib/my_app/foo.ex"
      refute result =~ "lib/my_app/foo.ex:"
    end

    test "includes source tool name when include_source is true" do
      problem = build_problem(source: "credo")

      result = ProblemRenderer.render(problem, include_source: true)

      assert result =~ "credo"
    end

    test "omits source tool name when include_source is false" do
      problem = build_problem(source: "credo")

      result = ProblemRenderer.render(problem, include_source: false)

      refute result =~ "credo"
    end

    test "renders compact format as single line" do
      problem =
        build_problem(
          file_path: "lib/my_app/foo.ex",
          line: 42,
          severity: :error,
          message: "Module doc missing"
        )

      result = ProblemRenderer.render(problem, format: :compact)

      refute result =~ "\n"
      assert result =~ "lib/my_app/foo.ex:42"
      assert result =~ "error"
      assert result =~ "Module doc missing"
    end

    test "renders text format with labeled fields" do
      problem =
        build_problem(
          file_path: "lib/my_app/foo.ex",
          line: 42,
          severity: :error,
          source: "credo",
          message: "Module doc missing"
        )

      result = ProblemRenderer.render(problem, format: :text)

      assert result =~ "lib/my_app/foo.ex:42"
      assert result =~ "error"
      assert result =~ "credo"
      assert result =~ "Module doc missing"
    end
  end

  describe "render_list/2" do
    test "returns empty string for empty list" do
      result = ProblemRenderer.render_list([])

      assert result == ""
    end

    test "renders multiple problems separated by newlines" do
      problems = [
        build_problem(message: "First problem"),
        build_problem(message: "Second problem")
      ]

      result = ProblemRenderer.render_list(problems)

      assert result =~ "First problem"
      assert result =~ "Second problem"
      assert result =~ "\n"
    end

    test "sorts problems by severity with errors first" do
      problems = [
        build_problem(severity: :info, message: "Info message"),
        build_problem(severity: :error, message: "Error message"),
        build_problem(severity: :warning, message: "Warning message")
      ]

      result = ProblemRenderer.render_list(problems)

      error_pos = :binary.match(result, "Error message") |> elem(0)
      warning_pos = :binary.match(result, "Warning message") |> elem(0)
      info_pos = :binary.match(result, "Info message") |> elem(0)

      assert error_pos < warning_pos
      assert warning_pos < info_pos
    end

    test "groups problems by severity when group_by is :severity" do
      problems = [
        build_problem(severity: :error, message: "Error 1"),
        build_problem(severity: :warning, message: "Warning 1"),
        build_problem(severity: :error, message: "Error 2")
      ]

      result = ProblemRenderer.render_list(problems, format: :grouped, group_by: :severity)

      assert result =~ "error"
      assert result =~ "warning"
    end

    test "groups problems by source when group_by is :source" do
      problems = [
        build_problem(source: "credo", message: "Credo issue"),
        build_problem(source: "credo", message: "Another credo issue")
      ]

      result = ProblemRenderer.render_list(problems, format: :grouped, group_by: :source)

      assert result =~ "credo"
    end

    test "groups problems by file_path when group_by is :file_path" do
      problems = [
        build_problem(file_path: "lib/foo.ex", message: "Foo issue"),
        build_problem(file_path: "lib/bar.ex", message: "Bar issue"),
        build_problem(file_path: "lib/foo.ex", message: "Another foo issue")
      ]

      result = ProblemRenderer.render_list(problems, format: :grouped, group_by: :file_path)

      assert result =~ "lib/foo.ex"
      assert result =~ "lib/bar.ex"
    end

    test "includes summary line with counts when include_summary is true" do
      problems = [
        build_problem(severity: :error),
        build_problem(severity: :warning),
        build_problem(severity: :warning)
      ]

      result = ProblemRenderer.render_list(problems, include_summary: true)

      assert result =~ "1 error"
      assert result =~ "2 warning"
    end

    test "omits summary line when include_summary is false" do
      problems = [
        build_problem(severity: :error),
        build_problem(severity: :warning)
      ]

      result = ProblemRenderer.render_list(problems, include_summary: false)

      refute result =~ ~r/\d+ error/
      refute result =~ ~r/\d+ warning/
    end
  end

  describe "render_summary/1" do
    test "returns \"No problems found\" for empty list" do
      result = ProblemRenderer.render_summary([])

      assert result == "No problems found"
    end

    test "returns count string for single severity" do
      problems = [
        build_problem(severity: :error),
        build_problem(severity: :error),
        build_problem(severity: :error)
      ]

      result = ProblemRenderer.render_summary(problems)

      assert result =~ "3 error"
    end

    test "returns combined counts for multiple severities" do
      problems = [
        build_problem(severity: :error),
        build_problem(severity: :warning),
        build_problem(severity: :warning),
        build_problem(severity: :info)
      ]

      result = ProblemRenderer.render_summary(problems)

      assert result =~ "1 error"
      assert result =~ "2 warning"
      assert result =~ "1 info"
    end

    test "orders counts as errors, warnings, info" do
      problems = [
        build_problem(severity: :info),
        build_problem(severity: :warning),
        build_problem(severity: :error)
      ]

      result = ProblemRenderer.render_summary(problems)

      error_pos = :binary.match(result, "error") |> elem(0)
      warning_pos = :binary.match(result, "warning") |> elem(0)
      info_pos = :binary.match(result, "info") |> elem(0)

      assert error_pos < warning_pos
      assert warning_pos < info_pos
    end
  end

  describe "render_summary_by_source/1" do
    test "returns \"No problems found\" for empty list" do
      result = ProblemRenderer.render_summary_by_source([])

      assert result == "No problems found"
    end

    test "groups counts by source tool" do
      problems = [
        build_problem(source: "credo", severity: :error)
      ]

      result = ProblemRenderer.render_summary_by_source(problems)

      assert result =~ "credo"
    end

    test "shows severity breakdown for each source" do
      problems = [
        build_problem(source: "credo", severity: :error),
        build_problem(source: "credo", severity: :warning),
        build_problem(source: "credo", severity: :warning)
      ]

      result = ProblemRenderer.render_summary_by_source(problems)

      assert result =~ "credo"
      assert result =~ "1 error"
      assert result =~ "2 warning"
    end

    test "orders sources alphabetically" do
      problems = [
        build_problem(source: "sobelow", severity: :error),
        build_problem(source: "credo", severity: :warning)
      ]

      result = ProblemRenderer.render_summary_by_source(problems)

      credo_pos = :binary.match(result, "credo") |> elem(0)
      sobelow_pos = :binary.match(result, "sobelow") |> elem(0)

      assert credo_pos < sobelow_pos
    end

    test "handles single source with multiple severities" do
      problems = [
        build_problem(source: "credo", severity: :error),
        build_problem(source: "credo", severity: :warning),
        build_problem(source: "credo", severity: :info)
      ]

      result = ProblemRenderer.render_summary_by_source(problems)

      assert result =~ "credo"
      assert result =~ "error"
      assert result =~ "warning"
      assert result =~ "info"
    end

    test "handles multiple sources with single severity each" do
      problems = [
        build_problem(source: "credo", severity: :warning),
        build_problem(source: "sobelow", severity: :error)
      ]

      result = ProblemRenderer.render_summary_by_source(problems)

      assert result =~ "credo"
      assert result =~ "sobelow"
    end
  end

  describe "render_for_feedback/2" do
    test "returns nil for empty list" do
      result = ProblemRenderer.render_for_feedback([])

      assert result == nil
    end

    test "includes context header when provided" do
      problems = [build_problem()]

      result =
        ProblemRenderer.render_for_feedback(problems, context: "Static analysis found issues:")

      assert result =~ "Static analysis found issues:"
    end

    test "includes summary of problem counts" do
      problems = [
        build_problem(severity: :error),
        build_problem(severity: :warning),
        build_problem(severity: :warning)
      ]

      result = ProblemRenderer.render_for_feedback(problems)

      assert result =~ "1 error"
      assert result =~ "2 warning"
    end

    test "limits output to max_problems" do
      problems =
        Enum.map(1..15, fn i ->
          build_problem(message: "Problem #{i}", line: i)
        end)

      result = ProblemRenderer.render_for_feedback(problems, max_problems: 5)

      matching_count =
        problems
        |> Enum.take(5)
        |> Enum.count(fn p -> result =~ p.message end)

      assert matching_count == 5
    end

    test "prioritizes errors over warnings when truncating" do
      problems = [
        build_problem(severity: :warning, message: "Warning 1"),
        build_problem(severity: :warning, message: "Warning 2"),
        build_problem(severity: :error, message: "Error 1"),
        build_problem(severity: :warning, message: "Warning 3"),
        build_problem(severity: :error, message: "Error 2")
      ]

      result = ProblemRenderer.render_for_feedback(problems, max_problems: 3)

      assert result =~ "Error 1"
      assert result =~ "Error 2"
    end

    test "includes truncation notice when problems are limited" do
      problems =
        Enum.map(1..15, fn i ->
          build_problem(message: "Problem #{i}", line: i)
        end)

      result = ProblemRenderer.render_for_feedback(problems, max_problems: 5)

      assert result =~ "10" or result =~ "truncated" or result =~ "more"
    end

    test "ends with actionable instruction for Claude" do
      problems = [build_problem()]

      result = ProblemRenderer.render_for_feedback(problems)

      assert result =~ "fix" or result =~ "address" or result =~ "resolve"
    end
  end

  # Fixture helpers

  defp build_problem(attrs \\ []) do
    defaults = [
      severity: :error,
      source_type: :static_analysis,
      source: "credo",
      file_path: "lib/my_app/example.ex",
      line: 42,
      message: "Modules should have a @moduledoc tag",
      category: "readability",
      rule: "Credo.Check.Readability.ModuleDoc",
      metadata: %{},
      project_id: Ecto.UUID.generate()
    ]

    merged = Keyword.merge(defaults, attrs)

    struct!(Problem, merged)
  end
end

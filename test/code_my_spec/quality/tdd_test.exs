defmodule CodeMySpec.Quality.TddTest do
  use ExUnit.Case, async: true

  alias CodeMySpec.Quality.Tdd
  alias CodeMySpec.Quality.Result

  # Fixtures

  defp test_result_fixture(test_run_data) when is_map(test_run_data) do
    %{
      data: test_run_data
    }
  end

  defp test_result_with_json_string_fixture(test_run_data) when is_map(test_run_data) do
    json_string = Jason.encode!(test_run_data)

    %{
      data: %{
        test_results: json_string
      }
    }
  end

  defp test_run_data_fixture(opts) do
    passes = Keyword.get(opts, :passes, 0)
    failures = Keyword.get(opts, :failures, 5)
    tests = passes + failures

    %{
      "project_path" => "/path/to/project",
      "command" => "mix test",
      "exit_code" => 1,
      "execution_status" => "failure",
      "raw_output" => "test output",
      "executed_at" => "2024-01-01T00:00:00",
      "stats" => %{
        "passes" => passes,
        "failures" => failures,
        "tests" => tests,
        "suites" => 1,
        "duration_ms" => 100,
        "started_at" => "2024-01-01T00:00:00",
        "finished_at" => "2024-01-01T00:00:01"
      }
    }
  end

  defp all_tests_failing_fixture do
    test_run_data_fixture(passes: 0, failures: 5)
  end

  defp some_tests_passing_fixture do
    test_run_data_fixture(passes: 2, failures: 3)
  end

  defp no_tests_executed_fixture do
    test_run_data_fixture(passes: 0, failures: 0)
  end

  defp invalid_schema_data_fixture do
    # Invalid execution_status enum value will cause changeset validation to fail
    %{
      "project_path" => "/path/to/project",
      "command" => "mix test",
      "execution_status" => "invalid_status",
      "raw_output" => "output",
      "executed_at" => "2024-01-01T00:00:00",
      "stats" => %{
        "passes" => 0,
        "failures" => 5,
        "tests" => 5,
        "suites" => 1,
        "duration_ms" => 100,
        "started_at" => "2024-01-01T00:00:00",
        "finished_at" => "2024-01-01T00:00:01"
      }
    }
  end

  # Tests for check_tdd_state/1

  describe "check_tdd_state/1" do
    test "returns score 1.0 when all tests are failing (TDD state correct)" do
      result = test_result_fixture(all_tests_failing_fixture())

      assert %Result{score: 1.0, errors: []} = Tdd.check_tdd_state(result)
    end

    test "returns score +0.0 when test results JSON is invalid" do
      result = %{
        data: %{
          test_results: "invalid json {{"
        }
      }

      assert %Result{score: +0.0, errors: errors} = Tdd.check_tdd_state(result)
      assert length(errors) == 1
      assert hd(errors) == "Invalid JSON in test results output"
    end

    test "returns score +0.0 when test run data is missing from result" do
      result = %{data: %{}}

      assert %Result{score: +0.0, errors: errors} = Tdd.check_tdd_state(result)
      assert length(errors) == 1
      assert hd(errors) == "Test run data not found in result"
    end

    test "returns score +0.0 when test run data fails schema validation" do
      result = test_result_fixture(invalid_schema_data_fixture())

      assert %Result{score: +0.0, errors: errors} = Tdd.check_tdd_state(result)
      # Schema validation returns a list of field errors in "field: message" format
      assert is_list(errors)
      assert length(errors) > 0
      # Check that errors follow the "field: message" format
      assert Enum.all?(errors, fn error -> String.contains?(error, ": ") end)
    end

    test "returns score +0.0 when some tests are passing" do
      result = test_result_fixture(some_tests_passing_fixture())

      assert %Result{score: +0.0, errors: errors} = Tdd.check_tdd_state(result)
      assert length(errors) == 1
      error = hd(errors)
      assert error =~ "2 test(s) are passing"
      assert error =~ "All tests should be failing in TDD mode"
    end

    test "returns score +0.0 when no tests were executed" do
      result = test_result_fixture(no_tests_executed_fixture())

      assert %Result{score: +0.0, errors: errors} = Tdd.check_tdd_state(result)
      assert length(errors) == 1
      assert hd(errors) == "No tests were executed"
    end

    test "handles test results as JSON string" do
      result = test_result_with_json_string_fixture(all_tests_failing_fixture())

      assert %Result{score: 1.0, errors: []} = Tdd.check_tdd_state(result)
    end

    test "handles test results as already-parsed map" do
      result = test_result_fixture(all_tests_failing_fixture())

      assert %Result{score: 1.0, errors: []} = Tdd.check_tdd_state(result)
    end

    test "includes descriptive error message for passing tests with exact count" do
      result = test_result_fixture(test_run_data_fixture(passes: 3, failures: 7))

      assert %Result{score: +0.0, errors: errors} = Tdd.check_tdd_state(result)
      assert length(errors) == 1
      error = hd(errors)
      assert error =~ "3 test(s) are passing"
      assert error =~ "All tests should be failing in TDD mode"
    end

    test "includes descriptive error message when test run data is missing" do
      result = %{data: %{}}

      assert %Result{score: +0.0, errors: errors} = Tdd.check_tdd_state(result)
      assert length(errors) == 1
      assert hd(errors) == "Test run data not found in result"
    end

    test "validates with real cached failing test data" do
      cache_path = CodeMySpec.Support.TestAdapter.test_results_failing_cache_path()

      if File.exists?(cache_path) do
        {:ok, json} = File.read(cache_path)
        {:ok, test_run_data} = Jason.decode(json)
        result = test_result_fixture(test_run_data)

        # The cached failing test should have failures > 0 and passes = 0
        assert %Result{score: score, errors: errors} = Tdd.check_tdd_state(result)

        # Verify the actual stats from the cache
        stats = test_run_data["stats"]

        if stats["failures"] > 0 and stats["passes"] == 0 do
          assert score == 1.0
          assert errors == []
        else
          # If the cache has passing tests, it should fail validation
          assert score == +0.0
          assert length(errors) > 0
        end
      else
        # If cache doesn't exist, skip this test
        :ok
      end
    end

    test "returns score 1.0 when failures > 0 and passes = 0 with multiple failing tests" do
      result = test_result_fixture(test_run_data_fixture(passes: 0, failures: 10))

      assert %Result{score: 1.0, errors: []} = Tdd.check_tdd_state(result)
    end

    test "returns score +0.0 when single test is passing among failures" do
      result = test_result_fixture(test_run_data_fixture(passes: 1, failures: 9))

      assert %Result{score: +0.0, errors: errors} = Tdd.check_tdd_state(result)
      assert length(errors) == 1
      error = hd(errors)
      assert error =~ "1 test(s) are passing"
      assert error =~ "All tests should be failing in TDD mode"
    end

    test "returns score +0.0 when all tests are passing" do
      result = test_result_fixture(test_run_data_fixture(passes: 5, failures: 0))

      assert %Result{score: +0.0, errors: errors} = Tdd.check_tdd_state(result)
      assert length(errors) == 1
      error = hd(errors)
      assert error =~ "5 test(s) are passing"
      assert error =~ "All tests should be failing in TDD mode"
    end
  end
end

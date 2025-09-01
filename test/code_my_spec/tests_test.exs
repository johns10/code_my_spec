# defmodule CodeMySpec.TestsTest do
#   use ExUnit.Case
#   doctest CodeMySpec.Tests

#   alias CodeMySpec.Tests
#   alias CodeMySpec.Tests.{TestRun, TestResult, TestStats, TestError}

#   @temp_dir System.tmp_dir!()

#   describe "parse_json_output/1" do
#     test "parses valid JSON output" do
#       json_output = """
#       ["start", {"including": [], "excluding": []}]
#       ["pass", {"title": "test_pass", "fullTitle": "TestModule: test_pass"}]
#       ["end", {"duration": 100.0, "passes": 1, "failures": 0, "tests": 1, "suites": 1}]
#       """

#       assert {:ok, %TestRun{} = test_run} = Tests.parse_json_output(json_output)
#       assert test_run.stats.passes == 1
#       assert test_run.stats.failures == 0
#       assert length(test_run.results) == 1
#     end

#     test "handles malformed JSON" do
#       json_output = """
#       ["start", {"including": [], "excluding": []}]
#       invalid json
#       """

#       assert {:error, _reason} = Tests.parse_json_output(json_output)
#     end
#   end

#   describe "failed_tests/1" do
#     test "filters failed tests from results" do
#       test_run = %TestRun{
#         results: [
#           %TestResult{title: "test1", status: :passed},
#           %TestResult{title: "test2", status: :failed},
#           %TestResult{title: "test3", status: :passed},
#           %TestResult{title: "test4", status: :failed}
#         ]
#       }

#       failed = Tests.failed_tests(test_run)

#       assert length(failed) == 2
#       assert Enum.all?(failed, &(&1.status == :failed))
#       assert Enum.map(failed, & &1.title) == ["test2", "test4"]
#     end

#     test "returns empty list when no failures" do
#       test_run = %TestRun{
#         results: [
#           %TestResult{title: "test1", status: :passed},
#           %TestResult{title: "test2", status: :passed}
#         ]
#       }

#       assert Tests.failed_tests(test_run) == []
#     end
#   end

#   describe "passed_tests/1" do
#     test "filters passed tests from results" do
#       test_run = %TestRun{
#         results: [
#           %TestResult{title: "test1", status: :passed},
#           %TestResult{title: "test2", status: :failed},
#           %TestResult{title: "test3", status: :passed}
#         ]
#       }

#       passed = Tests.passed_tests(test_run)

#       assert length(passed) == 2
#       assert Enum.all?(passed, &(&1.status == :passed))
#       assert Enum.map(passed, & &1.title) == ["test1", "test3"]
#     end
#   end

#   describe "success?/1" do
#     test "returns true for successful execution with no stats" do
#       test_run = %TestRun{execution_status: :success, stats: nil}
#       assert Tests.success?(test_run) == true
#     end

#     test "returns true for successful execution with no failures" do
#       test_run = %TestRun{
#         execution_status: :success,
#         stats: %{failures: 0, passes: 5}
#       }

#       assert Tests.success?(test_run) == true
#     end

#     test "returns false for successful execution with failures" do
#       test_run = %TestRun{
#         execution_status: :success,
#         stats: %{failures: 2, passes: 3}
#       }

#       assert Tests.success?(test_run) == false
#     end

#     test "returns false for failed execution" do
#       test_run = %TestRun{execution_status: :failure, stats: %{failures: 0}}
#       assert Tests.success?(test_run) == false
#     end

#     test "returns false for timeout execution" do
#       test_run = %TestRun{execution_status: :timeout, stats: nil}
#       assert Tests.success?(test_run) == false
#     end
#   end

#   describe "run_tests_async/2" do
#     test "returns a Task that can be awaited" do
#       task = Tests.run_tests_async(@temp_dir, timeout: 1000)

#       assert %Task{} = task
#       result = Task.await(task, 5000)

#       # Should either succeed or fail, but return a TestRun
#       case result do
#         {:ok, %TestRun{}} -> :ok
#         {:error, _} -> :ok
#       end
#     end
#   end

#   describe "integration test with real project" do
#     @describetag :integration
#     @test_project_dir Path.join(@temp_dir, "test_project")

#     setup do
#       # Clean up any existing test project
#       if File.exists?(@test_project_dir) do
#         File.rm_rf!(@test_project_dir)
#       end

#       :ok
#     end

#     @tag timeout: 120_000
#     test "runs tests on cloned elixir project" do
#       # Clone the test project (suppress output)
#       {_output, 0} =
#         System.cmd("git", [
#           "clone",
#           "--quiet",
#           "https://github.com/johns10/test_project.git",
#           @test_project_dir
#         ])

#       # Change to project directory and install dependencies (suppress output)
#       {_output, 0} = System.cmd("mix", ["deps.get", "--quiet"], cd: @test_project_dir)

#       # Run tests through our Tests context
#       assert {:ok, %TestRun{} = test_run} = Tests.run_tests(@test_project_dir, timeout: 60_000)

#       # Verify execution details
#       assert test_run.execution_status == :failure
#       assert test_run.exit_code == 2
#       assert test_run.project_path == @test_project_dir
#       assert test_run.command == "mix test --formatter ExUnitJsonFormatter"
#       assert String.contains?(test_run.raw_output, "test_project")
#       assert %NaiveDateTime{} = test_run.executed_at
#       assert test_run.seed == nil
#       assert test_run.including == []
#       assert test_run.excluding == []

#       # Verify stats structure
#       assert %TestStats{} = test_run.stats
#       assert test_run.stats.tests == 5
#       assert test_run.stats.passes == 3
#       assert test_run.stats.failures == 2
#       assert test_run.stats.pending == 0
#       assert test_run.stats.invalid == 0
#       assert test_run.stats.suites == 1
#       assert test_run.stats.duration_ms == 0
#       assert test_run.stats.load_time_ms == nil
#       assert %NaiveDateTime{} = test_run.stats.started_at
#       assert %NaiveDateTime{} = test_run.stats.finished_at

#       # Verify test results structure
#       assert length(test_run.results) == 5

#       failed = Tests.failed_tests(test_run)
#       passed = Tests.passed_tests(test_run)

#       assert length(failed) == 2
#       assert length(passed) == 3

#       # Verify failed test structure
#       failing_test = Enum.find(failed, &(&1.title == "test fails"))
#       assert %TestResult{} = failing_test
#       assert failing_test.full_title == "Elixir.TestProjectTest: test fails"
#       assert failing_test.status == :failed
#       assert %TestError{} = failing_test.error
#       assert String.contains?(failing_test.error.file, "test_project_test.exs")
#       assert failing_test.error.line == 16
#       assert failing_test.error.message == "Test failed"

#       # Verify passed test structure
#       passing_test = Enum.find(passed, &(&1.title == "test adds"))
#       assert %TestResult{} = passing_test
#       assert passing_test.full_title == "Elixir.TestProjectTest: test adds"
#       assert passing_test.status == :passed
#       assert passing_test.error == nil

#       # Verify success logic
#       assert Tests.success?(test_run) == false
#     end

#     @tag timeout: 120_000
#     test "runs tests with --trace flag" do
#       # Clone the test project (suppress output)
#       {_output, 0} =
#         System.cmd("git", [
#           "clone",
#           "--quiet",
#           "https://github.com/johns10/test_project.git",
#           @test_project_dir
#         ])

#       # Change to project directory and install dependencies (suppress output)
#       {_output, 0} = System.cmd("mix", ["deps.get", "--quiet"], cd: @test_project_dir)

#       # Run tests with trace flag
#       assert {:ok, %TestRun{} = test_run} =
#                Tests.run_tests(@test_project_dir, trace: true, timeout: 60_000)

#       # Verify trace flag is in command
#       assert test_run.command == "mix test --formatter ExUnitJsonFormatter --trace"
#       assert String.contains?(test_run.raw_output, "test_project")

#       # Should still get proper results even with trace
#       assert test_run.execution_status == :failure
#       assert test_run.exit_code == 2
#       assert %TestStats{} = test_run.stats
#       assert test_run.stats.tests == 5
#       assert test_run.stats.passes == 3
#       assert test_run.stats.failures == 2
#       assert length(test_run.results) == 5
#     end
#   end
# end

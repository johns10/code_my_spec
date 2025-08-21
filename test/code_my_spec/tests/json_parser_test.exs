defmodule CodeMySpec.Tests.JsonParserTest do
  use ExUnit.Case
  doctest CodeMySpec.Tests.JsonParser

  alias CodeMySpec.Tests.JsonParser
  alias CodeMySpec.Tests.TestRun

  describe "parse_json_line/1" do
    test "parses start event" do
      line = ~s(["start", {"including": ["integration"], "excluding": ["slow"]}])

      assert {:ok, {:start, %{including: ["integration"], excluding: ["slow"]}}} =
               JsonParser.parse_json_line(line)
    end

    test "parses start event with empty arrays" do
      line = ~s(["start", {"including": [], "excluding": []}])

      assert {:ok, {:start, %{including: [], excluding: []}}} =
               JsonParser.parse_json_line(line)
    end

    test "parses pass event" do
      line = ~s(["pass", {"title": "test_name", "fullTitle": "Module: test_name"}])

      assert {:ok, {:pass, %{title: "test_name", full_title: "Module: test_name"}}} =
               JsonParser.parse_json_line(line)
    end

    test "parses fail event with error details" do
      line =
        ~s(["fail", {"title": "test_name", "fullTitle": "Module: test_name", "err": {"file": "test.exs", "line": 42, "message": "assertion failed"}}])

      assert {:ok, {:fail, %{title: "test_name", full_title: "Module: test_name", err: err}}} =
               JsonParser.parse_json_line(line)

      assert err["file"] == "test.exs"
      assert err["line"] == 42
      assert err["message"] == "assertion failed"
    end

    test "parses end event with stats" do
      line =
        ~s(["end", {"duration": 1500.5, "passes": 5, "failures": 2, "pending": 1, "invalid": 0, "tests": 8, "suites": 3}])

      assert {:ok, {:end, stats}} = JsonParser.parse_json_line(line)
      assert stats["duration"] == 1500.5
      assert stats["passes"] == 5
      assert stats["failures"] == 2
    end

    test "returns error for invalid JSON" do
      line = ~s(invalid json)

      assert {:error, {:invalid_json, %{line: _line, reason: _}}} =
               JsonParser.parse_json_line(line)
    end

    test "returns error for unknown event type" do
      line = ~s(["unknown", {"data": "value"}])

      assert {:error, {:unknown_event, %{type: "unknown", data: %{"data" => "value"}}}} =
               JsonParser.parse_json_line(line)
    end
  end

  describe "parse_json_output/1" do
    test "parses complete test run output" do
      json_output = """
      ["start", {"including": [], "excluding": []}]
      ["pass", {"title": "test_pass", "fullTitle": "TestModule: test_pass"}]
      ["fail", {"title": "test_fail", "fullTitle": "TestModule: test_fail", "err": {"file": "test.exs", "line": 15, "message": "Expected true, got false"}}]
      ["end", {"duration": 1200.0, "passes": 1, "failures": 1, "pending": 0, "invalid": 0, "tests": 2, "suites": 1}]
      """

      assert {:ok, %TestRun{} = test_run} = JsonParser.parse_json_output(json_output)

      assert test_run.execution_status == :success
      assert length(test_run.results) == 2
      assert test_run.stats.passes == 1
      assert test_run.stats.failures == 1
      assert test_run.stats.duration_ms == 1200
    end

    test "returns error for malformed JSON line" do
      json_output = """
      ["start", {"including": [], "excluding": []}]
      invalid json line
      ["end", {"duration": 100}]
      """

      assert {:error, {:invalid_json, %{line: "invalid json line"}}} =
               JsonParser.parse_json_output(json_output)
    end

    test "handles empty output" do
      assert {:ok, %TestRun{}} = JsonParser.parse_json_output("")
    end

    test "handles output with only whitespace" do
      assert {:ok, %TestRun{}} = JsonParser.parse_json_output("   \n  \n  ")
    end
  end

  describe "build_test_run_from_events/2" do
    test "builds TestRun from event list" do
      events = [
        {:start, %{including: ["integration"], excluding: ["slow"]}},
        {:pass, %{title: "test1", full_title: "Module: test1"}},
        {:fail, %{title: "test2", full_title: "Module: test2", err: %{"message" => "failed"}}},
        {:end, %{"duration" => 500.0, "passes" => 1, "failures" => 1}}
      ]

      metadata = %{
        project_path: "/path/to/project",
        command: "mix test",
        execution_status: :success,
        exit_code: 0
      }

      test_run = JsonParser.build_test_run_from_events(events, metadata)

      assert test_run.project_path == "/path/to/project"
      assert test_run.command == "mix test"
      assert test_run.including == ["integration"]
      assert test_run.excluding == ["slow"]
      assert length(test_run.results) == 2

      [pass_result, fail_result] = test_run.results
      assert pass_result.status == :passed
      assert fail_result.status == :failed
      assert fail_result.error.message == "failed"
    end

    test "handles events without metadata" do
      events = [
        {:start, %{including: [], excluding: []}},
        {:end, %{"duration" => 100.0, "passes" => 0, "failures" => 0}}
      ]

      test_run = JsonParser.build_test_run_from_events(events)

      assert test_run.project_path == ""
      assert test_run.command == ""
      assert test_run.execution_status == :success
    end

    test "handles missing start event" do
      events = [
        {:pass, %{title: "test1", full_title: "Module: test1"}},
        {:end, %{"duration" => 100.0}}
      ]

      test_run = JsonParser.build_test_run_from_events(events)

      assert test_run.including == []
      assert test_run.excluding == []
    end

    test "handles missing end event" do
      events = [
        {:start, %{including: [], excluding: []}},
        {:pass, %{title: "test1", full_title: "Module: test1"}}
      ]

      test_run = JsonParser.build_test_run_from_events(events)

      assert test_run.stats == nil
      assert length(test_run.results) == 1
    end
  end

  describe "error parsing" do
    test "parses error with file and line" do
      events = [
        {:fail,
         %{
           title: "test",
           full_title: "Module: test",
           err: %{"file" => "test.exs", "line" => 42, "message" => "failed"}
         }}
      ]

      test_run = JsonParser.build_test_run_from_events(events)

      [result] = test_run.results
      assert result.error.file == "test.exs"
      assert result.error.line == 42
      assert result.error.message == "failed"
    end

    test "parses error with only message" do
      events = [
        {:fail,
         %{
           title: "test",
           full_title: "Module: test",
           err: %{"message" => "something went wrong"}
         }}
      ]

      test_run = JsonParser.build_test_run_from_events(events)

      [result] = test_run.results
      assert result.error.file == nil
      assert result.error.line == nil
      assert result.error.message == "something went wrong"
    end

    test "handles malformed error data" do
      events = [
        {:fail,
         %{
           title: "test",
           full_title: "Module: test",
           err: %{"unexpected" => "format"}
         }}
      ]

      test_run = JsonParser.build_test_run_from_events(events)

      [result] = test_run.results
      assert result.error.file == nil
      assert result.error.line == nil
      assert String.contains?(result.error.message, "unexpected")
    end
  end

  describe "stats parsing" do
    test "parses complete stats" do
      events = [
        {:end,
         %{
           "duration" => 1500.5,
           "loadTime" => 200.3,
           "passes" => 10,
           "failures" => 2,
           "pending" => 1,
           "invalid" => 0,
           "tests" => 13,
           "suites" => 5,
           "start" => "2025-01-01T10:00:00",
           "end" => "2025-01-01T10:00:01.5"
         }}
      ]

      test_run = JsonParser.build_test_run_from_events(events)

      stats = test_run.stats
      # rounded
      assert stats.duration_ms == 1501
      # rounded
      assert stats.load_time_ms == 200
      assert stats.passes == 10
      assert stats.failures == 2
      assert stats.pending == 1
      assert stats.invalid == 0
      assert stats.tests == 13
      assert stats.suites == 5
    end

    test "handles missing optional stats fields" do
      events = [
        {:end,
         %{
           "duration" => 100.0,
           "passes" => 5,
           "failures" => 0
         }}
      ]

      test_run = JsonParser.build_test_run_from_events(events)

      stats = test_run.stats
      assert stats.duration_ms == 100
      assert stats.load_time_ms == nil
      # defaults
      assert stats.pending == 0
      assert stats.invalid == 0
    end
  end
end

defmodule CodeMySpec.ComponentCodingSessions.Steps.RunTestsTest do
  use CodeMySpec.DataCase

  alias CodeMySpec.ComponentCodingSessions.Steps.RunTests
  alias CodeMySpec.Sessions.{Command, Result}
  alias CodeMySpec.Tests.TestRun

  import CodeMySpec.UsersFixtures
  import CodeMySpec.ProjectsFixtures
  import CodeMySpec.ComponentsFixtures
  import CodeMySpec.SessionsFixtures

  describe "get_command/2" do
    test "returns command to run test file with JSON formatter" do
      scope = full_scope_fixture()
      project = project_fixture(scope, %{module_name: "MyApp"})
      component = component_fixture(scope, %{module_name: "MyComponent", project_id: project.id})

      session = %{component: component, project: project}

      assert {:ok, %Command{} = command} = RunTests.get_command(scope, session, [])
      assert command.module == RunTests
      assert command.command =~ "mix test test/my_app/my_component_test.exs"
      assert command.command =~ "--formatter ExUnitJsonFormatter"
    end
  end

  describe "handle_result/3" do
    setup do
      scope = full_scope_fixture()
      project = project_fixture(scope)
      component = component_fixture(scope, %{project_id: project.id})
      session = session_fixture(scope, %{project_id: project.id, component_id: component.id})

      %{scope: scope, session: session}
    end

    test "returns success when all tests pass", %{scope: scope, session: session} do
      test_run_data = %{
        "project_path" => "/test/path",
        "command" => "mix test",
        "exit_code" => 0,
        "execution_status" => "success",
        "seed" => 12345,
        "including" => [],
        "excluding" => [],
        "raw_output" => "...",
        "executed_at" => NaiveDateTime.utc_now(),
        "stats" => %{"total" => 5, "failures" => 0},
        "tests" => [],
        "failures" => [],
        "pending" => []
      }

      result = Result.success(test_run_data)

      assert {:ok, state_updates, updated_result} = RunTests.handle_result(scope, session, result)
      assert %TestRun{execution_status: :success} = state_updates["test_run"]
      assert updated_result.status == :ok
    end

    test "returns error when tests fail", %{scope: scope, session: session} do
      test_run_data = %{
        "project_path" => "/test/path",
        "command" => "mix test",
        "exit_code" => 1,
        "execution_status" => "failure",
        "seed" => 12345,
        "including" => [],
        "excluding" => [],
        "raw_output" => "...",
        "executed_at" => NaiveDateTime.utc_now(),
        "stats" => %{"total" => 5, "failures" => 2},
        "tests" => [],
        "failures" => [
          %{
            "title" => "test fails",
            "full_title" => "MyTest test fails",
            "status" => "failed",
            "error" => %{
              "file" => "test/my_test.exs",
              "line" => 10,
              "message" => "Expected true, got false"
            }
          }
        ],
        "pending" => []
      }

      result = Result.success(test_run_data)

      assert {:ok, state_updates, updated_result} = RunTests.handle_result(scope, session, result)
      assert %TestRun{execution_status: :failure} = state_updates["test_run"]
      assert updated_result.status == :error
      assert updated_result.error_message =~ "Test execution status: failure"
      assert updated_result.error_message =~ "1 test(s) failed"
      assert updated_result.error_message =~ "MyTest test fails"
      assert updated_result.error_message =~ "Expected true, got false"
    end

    test "returns error when test run data is invalid JSON", %{scope: scope, session: session} do
      result = %Result{status: :ok, stdout: "not valid json"}

      assert {:ok, _state_updates, updated_result} =
               RunTests.handle_result(scope, session, result)

      assert updated_result.status == :error
      assert updated_result.error_message =~ "invalid JSON"
    end

    test "returns error when test run data is missing", %{scope: scope, session: session} do
      result = %Result{status: :ok}

      assert {:ok, _state_updates, updated_result} =
               RunTests.handle_result(scope, session, result)

      assert updated_result.status == :error
      assert updated_result.error_message =~ "test run data not found"
    end

    test "stores test run in session state on success", %{scope: scope, session: session} do
      test_run_data = %{
        "project_path" => "/test/path",
        "command" => "mix test",
        "exit_code" => 0,
        "execution_status" => "success",
        "seed" => 12345,
        "including" => [],
        "excluding" => [],
        "raw_output" => "...",
        "executed_at" => NaiveDateTime.utc_now(),
        "stats" => %{"total" => 5, "failures" => 0},
        "tests" => [],
        "failures" => [],
        "pending" => []
      }

      result = Result.success(test_run_data)

      assert {:ok, state_updates, _updated_result} =
               RunTests.handle_result(scope, session, result)

      assert %TestRun{} = state_updates["test_run"]
      assert state_updates["test_run"].command == "mix test"
    end

    test "stores test run in session state on failure", %{scope: scope, session: session} do
      test_run_data = %{
        "project_path" => "/test/path",
        "command" => "mix test",
        "exit_code" => 1,
        "execution_status" => "failure",
        "seed" => 12345,
        "including" => [],
        "excluding" => [],
        "raw_output" => "...",
        "executed_at" => NaiveDateTime.utc_now(),
        "stats" => %{"total" => 5, "failures" => 1},
        "tests" => [],
        "failures" => [
          %{
            "title" => "test fails",
            "full_title" => "MyTest test fails",
            "status" => "failed",
            "error" => %{"message" => "Assertion failed"}
          }
        ],
        "pending" => []
      }

      result = Result.success(test_run_data)

      assert {:ok, state_updates, _updated_result} =
               RunTests.handle_result(scope, session, result)

      assert %TestRun{} = state_updates["test_run"]
      assert state_updates["test_run"].execution_status == :failure
    end
  end
end

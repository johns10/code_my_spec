defmodule CodeMySpec.ProjectCoordinator.ComponentAnalyzerTest do
  use CodeMySpec.DataCase
  doctest CodeMySpec.ProjectCoordinator.ComponentAnalyzer

  alias CodeMySpec.ProjectCoordinator.ComponentAnalyzer
  alias CodeMySpec.Components.{Component, ComponentStatus}
  alias CodeMySpec.Tests.{TestResult, TestError}
  alias CodeMySpec.ComponentsFixtures
  alias CodeMySpec.UsersFixtures

  describe "analyze_components/4" do
    test "returns component status for components with all files existing and tests passing" do
      scope = UsersFixtures.full_scope_fixture()

      components = [
        %Component{
          id: 1,
          name: "Users",
          module_name: "Users",
          type: :context,
          project_id: scope.active_project.id,
          project: scope.active_project,
          dependencies: []
        }
      ]

      file_list = [
        "docs/design/my_app/users.md",
        "lib/my_app/users.ex",
        "test/my_app/users_test.exs"
      ]

      failures = []

      result =
        ComponentAnalyzer.analyze_components(components, file_list, failures,
          scope: scope,
          persist: false
        )

      assert [%Component{id: 1, component_status: %ComponentStatus{} = status}] = result
      assert status.design_exists == true
      assert status.code_exists == true
      assert status.test_exists == true
      assert status.test_status == :passing
    end

    test "returns component status for components with missing files" do
      scope = UsersFixtures.full_scope_fixture()

      components = [
        %Component{
          id: 1,
          name: "Users",
          module_name: "Users",
          type: :context,
          project_id: scope.active_project.id,
          project: scope.active_project,
          dependencies: []
        }
      ]

      file_list = [
        # Only code file exists
        "lib/my_app/users.ex"
      ]

      failures = []

      result =
        ComponentAnalyzer.analyze_components(components, file_list, failures,
          scope: scope,
          persist: false
        )

      assert [%Component{id: 1, component_status: %ComponentStatus{} = status}] = result
      assert status.design_exists == false
      assert status.code_exists == true
      assert status.test_exists == false
      assert status.test_status == :not_run
    end

    test "returns component status for components with failing tests" do
      scope = UsersFixtures.full_scope_fixture()

      components = [
        %Component{
          id: 1,
          name: "Users",
          module_name: "Users",
          type: :context,
          project_id: scope.active_project.id,
          project: scope.active_project,
          dependencies: []
        }
      ]

      file_list = [
        "docs/design/my_app/users.md",
        "lib/my_app/users.ex",
        "test/my_app/users_test.exs"
      ]

      failures = [
        %TestResult{
          title: "validates email",
          full_title: "MyApp.UsersTest validates email",
          status: :failed,
          error: %TestError{
            file: "test/my_app/users_test.exs",
            line: 15,
            message: "Expected true, got false"
          }
        }
      ]

      result =
        ComponentAnalyzer.analyze_components(components, file_list, failures,
          scope: scope,
          persist: false
        )

      assert [%Component{id: 1, component_status: %ComponentStatus{} = status}] = result
      assert status.design_exists == true
      assert status.code_exists == true
      assert status.test_exists == true
      assert status.test_status == :failing
    end

    test "handles multiple components" do
      scope = UsersFixtures.full_scope_fixture()

      components = [
        %Component{
          id: 1,
          name: "Users",
          module_name: "Users",
          type: :context,
          project_id: scope.active_project.id,
          project: scope.active_project,
          dependencies: []
        },
        %Component{
          id: 2,
          name: "Posts",
          module_name: "Posts",
          type: :context,
          project_id: scope.active_project.id,
          project: scope.active_project,
          dependencies: []
        }
      ]

      file_list = [
        "docs/design/my_app/users.md",
        "lib/my_app/users.ex",
        "test/my_app/users_test.exs",
        # Posts missing design and test
        "lib/my_app/posts.ex"
      ]

      failures = []

      result =
        ComponentAnalyzer.analyze_components(components, file_list, failures,
          scope: scope,
          persist: false
        )

      assert [
               %Component{id: 1, component_status: %ComponentStatus{} = status1},
               %Component{id: 2, component_status: %ComponentStatus{} = status2}
             ] = result

      assert status1.design_exists == true
      assert status1.code_exists == true
      assert status1.test_exists == true
      assert status1.test_status == :passing

      assert status2.design_exists == false
      assert status2.code_exists == true
      assert status2.test_exists == false
      assert status2.test_status == :not_run
    end

    test "ignores test results from other files" do
      scope = UsersFixtures.full_scope_fixture()

      components = [
        %Component{
          id: 1,
          name: "Users",
          module_name: "Users",
          type: :context,
          project_id: scope.active_project.id,
          project: scope.active_project,
          dependencies: []
        }
      ]

      file_list = [
        "lib/my_app/users.ex",
        "test/my_app/users_test.exs"
      ]

      failures = [
        # This failure is from a different file, should be ignored
        %TestResult{
          title: "validates post",
          full_title: "MyApp.PostsTest validates post",
          status: :failed,
          error: %TestError{
            file: "test/my_app/posts_test.exs",
            line: 10,
            message: "Expected valid, got invalid"
          }
        }
      ]

      result =
        ComponentAnalyzer.analyze_components(components, file_list, failures,
          scope: scope,
          persist: false
        )

      assert [%Component{id: 1, component_status: %ComponentStatus{} = status}] = result
      assert status.design_exists == false
      assert status.code_exists == true
      assert status.test_exists == true
      # Should be passing, not failing
      assert status.test_status == :passing
    end

    test "handles nested module names correctly" do
      scope = UsersFixtures.full_scope_fixture()

      components = [
        %Component{
          id: 1,
          name: "UserProfile",
          module_name: "Accounts.UserProfile",
          type: :schema,
          project_id: scope.active_project.id,
          project: scope.active_project,
          dependencies: []
        }
      ]

      file_list = [
        "docs/design/my_app/accounts/user_profile.md",
        "lib/my_app/accounts/user_profile.ex",
        "test/my_app/accounts/user_profile_test.exs"
      ]

      failures = []

      result =
        ComponentAnalyzer.analyze_components(components, file_list, failures,
          scope: scope,
          persist: false
        )

      assert [%Component{id: 1, component_status: %ComponentStatus{} = status}] = result
      assert status.design_exists == true
      assert status.code_exists == true
      assert status.test_exists == true
      assert status.test_status == :passing
    end

    test "builds nested dependency trees with actual Component and Dependency records" do
      # Create components with actual database records and dependencies
      scope = UsersFixtures.full_scope_fixture()

      {_parent, _child} =
        ComponentsFixtures.component_with_dependencies_fixture(scope, %{
          name: "UserContext",
          module_name: "UserContext"
        })

      # Use the proper Components context function that preloads dependencies
      components = CodeMySpec.Components.list_components_with_dependencies(scope)

      # Create file list that matches some expected files
      file_list = [
        "docs/design/my_app/user_context.md",
        "lib/my_app/user_context.ex",
        "test/my_app/user_context_test.exs"
      ]

      failures = []

      result =
        ComponentAnalyzer.analyze_components(components, file_list, failures,
          scope: scope,
          persist: false
        )

      assert length(result) == 2

      # Find parent and child components (parent has dependencies, child doesn't)
      parent_result = Enum.find(result, fn c -> c.name == "UserContext" end)
      child_result = Enum.find(result, fn c -> c.name != "UserContext" end)

      # Verify parent has nested dependency with analyzed child
      assert %Component{
               name: "UserContext",
               component_status: %ComponentStatus{} = parent_status,
               dependencies: [%Component{component_status: %ComponentStatus{}}]
             } = parent_result

      # Verify child has empty dependencies
      assert %Component{
               dependencies: []
             } = child_result

      # Verify component statuses are computed
      assert parent_status.design_exists == true
      assert parent_status.code_exists == true
      assert parent_status.test_exists == true
    end

    test "returns empty list for empty components list" do
      scope = UsersFixtures.full_scope_fixture()

      result =
        ComponentAnalyzer.analyze_components([], [], [],
          scope: scope,
          persist: false
        )

      assert result == []
    end
  end
end

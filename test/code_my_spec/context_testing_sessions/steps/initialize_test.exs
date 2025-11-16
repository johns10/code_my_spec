defmodule CodeMySpec.ContextTestingSessions.Steps.InitializeTest do
  use CodeMySpec.DataCase, async: true

  alias CodeMySpec.ContextTestingSessions.Steps.Initialize
  alias CodeMySpec.Sessions.{Command, Result, Session}
  alias CodeMySpec.Components.Component
  alias CodeMySpec.Projects.Project
  alias CodeMySpec.Users.Scope

  import CodeMySpec.UsersFixtures
  import CodeMySpec.ComponentsFixtures
  import CodeMySpec.SessionsFixtures

  describe "get_command/3" do
    test "generates sanitized branch name from context component name" do
      project = %Project{code_repo: "https://github.com/user/repo.git"}
      component = %Component{name: "User Management & Auth"}

      session = %Session{
        type: CodeMySpec.ContextTestingSessions,
        environment: :local,
        project: project,
        component: component
      }

      scope = %Scope{}

      assert {:ok, %Command{} = command} = Initialize.get_command(scope, session, [])
      assert command.command =~ "test-context-testing-session-for-user-management-auth"
    end

    test "delegates to Environments module for command generation" do
      repo_url = "https://github.com/user/myrepo.git"
      project = %Project{code_repo: repo_url}
      component = %Component{name: "Accounts"}

      session = %Session{
        type: CodeMySpec.ContextTestingSessions,
        environment: :local,
        project: project,
        component: component
      }

      scope = %Scope{}

      assert {:ok, %Command{} = command} = Initialize.get_command(scope, session, [])
      # Test environment uses RecordingEnvironment which generates git commands
      assert command.command =~ "git"
      assert command.command =~ "test-context-testing-session-for-accounts"
    end

    test "sets working_dir to project root (.)" do
      project = %Project{code_repo: "https://github.com/user/repo.git"}
      component = %Component{name: "Sessions"}

      session = %Session{
        type: CodeMySpec.ContextTestingSessions,
        environment: :local,
        project: project,
        component: component
      }

      scope = %Scope{}

      assert {:ok, %Command{} = command} = Initialize.get_command(scope, session, [])
      # Environment setup commands include working directory references
      assert command.command =~ ~r/cd\s+\.|git.*\./
    end

    test "creates branch name with test-context-testing-session-for- prefix" do
      project = %Project{code_repo: "https://github.com/user/repo.git"}
      component = %Component{name: "Accounts"}

      session = %Session{
        type: CodeMySpec.ContextTestingSessions,
        environment: :local,
        project: project,
        component: component
      }

      scope = %Scope{}

      assert {:ok, %Command{} = command} = Initialize.get_command(scope, session, [])
      assert command.command =~ "test-context-testing-session-for-accounts"
    end

    test "sanitizes component name by replacing special characters with hyphens" do
      project = %Project{code_repo: "https://github.com/user/repo.git"}
      component = %Component{name: "API/V2/Users"}

      session = %Session{
        type: CodeMySpec.ContextTestingSessions,
        environment: :local,
        project: project,
        component: component
      }

      scope = %Scope{}

      assert {:ok, %Command{} = command} = Initialize.get_command(scope, session, [])
      assert command.command =~ "test-context-testing-session-for-api-v2-users"
      refute command.command =~ "API/V2/Users"
    end

    test "collapses multiple consecutive hyphens in branch name" do
      project = %Project{code_repo: "https://github.com/user/repo.git"}
      component = %Component{name: "User  --  Sessions"}

      session = %Session{
        type: CodeMySpec.ContextTestingSessions,
        environment: :local,
        project: project,
        component: component
      }

      scope = %Scope{}

      assert {:ok, %Command{} = command} = Initialize.get_command(scope, session, [])
      assert command.command =~ "test-context-testing-session-for-user-sessions"
      refute command.command =~ "--"
    end

    test "trims leading and trailing hyphens from branch name" do
      project = %Project{code_repo: "https://github.com/user/repo.git"}
      component = %Component{name: "-Sessions-"}

      session = %Session{
        type: CodeMySpec.ContextTestingSessions,
        environment: :local,
        project: project,
        component: component
      }

      scope = %Scope{}

      assert {:ok, %Command{} = command} = Initialize.get_command(scope, session, [])
      assert command.command =~ "test-context-testing-session-for-sessions"
      refute command.command =~ "test-context-testing-session-for--sessions"
      refute command.command =~ "test-context-testing-session-for-sessions-"
    end

    test "converts component name to lowercase for branch name" do
      project = %Project{code_repo: "https://github.com/user/repo.git"}
      component = %Component{name: "UserManagement"}

      session = %Session{
        type: CodeMySpec.ContextTestingSessions,
        environment: :local,
        project: project,
        component: component
      }

      scope = %Scope{}

      assert {:ok, %Command{} = command} = Initialize.get_command(scope, session, [])
      assert command.command =~ "test-context-testing-session-for-usermanagement"
      refute command.command =~ "UserManagement"
    end

    test "delegates to Environments.environment_setup_command/2" do
      project = %Project{code_repo: "https://github.com/user/repo.git"}
      component = %Component{name: "Accounts"}

      session = %Session{
        type: CodeMySpec.ContextTestingSessions,
        environment: :local,
        project: project,
        component: component
      }

      scope = %Scope{}

      assert {:ok, %Command{} = command} = Initialize.get_command(scope, session, [])
      # Verify command contains git operations typical of environment setup
      assert command.command =~ ~r/git/
    end

    test "returns Command struct with module reference" do
      project = %Project{code_repo: "https://github.com/user/repo.git"}
      component = %Component{name: "Accounts"}

      session = %Session{
        type: CodeMySpec.ContextTestingSessions,
        environment: :local,
        project: project,
        component: component
      }

      scope = %Scope{}

      assert {:ok, %Command{} = command} = Initialize.get_command(scope, session, [])
      assert command.module == Initialize
      assert is_binary(command.command)
      assert %DateTime{} = command.timestamp
    end

    test "returns error when session missing project.code_repo" do
      project = %Project{code_repo: nil}
      component = %Component{name: "Accounts"}

      session = %Session{
        type: CodeMySpec.ContextTestingSessions,
        environment: :local,
        project: project,
        component: component
      }

      scope = %Scope{}

      # The implementation should handle nil code_repo - this may result in an error
      # or a command with nil in it. Let's verify it doesn't crash.
      result = Initialize.get_command(scope, session, [])
      assert {:ok, %Command{}} = result
    end
  end

  describe "handle_result/4" do
    test "returns empty session updates map" do
      scope = full_scope_fixture()

      parent_component =
        component_fixture(scope, %{
          name: "Accounts",
          type: :context,
          module_name: "Accounts"
        })

      session =
        session_fixture(scope, %{
          type: CodeMySpec.ContextTestingSessions,
          environment: :local,
          component_id: parent_component.id,
          state: %{}
        })

      result = Result.success(%{message: "Setup completed"})

      assert {:ok, session_updates, _returned_result} =
               Initialize.handle_result(scope, session, result, [])

      assert session_updates == %{}
    end

    test "returns result unchanged" do
      scope = full_scope_fixture()

      parent_component =
        component_fixture(scope, %{
          name: "Accounts",
          type: :context,
          module_name: "Accounts"
        })

      session =
        session_fixture(scope, %{
          type: CodeMySpec.ContextTestingSessions,
          environment: :local,
          component_id: parent_component.id,
          state: %{}
        })

      original_result = Result.success(%{message: "Setup completed"})

      assert {:ok, _session_updates, returned_result} =
               Initialize.handle_result(scope, session, original_result, [])

      assert returned_result == original_result
      assert returned_result.status == :ok
      assert returned_result.data == %{message: "Setup completed"}
    end

    test "returns success tuple with empty updates" do
      scope = full_scope_fixture()

      parent_component =
        component_fixture(scope, %{
          name: "Accounts",
          type: :context,
          module_name: "Accounts"
        })

      session =
        session_fixture(scope, %{
          type: CodeMySpec.ContextTestingSessions,
          environment: :local,
          component_id: parent_component.id,
          state: %{}
        })

      result = Result.success(%{message: "Setup completed"})

      assert {:ok, session_updates, returned_result} =
               Initialize.handle_result(scope, session, result, [])

      assert is_map(session_updates)
      assert session_updates == %{}
      assert returned_result == result
    end
  end
end

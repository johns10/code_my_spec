defmodule CodeMySpec.ContextCodingSessions.Steps.InitializeTest do
  use CodeMySpec.DataCase, async: true

  alias CodeMySpec.ContextCodingSessions.Steps.Initialize
  alias CodeMySpec.Sessions.{Command, Result, Session}
  alias CodeMySpec.Components.Component
  alias CodeMySpec.Projects.Project
  alias CodeMySpec.Users.Scope

  describe "get_command/3" do
    test "returns a Command struct with proper module reference" do
      project = %Project{code_repo: "https://github.com/user/repo.git"}
      component = %Component{name: "Accounts"}

      session = %Session{
        type: CodeMySpec.ContextCodingSessions,
        environment: :local,
        project: project,
        component: component
      }

      scope = %Scope{}

      assert {:ok, %Command{} = command} = Initialize.get_command(scope, session, [])
      assert command.module == Initialize
      assert is_binary(command.command)
    end

    test "generates sanitized branch name from context component name" do
      project = %Project{code_repo: "https://github.com/user/repo.git"}
      component = %Component{name: "User Management & Auth"}

      session = %Session{
        type: CodeMySpec.ContextCodingSessions,
        environment: :local,
        project: project,
        component: component
      }

      scope = %Scope{}

      assert {:ok, %Command{} = command} = Initialize.get_command(scope, session, [])
      assert command.command =~ "code-context-coding-session-for-user-management-auth"
    end

    test "sanitizes component name by replacing special characters with hyphens" do
      project = %Project{code_repo: "https://github.com/user/repo.git"}
      component = %Component{name: "API/V2/Users"}

      session = %Session{
        type: CodeMySpec.ContextCodingSessions,
        environment: :local,
        project: project,
        component: component
      }

      scope = %Scope{}

      assert {:ok, %Command{} = command} = Initialize.get_command(scope, session, [])
      assert command.command =~ "code-context-coding-session-for-api-v2-users"
      refute command.command =~ "/"
    end

    test "collapses multiple consecutive hyphens in branch name" do
      project = %Project{code_repo: "https://github.com/user/repo.git"}
      component = %Component{name: "User  --  Sessions"}

      session = %Session{
        type: CodeMySpec.ContextCodingSessions,
        environment: :local,
        project: project,
        component: component
      }

      scope = %Scope{}

      assert {:ok, %Command{} = command} = Initialize.get_command(scope, session, [])
      assert command.command =~ "code-context-coding-session-for-user-sessions"
      refute command.command =~ "--"
    end

    test "trims leading and trailing hyphens from branch name" do
      project = %Project{code_repo: "https://github.com/user/repo.git"}
      component = %Component{name: "-Sessions-"}

      session = %Session{
        type: CodeMySpec.ContextCodingSessions,
        environment: :local,
        project: project,
        component: component
      }

      scope = %Scope{}

      assert {:ok, %Command{} = command} = Initialize.get_command(scope, session, [])
      assert command.command =~ "code-context-coding-session-for-sessions"
      refute command.command =~ "code-context-coding-session-for--sessions"
      refute command.command =~ "code-context-coding-session-for-sessions-"
    end

    test "converts component name to lowercase for branch name" do
      project = %Project{code_repo: "https://github.com/user/repo.git"}
      component = %Component{name: "UserManagement"}

      session = %Session{
        type: CodeMySpec.ContextCodingSessions,
        environment: :local,
        project: project,
        component: component
      }

      scope = %Scope{}

      assert {:ok, %Command{} = command} = Initialize.get_command(scope, session, [])
      assert command.command =~ "code-context-coding-session-for-usermanagement"
      refute command.command =~ "UserManagement"
    end
  end

  describe "handle_result/4" do
    test "returns result unchanged" do
      project = %Project{code_repo: "https://github.com/user/repo.git"}
      component = %Component{name: "Sessions"}

      session = %Session{
        type: CodeMySpec.ContextCodingSessions,
        environment: :local,
        project: project,
        component: component,
        state: %{}
      }

      scope = %Scope{}
      original_result = Result.success(%{message: "Setup completed"})

      assert {:ok, _session_updates, returned_result} =
               Initialize.handle_result(scope, session, original_result, [])

      assert returned_result == original_result
      assert returned_result.status == :ok
      assert returned_result.data == %{message: "Setup completed"}
    end

    test "returns session updates with branch name and timestamp" do
      project = %Project{code_repo: "https://github.com/user/repo.git"}
      component = %Component{name: "Sessions"}

      session = %Session{
        type: CodeMySpec.ContextCodingSessions,
        environment: :local,
        project: project,
        component: component,
        state: %{}
      }

      scope = %Scope{}
      result = Result.success(%{message: "Setup completed"})

      assert {:ok, session_updates, _returned_result} =
               Initialize.handle_result(scope, session, result, [])

      assert is_map(session_updates)
      assert %{state: state} = session_updates
      assert state.branch_name == "code-context-coding-session-for-sessions"
      assert %DateTime{} = state.initialized_at
    end

    test "merges state updates with existing session state" do
      project = %Project{code_repo: "https://github.com/user/repo.git"}
      component = %Component{name: "Accounts"}

      session = %Session{
        type: CodeMySpec.ContextCodingSessions,
        environment: :local,
        project: project,
        component: component,
        state: %{existing_key: "existing_value"}
      }

      scope = %Scope{}
      result = Result.success(%{message: "Setup completed"})

      assert {:ok, session_updates, _returned_result} =
               Initialize.handle_result(scope, session, result, [])

      assert %{state: state} = session_updates
      assert state.existing_key == "existing_value"
      assert state.branch_name == "code-context-coding-session-for-accounts"
      assert %DateTime{} = state.initialized_at
    end
  end
end

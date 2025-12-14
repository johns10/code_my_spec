defmodule CodeMySpec.ContextComponentsDesignSessions.Steps.InitializeTest do
  use CodeMySpec.DataCase, async: true

  alias CodeMySpec.ContextComponentsDesignSessions.Steps.Initialize
  alias CodeMySpec.Sessions.{Command, Result, Session}
  alias CodeMySpec.Components.Component
  alias CodeMySpec.Projects.Project
  alias CodeMySpec.Users.Scope

  describe "get_command/3" do
    test "generates setup command for local environment" do
      project = %Project{code_repo: "https://github.com/user/repo.git"}
      component = %Component{name: "Accounts"}

      session = %Session{
        type: CodeMySpec.ContextComponentsDesignSessions,
        environment: :local,
        project: project,
        component: component
      }

      scope = %Scope{}

      assert {:ok, %Command{} = command} = Initialize.get_command(scope, session, [])
      assert command.module == Initialize

      assert command.command =~
               "git -C docs switch -C docs-context-components-design-session-for-accounts"
    end

    test "generates setup command for vscode environment" do
      project = %Project{code_repo: "https://github.com/user/repo.git"}
      component = %Component{name: "Users"}

      session = %Session{
        type: CodeMySpec.ContextComponentsDesignSessions,
        environment: :vscode,
        project: project,
        component: component
      }

      scope = %Scope{}

      assert {:ok, %Command{} = command} = Initialize.get_command(scope, session, [])
      assert command.module == Initialize
      # VSCode environment returns empty command
      assert command.command ==
               "git -C docs switch -C docs-context-components-design-session-for-users"
    end

    test "sanitizes component name in branch" do
      project = %Project{code_repo: "https://github.com/user/repo.git"}
      component = %Component{name: "User Management & Auth"}

      session = %Session{
        type: CodeMySpec.ContextComponentsDesignSessions,
        environment: :local,
        project: project,
        component: component
      }

      scope = %Scope{}

      assert {:ok, %Command{} = command} = Initialize.get_command(scope, session, [])
      assert command.command =~ "docs-context-components-design-session-for-user-management-auth"
    end

    test "uses docs as working directory" do
      project = %Project{code_repo: "https://github.com/user/repo.git"}
      component = %Component{name: "API"}

      session = %Session{
        type: CodeMySpec.ContextComponentsDesignSessions,
        environment: :local,
        project: project,
        component: component
      }

      scope = %Scope{}

      assert {:ok, %Command{} = command} = Initialize.get_command(scope, session, [])
      assert command.command =~ "git -C docs"
    end
  end

  describe "handle_result/4" do
    test "returns empty updates and passes through result unchanged" do
      session = %Session{}
      scope = %Scope{}
      result = Result.success(%{message: "Setup completed"})

      assert {:ok, session_updates, returned_result} =
               Initialize.handle_result(scope, session, result, [])

      assert session_updates == %{}
      assert returned_result == result
    end

    test "handles error results" do
      session = %Session{}
      scope = %Scope{}
      result = Result.error("Setup failed")

      assert {:ok, session_updates, returned_result} =
               Initialize.handle_result(scope, session, result, [])

      assert session_updates == %{}
      assert returned_result == result
    end
  end
end

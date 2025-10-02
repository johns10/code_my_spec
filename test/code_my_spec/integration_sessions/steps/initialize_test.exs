defmodule CodeMySpec.IntegrationSessions.Steps.InitializeTest do
  use CodeMySpec.DataCase

  alias CodeMySpec.ComponentCodingSessions.Steps.Initialize
  alias CodeMySpec.Sessions.Command

  import CodeMySpec.UsersFixtures
  import CodeMySpec.ProjectsFixtures
  import CodeMySpec.ComponentsFixtures
  import CodeMySpec.SessionsFixtures

  describe "get_command/2" do
    test "returns command to clone repo, checkout branch, and install dependencies" do
      scope = full_scope_fixture()

      project =
        project_fixture(scope, %{
          module_name: "MyTestApp",
          code_repo: "https://github.com/test/my_test_app.git"
        })

      component =
        component_fixture(scope, %{
          name: "TestComponent",
          module_name: "MyTestApp.TestComponent",
          project_id: project.id
        })

      session =
        session_fixture(scope, %{
          component_id: component.id,
          project_id: project.id,
          type: CodeMySpec.ComponentCodingSessions,
          environment: :local
        })

      session = %{session | component: component, project: project}

      assert {:ok, %Command{} = command} = Initialize.get_command(scope, session)
      assert command.module == Initialize
      assert command.command =~ "git clone https://github.com/test/my_test_app.git"
      assert command.command =~ "cd my_test_app"
      assert command.command =~ "git switch -C code-component-coding-session-for-testcomponent"
      assert command.command =~ "mix deps.get"
    end

    test "uses session environment to determine command format" do
      scope = full_scope_fixture()

      project =
        project_fixture(scope, %{
          module_name: "MyApp",
          code_repo: "https://github.com/user/my_app.git"
        })

      component =
        component_fixture(scope, %{
          name: "UserService",
          module_name: "MyApp.UserService",
          project_id: project.id
        })

      session =
        session_fixture(scope, %{
          component_id: component.id,
          project_id: project.id,
          type: CodeMySpec.ComponentCodingSessions,
          environment: :local
        })

      session = %{session | component: component, project: project}

      assert {:ok, %Command{}} = Initialize.get_command(scope, session)
    end

    test "generates branch name based on component name" do
      scope = full_scope_fixture()

      project =
        project_fixture(scope, %{
          module_name: "TestApp",
          code_repo: "https://github.com/test/test_app.git"
        })

      component =
        component_fixture(scope, %{
          name: "UserAuthentication",
          module_name: "TestApp.UserAuthentication",
          project_id: project.id
        })

      session =
        session_fixture(scope, %{
          component_id: component.id,
          project_id: project.id,
          type: CodeMySpec.ComponentCodingSessions,
          environment: :local
        })

      session = %{session | component: component, project: project}

      assert {:ok, %Command{} = command} = Initialize.get_command(scope, session)
      assert command.command =~ "code-component-coding-session-for-userauthentication"
    end

    test "sanitizes component name with special characters for branch name" do
      scope = full_scope_fixture()

      project =
        project_fixture(scope, %{
          module_name: "TestApp",
          code_repo: "https://github.com/test/test_app.git"
        })

      component =
        component_fixture(scope, %{
          name: "User@Authentication#Service",
          module_name: "TestApp.UserAuthenticationService",
          project_id: project.id
        })

      session =
        session_fixture(scope, %{
          component_id: component.id,
          project_id: project.id,
          type: CodeMySpec.ComponentCodingSessions,
          environment: :local
        })

      session = %{session | component: component, project: project}

      assert {:ok, %Command{} = command} = Initialize.get_command(scope, session)
      assert command.command =~ "code-component-coding-session-for-user-authentication-service"
      refute command.command =~ "@"
      refute command.command =~ "#"
    end

    test "extracts project name from git URL for clone destination" do
      scope = full_scope_fixture()

      project =
        project_fixture(scope, %{
          module_name: "PhoenixApp",
          code_repo: "https://github.com/org/phoenix_app.git"
        })

      component =
        component_fixture(scope, %{
          name: "Blog",
          module_name: "PhoenixApp.Blog",
          project_id: project.id
        })

      session =
        session_fixture(scope, %{
          component_id: component.id,
          project_id: project.id,
          type: CodeMySpec.ComponentCodingSessions,
          environment: :local
        })

      session = %{session | component: component, project: project}

      assert {:ok, %Command{} = command} = Initialize.get_command(scope, session)
      assert command.command =~ "git clone https://github.com/org/phoenix_app.git phoenix_app"
      assert command.command =~ "cd phoenix_app"
    end

    test "uses working directory from session or defaults to current directory" do
      scope = full_scope_fixture()

      project =
        project_fixture(scope, %{
          module_name: "MyApp",
          code_repo: "https://github.com/user/my_app.git"
        })

      component =
        component_fixture(scope, %{
          name: "Service",
          module_name: "MyApp.Service",
          project_id: project.id
        })

      session =
        session_fixture(scope, %{
          component_id: component.id,
          project_id: project.id,
          type: CodeMySpec.ComponentCodingSessions,
          environment: :local
        })

      session = %{session | component: component, project: project}

      assert {:ok, %Command{} = command} = Initialize.get_command(scope, session)
      assert command.command =~ "cd ."
    end

    test "creates command with module reference" do
      scope = full_scope_fixture()

      project = project_fixture(scope, %{code_repo: "https://github.com/user/repo.git"})

      component =
        component_fixture(scope, %{
          name: "Test",
          project_id: project.id
        })

      session =
        session_fixture(scope, %{
          component_id: component.id,
          project_id: project.id,
          type: CodeMySpec.ComponentCodingSessions,
          environment: :local
        })

      session = %{session | component: component, project: project}

      assert {:ok, %Command{module: module}} = Initialize.get_command(scope, session)
      assert module == Initialize
    end

    test "handles repo URL without .git extension" do
      scope = full_scope_fixture()

      project =
        project_fixture(scope, %{
          module_name: "TestApp",
          code_repo: "https://github.com/user/test_app"
        })

      component =
        component_fixture(scope, %{
          name: "Component",
          project_id: project.id
        })

      session =
        session_fixture(scope, %{
          component_id: component.id,
          project_id: project.id,
          type: CodeMySpec.ComponentCodingSessions,
          environment: :local
        })

      session = %{session | component: component, project: project}

      assert {:ok, %Command{} = command} = Initialize.get_command(scope, session)
      assert command.command =~ "git clone https://github.com/user/test_app test_app"
    end

    test "generates multi-step bash command with proper chaining" do
      scope = full_scope_fixture()

      project =
        project_fixture(scope, %{
          code_repo: "https://github.com/user/repo.git"
        })

      component = component_fixture(scope, %{name: "Test", project_id: project.id})

      session =
        session_fixture(scope, %{
          component_id: component.id,
          project_id: project.id,
          type: CodeMySpec.ComponentCodingSessions,
          environment: :local
        })

      session = %{session | component: component, project: project}

      assert {:ok, %Command{} = command} = Initialize.get_command(scope, session)
      assert command.command =~ "&&"
      assert String.contains?(command.command, ["cd", "git clone", "git switch", "mix deps.get"])
    end
  end

  describe "handle_result/3" do
    test "returns success with empty state updates" do
      scope = full_scope_fixture()
      project = project_fixture(scope)
      component = component_fixture(scope, %{project_id: project.id})

      session =
        session_fixture(scope, %{
          project_id: project.id,
          component_id: component.id,
          type: CodeMySpec.ComponentCodingSessions
        })

      result = "Successfully initialized environment"

      assert {:ok, state_updates, returned_result} =
               Initialize.handle_result(scope, session, result)

      assert state_updates == %{}
      assert returned_result == result
    end

    test "returns result unchanged regardless of content" do
      scope = full_scope_fixture()
      project = project_fixture(scope)
      component = component_fixture(scope, %{project_id: project.id})

      session =
        session_fixture(scope, %{
          project_id: project.id,
          component_id: component.id,
          type: CodeMySpec.ComponentCodingSessions
        })

      result = "Environment setup with warnings"

      assert {:ok, %{}, returned_result} = Initialize.handle_result(scope, session, result)
      assert returned_result == result
    end

    test "handles empty result string" do
      scope = full_scope_fixture()
      project = project_fixture(scope)
      component = component_fixture(scope, %{project_id: project.id})

      session =
        session_fixture(scope, %{
          project_id: project.id,
          component_id: component.id,
          type: CodeMySpec.ComponentCodingSessions
        })

      result = ""

      assert {:ok, %{}, returned_result} = Initialize.handle_result(scope, session, result)
      assert returned_result == ""
    end

    test "handles result with git output" do
      scope = full_scope_fixture()
      project = project_fixture(scope)
      component = component_fixture(scope, %{project_id: project.id})

      session =
        session_fixture(scope, %{
          project_id: project.id,
          component_id: component.id,
          type: CodeMySpec.ComponentCodingSessions
        })

      result = """
      Cloning into 'test_app'...
      Switched to a new branch 'code-component-coding-session-for-test'
      """

      assert {:ok, %{}, returned_result} = Initialize.handle_result(scope, session, result)
      assert returned_result == result
    end

    test "does not modify result on error output" do
      scope = full_scope_fixture()
      project = project_fixture(scope)
      component = component_fixture(scope, %{project_id: project.id})

      session =
        session_fixture(scope, %{
          project_id: project.id,
          component_id: component.id,
          type: CodeMySpec.ComponentCodingSessions
        })

      result = "fatal: repository not found"

      assert {:ok, %{}, returned_result} = Initialize.handle_result(scope, session, result)
      assert returned_result == result
    end
  end
end
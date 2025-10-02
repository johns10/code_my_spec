defmodule CodeMySpec.ComponentCodingSessions.Steps.GenerateImplementationTest do
  use CodeMySpec.DataCase

  alias CodeMySpec.ComponentCodingSessions.Steps.GenerateImplementation
  alias CodeMySpec.Sessions.{Command}

  import CodeMySpec.UsersFixtures
  import CodeMySpec.ProjectsFixtures
  import CodeMySpec.ComponentsFixtures
  import CodeMySpec.SessionsFixtures

  describe "get_command/2" do
    test "returns command with component design and implementation instructions" do
      scope = full_scope_fixture()

      project =
        project_fixture(scope, %{
          module_name: "TestPhoenixProject",
          name: "Test Phoenix Project",
          description: "A test Phoenix project"
        })

      component =
        component_fixture(scope, %{
          module_name: "TestPhoenixProject.Blog.PostRepository",
          name: "PostRepository",
          type: :repository,
          description: "Repository for managing blog posts",
          project_id: project.id
        })

      component_design = """
      # PostRepository Component Design

      ## Purpose
      Repository for managing blog post operations.

      ## Public API
      - create_post/2
      - update_post/3
      - delete_post/2
      """

      session =
        session_fixture(scope, %{
          component_id: component.id,
          project_id: project.id,
          type: CodeMySpec.ComponentCodingSessions,
          state: %{"component_design" => component_design}
        })

      session = %{session | component: component, project: project}

      assert {:ok, %Command{} = command} = GenerateImplementation.get_command(scope, session)
      assert command.module == GenerateImplementation
      assert command.pipe =~ component_design
      assert command.pipe =~ "Test Phoenix Project"
      assert command.pipe =~ "PostRepository"
      assert command.pipe =~ "Generate the implementation"
      assert command.pipe =~ "lib/test_phoenix_project/blog/post_repository.ex"
    end

    test "includes project description in prompt" do
      scope = full_scope_fixture()

      project =
        project_fixture(scope, %{
          module_name: "MyApp",
          name: "My Application",
          description: "Application for testing"
        })

      component =
        component_fixture(scope, %{
          module_name: "MyApp.UserService",
          project_id: project.id
        })

      session =
        session_fixture(scope, %{
          component_id: component.id,
          project_id: project.id,
          type: CodeMySpec.ComponentCodingSessions,
          state: %{"component_design" => "# Design"}
        })

      session = %{session | component: component, project: project}

      assert {:ok, %Command{} = command} = GenerateImplementation.get_command(scope, session)
      assert command.pipe =~ "Application for testing"
    end

    test "includes component description when present" do
      scope = full_scope_fixture()
      project = project_fixture(scope, %{module_name: "MyApp"})

      component =
        component_fixture(scope, %{
          module_name: "MyApp.Service",
          description: "Handles user authentication",
          project_id: project.id
        })

      session =
        session_fixture(scope, %{
          component_id: component.id,
          project_id: project.id,
          type: CodeMySpec.ComponentCodingSessions,
          state: %{"component_design" => "# Design"}
        })

      session = %{session | component: component, project: project}

      assert {:ok, %Command{} = command} = GenerateImplementation.get_command(scope, session)
      assert command.pipe =~ "Handles user authentication"
    end

    test "handles missing component description" do
      scope = full_scope_fixture()
      project = project_fixture(scope, %{module_name: "MyApp"})

      component =
        component_fixture(scope, %{
          module_name: "MyApp.Service",
          description: nil,
          project_id: project.id
        })

      session =
        session_fixture(scope, %{
          component_id: component.id,
          project_id: project.id,
          type: CodeMySpec.ComponentCodingSessions,
          state: %{"component_design" => "# Design"}
        })

      session = %{session | component: component, project: project}

      assert {:ok, %Command{} = command} = GenerateImplementation.get_command(scope, session)
      assert command.pipe =~ "No description provided"
    end

    test "includes implementation-specific coding rules" do
      scope = full_scope_fixture()

      # Seed coding rules
      {:ok, _rule} =
        CodeMySpec.Rules.create_rule(scope, %{
          name: "code rule",
          content: "Write pure functions",
          component_type: "*",
          session_type: "code"
        })

      project = project_fixture(scope, %{module_name: "MyApp"})

      component =
        component_fixture(scope, %{
          module_name: "MyApp.Repository",
          type: :repository,
          project_id: project.id
        })

      session =
        session_fixture(scope, %{
          component_id: component.id,
          project_id: project.id,
          type: CodeMySpec.ComponentCodingSessions,
          state: %{"component_design" => "# Design"}
        })

      session = %{session | component: component, project: project}

      assert {:ok, %Command{} = command} = GenerateImplementation.get_command(scope, session)
      assert command.pipe =~ "Write pure functions"
      assert command.pipe =~ "Coding Rules:"
    end

    test "returns error when component design not in state" do
      scope = full_scope_fixture()
      project = project_fixture(scope, %{module_name: "MyApp"})

      component =
        component_fixture(scope, %{
          module_name: "MyApp.Service",
          project_id: project.id
        })

      session =
        session_fixture(scope, %{
          component_id: component.id,
          project_id: project.id,
          type: CodeMySpec.ComponentCodingSessions,
          state: %{}
        })

      session = %{session | component: component, project: project}

      assert {:error, "Component design not found in session state"} =
               GenerateImplementation.get_command(scope, session)
    end

    test "specifies correct target file path for implementation" do
      scope = full_scope_fixture()
      project = project_fixture(scope, %{module_name: "TestPhoenixProject"})

      component =
        component_fixture(scope, %{
          module_name: "TestPhoenixProject.Blog.PostRepository",
          project_id: project.id
        })

      session =
        session_fixture(scope, %{
          component_id: component.id,
          project_id: project.id,
          type: CodeMySpec.ComponentCodingSessions,
          state: %{"component_design" => "# Design"}
        })

      session = %{session | component: component, project: project}

      assert {:ok, %Command{} = command} = GenerateImplementation.get_command(scope, session)
      assert command.pipe =~ "lib/test_phoenix_project/blog/post_repository.ex"
    end

    test "creates agent with context_designer type and claude_code model" do
      scope = full_scope_fixture()
      project = project_fixture(scope, %{module_name: "MyApp"})

      component =
        component_fixture(scope, %{
          module_name: "MyApp.Service",
          project_id: project.id
        })

      session =
        session_fixture(scope, %{
          component_id: component.id,
          project_id: project.id,
          type: CodeMySpec.ComponentCodingSessions,
          state: %{"component_design" => "# Design"}
        })

      session = %{session | component: component, project: project}

      assert {:ok, %Command{} = command} = GenerateImplementation.get_command(scope, session)
      assert command.command =~ "claude"
    end

    test "includes implementation instructions in prompt" do
      scope = full_scope_fixture()
      project = project_fixture(scope, %{module_name: "MyApp"})

      component =
        component_fixture(scope, %{
          module_name: "MyApp.Service",
          project_id: project.id
        })

      session =
        session_fixture(scope, %{
          component_id: component.id,
          project_id: project.id,
          type: CodeMySpec.ComponentCodingSessions,
          state: %{"component_design" => "# Design"}
        })

      session = %{session | component: component, project: project}

      assert {:ok, %Command{} = command} = GenerateImplementation.get_command(scope, session)
      assert command.pipe =~ "Read the test file"
      assert command.pipe =~ "Create all necessary module files"
      assert command.pipe =~ "Ensure the implementation satisfies the tests"
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

      result = "Successfully generated implementation"

      assert {:ok, state_updates, returned_result} =
               GenerateImplementation.handle_result(scope, session, result)

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

      result = "Implementation complete with errors"

      assert {:ok, %{}, returned_result} =
               GenerateImplementation.handle_result(scope, session, result)

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

      assert {:ok, %{}, returned_result} =
               GenerateImplementation.handle_result(scope, session, result)

      assert returned_result == ""
    end
  end
end

defmodule CodeMySpec.ComponentDesignSessionsTest do
  alias CodeMySpec.Sessions.Interaction
  use CodeMySpec.DataCase
  import Mox
  import CodeMySpec.Support.CLIRecorder
  import CodeMySpec.{UsersFixtures, AccountsFixtures, ProjectsFixtures}
  alias CodeMySpec.{Sessions, Components}
  alias CodeMySpec.ComponentDesignSessions

  @test_repo_url "https://github.com/johns10/test_phoenix_project.git"

  describe "component design session workflow" do
    setup do
      # Configure application to use mock for local environment
      Application.put_env(:code_my_spec, :local_environment, CodeMySpec.MockEnvironment)

      # Use stub environment that automatically records
      stub_with(CodeMySpec.MockEnvironment, CodeMySpec.Support.RecordingEnvironment)

      user = user_fixture()
      account = account_fixture()
      member_fixture(user, account)

      project =
        user_scope_fixture(user, account)
        |> project_fixture(%{account_id: account.id, module_name: "TestPhoenixProject"})

      scope = user_scope_fixture(user, account, project)

      # Create test parent component (Blog context)
      {:ok, blog_context} =
        Components.create_component(scope, %{
          name: "Blog",
          type: :context,
          module_name: "TestPhoenixProject.Blog",
          description: "Blog context for managing posts"
        })

      # Create test component to design (PostService)
      {:ok, post_service} =
        Components.create_component(scope, %{
          name: "PostRepository",
          type: :repository,
          module_name: "TestPhoenixProject.Blog.PostRepository",
          description: "Repository for post persistence",
          parent_component_id: blog_context.id
        })

      %{scope: scope, blog_context: blog_context, post_service: post_service}
    end

    @tag timeout: 300_000
    # @tag :integration
    test "executes complete component design workflow", %{
      scope: scope,
      post_service: post_service
    } do
      project_dir = "test_phoenix_project"

      # Setup test project (clone only if doesn't exist)
      setup_test_project(project_dir)
      CodeMySpec.Sessions.subscribe_sessions(scope)

      # Use CLI recorder for the session
      use_cassette "component_design_workflow" do
        # Create component design session
        {:ok, session} =
          Sessions.create_session(scope, %{
            type: ComponentDesignSessions,
            agent: :claude_code,
            environment: :local,
            component_id: post_service.id
          })

        # Step 1: Initialize
        {:ok, initialize_interaction} = Sessions.next_command(scope, session.id)
        opts = [cd: "test_phoenix_project"]

        assert initialize_interaction.command.module ==
                 CodeMySpec.ComponentDesignSessions.Steps.Initialize

        [cmd | args] = String.split(initialize_interaction.command.command, " ")
        {:ok, initialize_output} = CodeMySpec.Environments.cmd(:local, cmd, args, opts)
        initialize_result = %{status: :ok, stdout: initialize_output, stderr: "", exit_code: 0}

        {:ok, session} =
          Sessions.handle_result(scope, session.id, initialize_interaction.id, initialize_result)

        assert_received {:updated, %CodeMySpec.Sessions.Session{interactions: [%Interaction{}]}}

        # Step 2: Read Context Design
        {:ok, read_context_interaction} = Sessions.next_command(scope, session.id)

        assert read_context_interaction.command.module ==
                 CodeMySpec.ComponentDesignSessions.Steps.ReadContextDesign

        [cmd | args] = String.split(read_context_interaction.command.command, " ")
        {:ok, context_design_content} = CodeMySpec.Environments.cmd(:local, cmd, args, opts)

        read_context_result = %{
          status: :ok,
          stdout: context_design_content,
          stderr: "",
          exit_code: 0
        }

        {:ok, session} =
          Sessions.handle_result(
            scope,
            session.id,
            read_context_interaction.id,
            read_context_result
          )

        assert String.starts_with?(session.state.context_design, "# Blog Context")

        assert_received {:updated,
                         %CodeMySpec.Sessions.Session{interactions: [_, %Interaction{}]}}

        # Step 3: Generate Component Design
        {:ok, generate_interaction} = Sessions.next_command(scope, session.id)

        assert generate_interaction.command.module ==
                 CodeMySpec.ComponentDesignSessions.Steps.GenerateComponentDesign

        {:ok, claude_output} =
          CodeMySpec.Environments.cmd(
            :local,
            "echo",
            ["Generated component design for PostRepository"],
            []
          )

        generate_result = %{status: :ok, stdout: claude_output, stderr: "", exit_code: 0}

        {:ok, session} =
          Sessions.handle_result(scope, session.id, generate_interaction.id, generate_result)

        assert_received {:updated,
                         %CodeMySpec.Sessions.Session{interactions: [_, _, %Interaction{}]}}

        # Step 4: Validate Design
        {:ok, validate_interaction} = Sessions.next_command(scope, session.id)

        assert validate_interaction.command.module ==
                 CodeMySpec.ComponentDesignSessions.Steps.ValidateDesign

        [cmd | args] = String.split(validate_interaction.command.command, " ")
        {:ok, component_validation_content} = CodeMySpec.Environments.cmd(:local, cmd, args, opts)

        validate_result = %{
          status: :ok,
          stdout: component_validation_content,
          stderr: "",
          exit_code: 0
        }

        {:ok, session} =
          Sessions.handle_result(scope, session.id, validate_interaction.id, validate_result)

        assert_received {:updated,
                         %CodeMySpec.Sessions.Session{interactions: [_, _, _, %Interaction{}]}}

        # Step 5: Finalize (assuming validation passes)
        {:ok, finalize_interaction} = Sessions.next_command(scope, session.id)

        assert finalize_interaction.command.module ==
                 CodeMySpec.ComponentDesignSessions.Steps.Finalize

        {:ok, finalize_output} =
          CodeMySpec.Environments.cmd(:local, "echo", ["Component design finalized"], [])

        finalize_result = %{status: :ok, stdout: finalize_output, stderr: "", exit_code: 0}

        {:ok, session} =
          Sessions.handle_result(scope, session.id, finalize_interaction.id, finalize_result)

        assert_received {:updated,
                         %CodeMySpec.Sessions.Session{interactions: [_, _, _, _, %Interaction{}]}}

        # Step 6: Session should be complete
        assert {:error, :session_complete} = Sessions.next_command(scope, session.id)

        # Verify final state
        assert session.state["component_design"] != nil
        assert is_binary(session.state["component_design"])
      end
    end
  end

  # Helper function to setup test project (only clone if needed)
  defp setup_test_project(project_dir) do
    if File.exists?(project_dir) do
      # Update existing repository
      System.cmd("git", ["fetch", "origin"], cd: project_dir)
      System.cmd("git", ["reset", "--hard", "origin/main"], cd: project_dir)
    else
      # Clone fresh copy
      System.cmd("git", [
        "clone",
        "--recurse-submodules",
        @test_repo_url,
        project_dir
      ])
    end

    # Ensure dependencies are up to date
    unless File.exists?(Path.join(project_dir, "deps")) do
      System.cmd("mix", ["deps.get"], cd: project_dir)
    end
  end
end

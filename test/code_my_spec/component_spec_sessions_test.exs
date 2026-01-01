defmodule CodeMySpec.ComponentSpecSessionsTest do
  alias CodeMySpec.Sessions.Interaction
  use CodeMySpec.DataCase
  import CodeMySpec.Support.CLIRecorder
  import CodeMySpec.{UsersFixtures, AccountsFixtures, ProjectsFixtures}
  alias CodeMySpec.{Sessions, Components}
  alias CodeMySpec.ComponentSpecSessions
  alias CodeMySpec.Sessions.Session

  alias CodeMySpec.ComponentSpecSessions.Steps.{
    Finalize,
    GenerateComponentSpec,
    Initialize,
    ReviseSpec,
    ValidateSpec
  }

  @test_repo_url "https://github.com/johns10/test_phoenix_project.git"

  describe "component design session workflow" do
    setup do
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
          description: "Repository for blog persistence",
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
      project_dir =
        "../code_my_spec_test_repos/component_design_session_#{System.unique_integer([:positive])}"

      # Setup test project using TestAdapter
      {:ok, ^project_dir} =
        CodeMySpec.Support.TestAdapter.clone(scope, @test_repo_url, project_dir)

      CodeMySpec.Sessions.subscribe_sessions(scope)

      # Use CLI recorder for the session
      use_cassette "component_design_workflow" do
        # Create component design session
        {:ok, session} =
          Sessions.create_session(scope, %{
            type: ComponentSpecSessions,
            agent: :claude_code,
            environment: :local,
            component_id: post_service.id,
            state: %{working_dir: project_dir}
          })

        # Step 1: Initialize
        {_, _, session} = execute_step(scope, session.id, Initialize)
        assert_received {:updated, %Session{interactions: [%Interaction{}]}}

        # Step 2: GenerateComponentSpec (async)
        {:ok, session} = Sessions.execute(scope, session.id)
        [interaction | _] = session.interactions
        assert interaction.command.module == GenerateComponentSpec

        # Create the design file that would have been created by Claude
        spec_file =
          Path.join([
            project_dir,
            "docs",
            "spec",
            "test_phoenix_project",
            "blog",
            "post_repository.spec.md"
          ])

        correct_content = File.read!(spec_file)
        File.mkdir_p!(Path.dirname(spec_file))
        File.write!(spec_file, invalid_post_repository_content())

        # Complete the async interaction
        {:ok, session} = Sessions.handle_result(scope, session.id, interaction.id, %{status: :ok})

        assert_received {:updated, %Session{interactions: [%Interaction{}, _]}}

        # Step 3: Validate Design
        {_, _, session} = execute_step(scope, session.id, ValidateSpec)

        assert_received {:updated,
                         %Session{
                           interactions: [interaction, _, _]
                         }}

        assert %Interaction{result: %{status: :error}} = interaction

        # Step 4: ReviseSpec (async)
        {:ok, session} = Sessions.execute(scope, session.id)
        [interaction | _] = session.interactions
        assert interaction.command.module == ReviseSpec

        # Update the design file with valid content
        File.write!(spec_file, correct_content)

        # Complete the async interaction
        {:ok, session} = Sessions.handle_result(scope, session.id, interaction.id, %{status: :ok})

        assert_received {:updated, %Session{interactions: [%Interaction{}, _, _, _]}}

        # Step 5: Revalidate Design
        {_, _, session} = execute_step(scope, session.id, ValidateSpec)

        assert_received {:updated,
                         %Session{
                           interactions: [interaction, _, _, _, _]
                         }}

        assert %Interaction{result: %{status: :ok}} = interaction

        # Step 6: Finalize (async)
        {:ok, session} = Sessions.execute(scope, session.id)
        [interaction | _] = session.interactions
        assert interaction.command.module == Finalize

        # Complete the async interaction
        {:ok, session} = Sessions.handle_result(scope, session.id, interaction.id, %{status: :ok})

        assert_received {:updated, %Session{interactions: [%Interaction{}, _, _, _, _, _]}}

        # Step 7: Session should be complete
        assert {:error, :complete} = Sessions.next_command(scope, session.id)
      end
    end
  end

  # Helper function to execute a session step with common pattern
  defp execute_step(scope, session_id, expected_module, opts \\ []) do
    {:ok, session} = Sessions.execute(scope, session_id, opts)
    [interaction | _] = session.interactions
    assert interaction.command.module == expected_module

    final_result = Map.get(interaction, :result)

    {interaction, final_result, session}
  end

  defp invalid_post_repository_content() do
    """
    # PostRepository Component Design

    ## Purpose
    Repository for managing blog persistence in the blog context.

    ## Interface
    - get_post/1
    - create_post/1
    - update_post/2
    - delete_post/1

    ## Implementation Notes
    Generated component design for PostRepository
    """
  end
end

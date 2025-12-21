defmodule CodeMySpec.ContextSpecSessionsTest do
  alias CodeMySpec.Sessions.Interaction
  use CodeMySpec.DataCase
  import CodeMySpec.Support.CLIRecorder
  import CodeMySpec.{UsersFixtures, AccountsFixtures, ProjectsFixtures}
  alias CodeMySpec.{Sessions, Components, Stories}
  alias CodeMySpec.ContextSpecSessions

  alias CodeMySpec.ContextSpecSessions.Steps.{
    Finalize,
    GenerateContextDesign,
    Initialize,
    ReviseDesign,
    ValidateDesign
  }

  @test_repo_url "https://github.com/johns10/test_phoenix_project.git"

  describe "context design session workflow" do
    setup do
      user = user_fixture()
      account = account_fixture()
      member_fixture(user, account)

      project =
        user_scope_fixture(user, account)
        |> project_fixture(%{account_id: account.id, module_name: "TestPhoenixProject"})

      scope = user_scope_fixture(user, account, project)

      # Create test context component to design (Blog context)
      {:ok, blog_context} =
        Components.create_component(scope, %{
          name: "Blog",
          type: :context,
          module_name: "TestPhoenixProject.Blog",
          description: "Blog context for managing posts and comments"
        })

      # Create some user stories for the context
      {:ok, story1} =
        Stories.create_story(scope, %{
          title: "Create blog posts",
          description: "As a user, I want to create blog posts",
          acceptance_criteria: ["User can create a post", "Post has title and content"],
          component_id: blog_context.id
        })

      {:ok, story2} =
        Stories.create_story(scope, %{
          title: "Comment on posts",
          description: "As a user, I want to comment on posts",
          acceptance_criteria: ["User can add comments", "Comments are associated with posts"],
          component_id: blog_context.id
        })

      %{
        scope: scope,
        project: project,
        blog_context: blog_context,
        story1: story1,
        story2: story2
      }
    end

    @tag timeout: 300_000
    # @tag :integration
    test "executes complete context design workflow", %{
      scope: scope,
      blog_context: blog_context
    } do
      project_dir =
        "../code_my_spec_test_repos/context_spec_session_#{System.unique_integer([:positive])}"

      # Setup test project using TestAdapter
      {:ok, ^project_dir} =
        CodeMySpec.Support.TestAdapter.clone(scope, @test_repo_url, project_dir)

      CodeMySpec.Sessions.subscribe_sessions(scope)

      # Use CLI recorder for the session
      use_cassette "context_design_workflow" do
        # Create context design session
        {:ok, session} =
          Sessions.create_session(scope, %{
            type: ContextSpecSessions,
            agent: :claude_code,
            environment: :local,
            component_id: blog_context.id,
            state: %{working_dir: project_dir}
          })

        # Step 1: Initialize
        {_, _, session} = execute_step(scope, session.id, Initialize)
        assert_received {:updated, %CodeMySpec.Sessions.Session{interactions: [%Interaction{}]}}

        # Step 2: GenerateContextDesign
        {:ok, session} = Sessions.execute(scope, session.id)
        [interaction | _] = session.interactions
        assert interaction.command.module == GenerateContextDesign

        # Create the design file that would have been created by Claude
        design_file =
          Path.join([
            project_dir,
            "docs",
            "spec",
            "test_phoenix_project",
            "blog.spec.md"
          ])

        File.mkdir_p!(Path.dirname(design_file))
        File.write!(design_file, valid_blog_context_content())

        # Complete the async interaction
        {:ok, session} = Sessions.handle_result(scope, session.id, interaction.id, %{status: :ok})

        assert_received {:updated,
                         %CodeMySpec.Sessions.Session{interactions: [%Interaction{}, _]}}

        # Step 3: Validate Design
        {_, _, session} = execute_step(scope, session.id, ValidateDesign)

        assert_received {:updated,
                         %CodeMySpec.Sessions.Session{
                           interactions: [interaction, _, _]
                         }}

        assert %Interaction{result: %{status: :ok}} = interaction

        # Step 4: Finalize
        {:ok, session} = Sessions.execute(scope, session.id)
        [interaction | _] = session.interactions
        assert interaction.command.module == Finalize

        # Complete the async interaction
        {:ok, session} = Sessions.handle_result(scope, session.id, interaction.id, %{status: :ok})

        assert_received {:updated,
                         %CodeMySpec.Sessions.Session{interactions: [%Interaction{}, _, _, _]}}

        # Step 5: Session should be complete
        assert {:error, :complete} = Sessions.next_command(scope, session.id)
      end
    end

    @tag timeout: 300_000
    # @tag :integration
    test "handles validation failure and retry", %{
      scope: scope,
      blog_context: blog_context
    } do
      project_dir =
        "../code_my_spec_test_repos/context_spec_session_retry_#{System.unique_integer([:positive])}"

      # Setup test project using TestAdapter
      {:ok, ^project_dir} =
        CodeMySpec.Support.TestAdapter.clone(scope, @test_repo_url, project_dir)

      CodeMySpec.Sessions.subscribe_sessions(scope)

      # Use CLI recorder for the session
      use_cassette "context_design_workflow_retry" do
        # Create context design session
        {:ok, session} =
          Sessions.create_session(scope, %{
            type: ContextSpecSessions,
            agent: :claude_code,
            environment: :local,
            component_id: blog_context.id,
            state: %{working_dir: project_dir}
          })

        # Step 1: Initialize
        {_, _, session} = execute_step(scope, session.id, Initialize)
        assert_received {:updated, %CodeMySpec.Sessions.Session{interactions: [%Interaction{}]}}

        # Step 2: GenerateContextDesign
        {:ok, session} = Sessions.execute(scope, session.id)
        [interaction | _] = session.interactions
        assert interaction.command.module == GenerateContextDesign

        # Create an invalid design file (missing required sections)
        design_file =
          Path.join([
            project_dir,
            "docs",
            "spec",
            "test_phoenix_project",
            "blog.spec.md"
          ])

        File.mkdir_p!(Path.dirname(design_file))
        File.write!(design_file, invalid_blog_context_content())

        # Complete the async interaction
        {:ok, session} = Sessions.handle_result(scope, session.id, interaction.id, %{status: :ok})

        assert_received {:updated,
                         %CodeMySpec.Sessions.Session{interactions: [%Interaction{}, _]}}

        # Step 3: Validate Design (should fail)
        {_, _, session} = execute_step(scope, session.id, ValidateDesign)

        assert_received {:updated,
                         %CodeMySpec.Sessions.Session{
                           interactions: [%Interaction{result: %{status: :error}}, _, _]
                         }}

        # Step 4: ReviseDesign (after validation failure)
        {:ok, session} = Sessions.execute(scope, session.id)
        [interaction | _] = session.interactions
        assert interaction.command.module == ReviseDesign

        # Update the design file with valid content
        File.write!(design_file, valid_blog_context_content())

        # Complete the async interaction
        {:ok, session} = Sessions.handle_result(scope, session.id, interaction.id, %{status: :ok})

        assert_received {:updated,
                         %CodeMySpec.Sessions.Session{interactions: [%Interaction{}, _, _, _]}}

        # Step 5: Revalidate Design (should pass)
        {_, _, session} = execute_step(scope, session.id, ValidateDesign)

        assert_received {:updated,
                         %CodeMySpec.Sessions.Session{
                           interactions: [interaction, _, _, _, _]
                         }}

        assert %Interaction{result: %{status: :ok}} = interaction

        # Step 6: Finalize
        {:ok, session} = Sessions.execute(scope, session.id)
        [interaction | _] = session.interactions
        assert interaction.command.module == Finalize

        # Complete the async interaction
        {:ok, session} = Sessions.handle_result(scope, session.id, interaction.id, %{status: :ok})

        assert_received {:updated,
                         %CodeMySpec.Sessions.Session{
                           interactions: [%Interaction{}, _, _, _, _, _]
                         }}

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

  defp invalid_blog_context_content() do
    """
    # TestPhoenixProject.Blog

    ## Dependencies
    - TestPhoenixProject.Accounts.User

    ## Components

    ### TestPhoenixProject.Blog.Post

    Post schema with title, content, and author.

    ## Poop face

    A section that isn't allowed
    """
  end

  defp valid_blog_context_content() do
    """
    # TestPhoenixProject.Blog

    ## Delegates
    - list_posts/1: TestPhoenixProject.Blog.PostRepository.list_posts/1
    - get_post/2: TestPhoenixProject.Blog.PostRepository.get_post/2
    - create_post/2: TestPhoenixProject.Blog.PostRepository.create_post/2
    - list_comments/2: TestPhoenixProject.Blog.CommentRepository.list_comments/2

    ## Functions

    ### create_post_with_validation/2

    Creates a new blog post with additional validation logic.

    ```elixir
    @spec create_post_with_validation(Scope.t(), map()) :: {:ok, Post.t()} | {:error, Changeset.t()}
    ```

    **Process**:
    1. Validate post attributes
    2. Check user permissions
    3. Delegate to PostRepository.create_post/2
    4. Return result

    **Test Assertions**:
    - create_post_with_validation/2 validates required fields
    - create_post_with_validation/2 checks user has permission
    - create_post_with_validation/2 delegates to repository

    ## Dependencies
    - TestPhoenixProject.Accounts.User
    - TestPhoenixProject.Blog.PostRepository
    - TestPhoenixProject.Blog.CommentRepository
    - TestPhoenixProject.Repo

    ## Components

    ### TestPhoenixProject.Blog.Post

    Post schema with title, content, and author.

    ### TestPhoenixProject.Blog.Comment

    Comment schema associated with posts.

    ### TestPhoenixProject.Blog.PostRepository

    Repository for post persistence operations.

    ### TestPhoenixProject.Blog.CommentRepository

    Repository for comment persistence operations.
    """
  end
end

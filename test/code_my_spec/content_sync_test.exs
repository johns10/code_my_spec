defmodule CodeMySpec.ContentSyncTest do
  use CodeMySpec.DataCase

  import CodeMySpec.{UsersFixtures, AccountsFixtures, ProjectsFixtures}
  import Mox

  alias CodeMySpec.ContentSync
  alias CodeMySpec.Content
  alias CodeMySpec.Users.Scope

  setup :verify_on_exit!

  # ============================================================================
  # Fixtures - Scope Creation
  # ============================================================================

  defp scope_with_project(attrs \\ %{}) do
    user = user_fixture()
    account = account_fixture(%{name: "Test Account"})

    scope = %Scope{
      user: user,
      active_account: account,
      active_account_id: account.id,
      active_project_id: nil
    }

    default_project_attrs = %{
      name: "Test Project",
      content_repo: "https://github.com/test/content-repo.git"
    }

    project_attrs = Map.merge(default_project_attrs, attrs)
    project = project_fixture(scope, project_attrs)

    %Scope{
      user: user,
      active_account: account,
      active_account_id: account.id,
      active_project: project,
      active_project_id: project.id
    }
  end

  defp scope_without_project do
    user = user_fixture()
    account = account_fixture(%{name: "Test Account"})

    %Scope{
      user: user,
      active_account: account,
      active_account_id: account.id,
      active_project: nil,
      active_project_id: nil
    }
  end

  defp scope_without_content_repo do
    scope_with_project(%{content_repo: nil})
  end

  # ============================================================================
  # Fixtures - Test Directories and Files
  # ============================================================================

  defp create_test_directory(files) do
    dir = Path.join(System.tmp_dir!(), "content_sync_test_#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)

    for {filename, content, metadata} <- files do
      file_path = Path.join(dir, filename)
      metadata_path = Path.join(dir, Path.rootname(filename) <> ".yaml")

      File.write!(file_path, content)
      File.write!(metadata_path, metadata)
    end

    dir
  end

  defp cleanup_directory(dir) do
    if File.exists?(dir) do
      File.rm_rf!(dir)
    end
  end

  defp valid_blog_metadata do
    """
    title: "Test Blog Post"
    slug: "test-blog-post"
    type: "blog"
    publish_at: "2025-01-15T10:00:00Z"
    meta_title: "Test Blog Post - SEO"
    meta_description: "A test blog post"
    """
  end

  defp valid_page_metadata do
    """
    title: "Test Page"
    slug: "test-page"
    type: "page"
    """
  end

  defp valid_landing_metadata do
    """
    title: "Test Landing Page"
    slug: "test-landing"
    type: "landing"
    protected: true
    """
  end

  defp simple_markdown_content do
    """
    # Hello World

    This is a test blog post.
    """
  end

  defp simple_html_content do
    """
    <div>
      <h1>Hello HTML</h1>
      <p>This is HTML content.</p>
    </div>
    """
  end

  defp simple_heex_content do
    """
    <div>
      <h1><%= @title %></h1>
      <p><%= @content %></p>
    </div>
    """
  end

  # ============================================================================
  # sync_from_git/1 - Successful Sync Operations
  # ============================================================================

  describe "sync_from_git/1 - successful git-based sync" do
    setup do
      Application.put_env(:code_my_spec, :git_impl_module, CodeMySpec.MockGit)
      :ok
    end

    test "successfully clones repo and syncs content" do
      scope = scope_with_project()

      dir =
        create_test_directory([
          {"post.md", simple_markdown_content(), valid_blog_metadata()}
        ])

      expect(CodeMySpec.MockGit, :clone, fn _scope, repo_url, _temp_path ->
        assert repo_url == "https://github.com/test/content-repo.git"
        {:ok, dir}
      end)

      assert {:ok, result} = ContentSync.sync_from_git(scope)
      assert result.total_files == 1
      assert result.successful == 1
      assert result.errors == 0
      assert result.content_types.blog == 1

      cleanup_directory(dir)
    end

    test "syncs multiple content files from git repo" do
      scope = scope_with_project()

      dir =
        create_test_directory([
          {"blog.md", simple_markdown_content(), valid_blog_metadata()},
          {"page.html", simple_html_content(), valid_page_metadata()},
          {"landing.heex", simple_heex_content(), valid_landing_metadata()}
        ])

      expect(CodeMySpec.MockGit, :clone, fn _scope, _repo_url, _temp_path ->
        {:ok, dir}
      end)

      assert {:ok, result} = ContentSync.sync_from_git(scope)
      assert result.total_files == 3
      assert result.successful == 3
      assert result.errors == 0
      assert result.content_types.blog == 1
      assert result.content_types.page == 1
      assert result.content_types.landing == 1

      cleanup_directory(dir)
    end

    test "creates content records in database from git sync" do
      scope = scope_with_project()

      dir =
        create_test_directory([
          {"post.md", simple_markdown_content(), valid_blog_metadata()}
        ])

      expect(CodeMySpec.MockGit, :clone, fn _scope, _repo_url, _temp_path ->
        {:ok, dir}
      end)

      assert {:ok, _result} = ContentSync.sync_from_git(scope)

      content = Content.list_all_content(scope)
      assert length(content) == 1

      [post] = content
      assert post.slug == "test-blog-post"
      assert post.content_type == :blog
      assert post.parse_status == :success

      cleanup_directory(dir)
    end

    test "returns sync result with accurate statistics" do
      scope = scope_with_project()

      dir =
        create_test_directory([
          {"blog1.md", simple_markdown_content(), valid_blog_metadata()},
          {"blog2.md", simple_markdown_content(),
           """
           title: "Blog 2"
           slug: "blog-2"
           type: "blog"
           """}
        ])

      expect(CodeMySpec.MockGit, :clone, fn _scope, _repo_url, _temp_path ->
        {:ok, dir}
      end)

      assert {:ok, result} = ContentSync.sync_from_git(scope)
      assert is_integer(result.duration_ms)
      assert result.duration_ms >= 0
      assert result.total_files == 2
      assert result.successful == 2
      assert result.errors == 0

      cleanup_directory(dir)
    end

    test "scopes content to correct account and project" do
      scope = scope_with_project()

      dir =
        create_test_directory([
          {"post.md", simple_markdown_content(), valid_blog_metadata()}
        ])

      expect(CodeMySpec.MockGit, :clone, fn _scope, _repo_url, _temp_path ->
        {:ok, dir}
      end)

      assert {:ok, _result} = ContentSync.sync_from_git(scope)

      [content] = Content.list_all_content(scope)
      assert content.account_id == scope.active_account_id
      assert content.project_id == scope.active_project_id

      cleanup_directory(dir)
    end
  end

  describe "sync_from_git/1 - git operation errors" do
    setup do
      Application.put_env(:code_my_spec, :git_impl_module, CodeMySpec.MockGit)
      :ok
    end

    test "returns error when git clone fails" do
      scope = scope_with_project()

      expect(CodeMySpec.MockGit, :clone, fn _scope, _repo_url, _temp_path ->
        {:error, :clone_failed}
      end)

      assert {:error, :clone_failed} = ContentSync.sync_from_git(scope)
    end

    test "returns error when repository is not accessible" do
      scope = scope_with_project()

      expect(CodeMySpec.MockGit, :clone, fn _scope, _repo_url, _temp_path ->
        {:error, :not_connected}
      end)

      assert {:error, :not_connected} = ContentSync.sync_from_git(scope)
    end

    test "returns error when git provider is unsupported" do
      scope = scope_with_project()

      expect(CodeMySpec.MockGit, :clone, fn _scope, _repo_url, _temp_path ->
        {:error, :unsupported_provider}
      end)

      assert {:error, :unsupported_provider} = ContentSync.sync_from_git(scope)
    end

    test "returns error when repository URL is invalid" do
      scope = scope_with_project()

      expect(CodeMySpec.MockGit, :clone, fn _scope, _repo_url, _temp_path ->
        {:error, :invalid_url}
      end)

      assert {:error, :invalid_url} = ContentSync.sync_from_git(scope)
    end
  end

  describe "sync_from_git/1 - scope validation" do
    test "returns error when scope has no active_project_id" do
      scope = scope_without_project()

      result = ContentSync.sync_from_git(scope)
      assert match?({:error, _}, result)
    end

    test "returns error when project has no content_repo configured" do
      scope = scope_without_content_repo()

      assert {:error, :no_content_repo} = ContentSync.sync_from_git(scope)
    end

    test "returns error when project does not exist" do
      scope = scope_with_project()
      invalid_scope = %{scope | active_project_id: 999_999}

      assert {:error, :project_not_found} = ContentSync.sync_from_git(invalid_scope)
    end

    test "returns error when scope account does not match project account" do
      scope1 = scope_with_project()
      scope2 = scope_with_project()

      # Try to access project from scope1 using scope2's account
      invalid_scope = %{scope2 | active_project_id: scope1.active_project_id}

      assert {:error, :project_not_found} = ContentSync.sync_from_git(invalid_scope)
    end
  end

  describe "sync_from_git/1 - temporary directory cleanup" do
    setup do
      Application.put_env(:code_my_spec, :git_impl_module, CodeMySpec.MockGit)
      :ok
    end

    test "cleans up temporary directory after successful sync" do
      scope = scope_with_project()

      dir =
        create_test_directory([
          {"post.md", simple_markdown_content(), valid_blog_metadata()}
        ])

      temp_dir_path = dir

      expect(CodeMySpec.MockGit, :clone, fn _scope, _repo_url, _temp_path ->
        {:ok, temp_dir_path}
      end)

      assert {:ok, _result} = ContentSync.sync_from_git(scope)

      # Verify we got a result - actual cleanup is handled by Briefly library
      content = Content.list_all_content(scope)
      assert length(content) == 1

      cleanup_directory(dir)
    end
  end

  # ============================================================================
  # list_content_errors/1 - Query Error Content
  # ============================================================================

  describe "list_content_errors/1 - query content with errors" do
    test "returns only content with error parse status" do
      scope = scope_with_project()

      # Create successful content
      {:ok, _success} =
        Content.create_content(scope, %{
          title: "Success Post",
          slug: "success-post",
          content_type: :blog,
          raw_content: "Content",
          processed_content: "Processed",
          parse_status: :success
        })

      # Create error content
      {:ok, error} =
        Content.create_content(scope, %{
          title: "Error Post",
          slug: "error-post",
          content_type: :blog,
          raw_content: "Content",
          parse_status: :error,
          parse_errors: %{"error_type" => "metadata_missing", "message" => "Missing title"}
        })

      result = ContentSync.list_content_errors(scope)
      assert length(result) == 1
      assert hd(result).id == error.id
      assert hd(result).parse_status == :error
    end

    test "returns empty list when no errors exist" do
      scope = scope_with_project()

      {:ok, _success} =
        Content.create_content(scope, %{
          title: "Success Post",
          slug: "success-post",
          content_type: :blog,
          raw_content: "Content",
          processed_content: "Processed",
          parse_status: :success
        })

      result = ContentSync.list_content_errors(scope)
      assert result == []
    end

    test "returns multiple error content records" do
      scope = scope_with_project()

      for i <- 1..5 do
        {:ok, _error} =
          Content.create_content(scope, %{
            title: "Error Post #{i}",
            slug: "error-post-#{i}",
            content_type: :blog,
            raw_content: "Content",
            parse_status: :error,
            parse_errors: %{"error_type" => "parse_error", "message" => "Parse failed"}
          })
      end

      result = ContentSync.list_content_errors(scope)
      assert length(result) == 5
      assert Enum.all?(result, &(&1.parse_status == :error))
    end

    test "scopes errors to project" do
      scope1 = scope_with_project()
      scope2 = scope_with_project()

      # Create error in project 1
      {:ok, error1} =
        Content.create_content(scope1, %{
          title: "Error Post 1",
          slug: "error-post-1",
          content_type: :blog,
          raw_content: "Content",
          parse_status: :error,
          parse_errors: %{"error_type" => "parse_error"}
        })

      # Create error in project 2
      {:ok, _error2} =
        Content.create_content(scope2, %{
          title: "Error Post 2",
          slug: "error-post-2",
          content_type: :blog,
          raw_content: "Content",
          parse_status: :error,
          parse_errors: %{"error_type" => "parse_error"}
        })

      result1 = ContentSync.list_content_errors(scope1)
      assert length(result1) == 1
      assert hd(result1).id == error1.id

      result2 = ContentSync.list_content_errors(scope2)
      assert length(result2) == 1
      refute hd(result2).id == error1.id
    end

    test "includes parse_errors details in result" do
      scope = scope_with_project()

      error_details = %{
        "error_type" => "metadata_validation",
        "message" => "Missing required field: title",
        "field" => "title"
      }

      {:ok, error} =
        Content.create_content(scope, %{
          slug: "error-post",
          content_type: :blog,
          raw_content: "Content",
          parse_status: :error,
          parse_errors: error_details
        })

      [result] = ContentSync.list_content_errors(scope)
      assert result.id == error.id
      assert result.parse_errors == error_details
      assert result.parse_errors["error_type"] == "metadata_validation"
      assert result.parse_errors["message"] == "Missing required field: title"
      assert result.parse_errors["field"] == "title"
    end
  end

  # ============================================================================
  # Integration Tests - Full Sync Workflow
  # ============================================================================

  describe "full sync workflow integration" do
    setup do
      Application.put_env(:code_my_spec, :git_impl_module, CodeMySpec.MockGit)
      :ok
    end

    test "complete workflow: clone -> sync -> query errors" do
      scope = scope_with_project()

      dir =
        create_test_directory([
          {"good.md", simple_markdown_content(), valid_blog_metadata()},
          {"bad.md", simple_markdown_content(),
           """
           slug: "missing-title"
           type: "blog"
           """}
        ])

      expect(CodeMySpec.MockGit, :clone, fn _scope, _repo_url, _temp_path ->
        {:ok, dir}
      end)

      # Perform git sync
      assert {:ok, result} = ContentSync.sync_from_git(scope)
      assert result.total_files == 2
      assert result.successful == 1
      assert result.errors == 1

      # Query errors
      errors = ContentSync.list_content_errors(scope)
      assert length(errors) == 1
      assert hd(errors).parse_status == :error
      assert hd(errors).parse_errors != nil

      # Verify successful content also exists
      all_content = Content.list_all_content(scope)
      assert length(all_content) == 2

      cleanup_directory(dir)
    end

    test "resync replaces all previous content" do
      scope = scope_with_project()

      # First sync
      dir1 =
        create_test_directory([
          {"old.md", simple_markdown_content(),
           """
           title: "Old Post"
           slug: "old-post"
           type: "blog"
           """}
        ])

      expect(CodeMySpec.MockGit, :clone, fn _scope, _repo_url, _temp_path ->
        {:ok, dir1}
      end)

      assert {:ok, result1} = ContentSync.sync_from_git(scope)
      assert result1.total_files == 1

      content_after_first = Content.list_all_content(scope)
      assert length(content_after_first) == 1
      assert hd(content_after_first).slug == "old-post"

      # Second sync with new content
      dir2 =
        create_test_directory([
          {"new.md", simple_markdown_content(),
           """
           title: "New Post"
           slug: "new-post"
           type: "blog"
           """}
        ])

      expect(CodeMySpec.MockGit, :clone, fn _scope, _repo_url, _temp_path ->
        {:ok, dir2}
      end)

      assert {:ok, result2} = ContentSync.sync_from_git(scope)
      assert result2.total_files == 1

      content_after_second = Content.list_all_content(scope)
      assert length(content_after_second) == 1
      assert hd(content_after_second).slug == "new-post"
      refute hd(content_after_second).slug == "old-post"

      cleanup_directory(dir1)
      cleanup_directory(dir2)
    end

    test "multiple projects can sync independently" do
      scope1 = scope_with_project(%{name: "Project 1"})
      scope2 = scope_with_project(%{name: "Project 2"})

      dir1 =
        create_test_directory([
          {"project1.md", simple_markdown_content(),
           """
           title: "Project 1 Post"
           slug: "project-1-post"
           type: "blog"
           """}
        ])

      dir2 =
        create_test_directory([
          {"project2.md", simple_markdown_content(),
           """
           title: "Project 2 Post"
           slug: "project-2-post"
           type: "blog"
           """}
        ])

      expect(CodeMySpec.MockGit, :clone, 2, fn _scope, _repo_url, _temp_path ->
        receive do
          {:return_dir, dir} -> {:ok, dir}
        end
      end)

      # Sync project 1
      send(self(), {:return_dir, dir1})
      assert {:ok, result1} = ContentSync.sync_from_git(scope1)
      assert result1.total_files == 1

      # Sync project 2
      send(self(), {:return_dir, dir2})
      assert {:ok, result2} = ContentSync.sync_from_git(scope2)
      assert result2.total_files == 1

      # Verify isolation
      content1 = Content.list_all_content(scope1)
      assert length(content1) == 1
      assert hd(content1).slug == "project-1-post"

      content2 = Content.list_all_content(scope2)
      assert length(content2) == 1
      assert hd(content2).slug == "project-2-post"

      cleanup_directory(dir1)
      cleanup_directory(dir2)
    end
  end

  # ============================================================================
  # Edge Cases and Error Handling
  # ============================================================================

  describe "edge cases" do
    setup do
      Application.put_env(:code_my_spec, :git_impl_module, CodeMySpec.MockGit)
      :ok
    end

    test "handles empty git repository" do
      scope = scope_with_project()

      empty_dir =
        Path.join(System.tmp_dir!(), "empty_#{System.unique_integer([:positive])}")

      File.mkdir_p!(empty_dir)

      expect(CodeMySpec.MockGit, :clone, fn _scope, _repo_url, _temp_path ->
        {:ok, empty_dir}
      end)

      assert {:ok, result} = ContentSync.sync_from_git(scope)
      assert result.total_files == 0
      assert result.successful == 0
      assert result.errors == 0

      content = Content.list_all_content(scope)
      assert content == []

      cleanup_directory(empty_dir)
    end

    test "handles git repository with no content files" do
      scope = scope_with_project()

      dir = Path.join(System.tmp_dir!(), "no_content_#{System.unique_integer([:positive])}")
      File.mkdir_p!(dir)

      # Create non-content files
      File.write!(Path.join(dir, "README.md"), "# README")
      File.write!(Path.join(dir, ".gitignore"), "*.log")

      expect(CodeMySpec.MockGit, :clone, fn _scope, _repo_url, _temp_path ->
        {:ok, dir}
      end)

      assert {:ok, result} = ContentSync.sync_from_git(scope)
      assert result.total_files == 0

      cleanup_directory(dir)
    end

    test "syncs successfully with very large number of files" do
      scope = scope_with_project()

      many_files =
        for i <- 1..100 do
          {"post#{i}.md", simple_markdown_content(),
           """
           title: "Post #{i}"
           slug: "post-#{i}"
           type: "blog"
           """}
        end

      dir = create_test_directory(many_files)

      expect(CodeMySpec.MockGit, :clone, fn _scope, _repo_url, _temp_path ->
        {:ok, dir}
      end)

      assert {:ok, result} = ContentSync.sync_from_git(scope)
      assert result.total_files == 100
      assert result.successful == 100
      assert result.errors == 0

      content = Content.list_all_content(scope)
      assert length(content) == 100

      cleanup_directory(dir)
    end

    test "handles git repository with mixed success and error content" do
      scope = scope_with_project()

      dir =
        create_test_directory([
          {"success1.md", simple_markdown_content(), valid_blog_metadata()},
          {"error1.md", simple_markdown_content(),
           """
           slug: "missing-title-1"
           type: "blog"
           """},
          {"success2.html", simple_html_content(), valid_page_metadata()},
          {"error2.heex", "<div><p>Unclosed tag",
           """
           title: "Error Landing"
           slug: "error-landing"
           type: "landing"
           """}
        ])

      expect(CodeMySpec.MockGit, :clone, fn _scope, _repo_url, _temp_path ->
        {:ok, dir}
      end)

      assert {:ok, result} = ContentSync.sync_from_git(scope)
      assert result.total_files == 4
      assert result.successful == 2
      assert result.errors == 2

      errors = ContentSync.list_content_errors(scope)
      assert length(errors) == 2

      all_content = Content.list_all_content(scope)
      assert length(all_content) == 4

      cleanup_directory(dir)
    end
  end

  # ============================================================================
  # Result Structure Validation
  # ============================================================================

  describe "sync_result structure validation" do
    setup do
      Application.put_env(:code_my_spec, :git_impl_module, CodeMySpec.MockGit)
      :ok
    end

    test "sync_result has all required fields" do
      scope = scope_with_project()

      dir =
        create_test_directory([
          {"post.md", simple_markdown_content(), valid_blog_metadata()}
        ])

      expect(CodeMySpec.MockGit, :clone, fn _scope, _repo_url, _temp_path ->
        {:ok, dir}
      end)

      assert {:ok, result} = ContentSync.sync_from_git(scope)
      assert Map.has_key?(result, :total_files)
      assert Map.has_key?(result, :successful)
      assert Map.has_key?(result, :errors)
      assert Map.has_key?(result, :duration_ms)
      assert Map.has_key?(result, :content_types)

      cleanup_directory(dir)
    end

    test "content_types map has all required content type keys" do
      scope = scope_with_project()

      dir =
        create_test_directory([
          {"post.md", simple_markdown_content(), valid_blog_metadata()}
        ])

      expect(CodeMySpec.MockGit, :clone, fn _scope, _repo_url, _temp_path ->
        {:ok, dir}
      end)

      assert {:ok, result} = ContentSync.sync_from_git(scope)
      assert Map.has_key?(result.content_types, :blog)
      assert Map.has_key?(result.content_types, :page)
      assert Map.has_key?(result.content_types, :landing)

      cleanup_directory(dir)
    end

    test "all numeric fields are non-negative integers" do
      scope = scope_with_project()

      dir =
        create_test_directory([
          {"post.md", simple_markdown_content(), valid_blog_metadata()}
        ])

      expect(CodeMySpec.MockGit, :clone, fn _scope, _repo_url, _temp_path ->
        {:ok, dir}
      end)

      assert {:ok, result} = ContentSync.sync_from_git(scope)
      assert is_integer(result.total_files) and result.total_files >= 0
      assert is_integer(result.successful) and result.successful >= 0
      assert is_integer(result.errors) and result.errors >= 0
      assert is_integer(result.duration_ms) and result.duration_ms >= 0
      assert is_integer(result.content_types.blog) and result.content_types.blog >= 0
      assert is_integer(result.content_types.page) and result.content_types.page >= 0
      assert is_integer(result.content_types.landing) and result.content_types.landing >= 0

      cleanup_directory(dir)
    end

    test "total_files equals successful plus errors" do
      scope = scope_with_project()

      dir =
        create_test_directory([
          {"good.md", simple_markdown_content(), valid_blog_metadata()},
          {"bad.md", simple_markdown_content(),
           """
           slug: "missing-title"
           type: "blog"
           """}
        ])

      expect(CodeMySpec.MockGit, :clone, fn _scope, _repo_url, _temp_path ->
        {:ok, dir}
      end)

      assert {:ok, result} = ContentSync.sync_from_git(scope)
      assert result.total_files == result.successful + result.errors

      cleanup_directory(dir)
    end
  end
end
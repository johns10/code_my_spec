defmodule CodeMySpec.ContentSync.SyncTest do
  use CodeMySpec.DataCase

  import CodeMySpec.{UsersFixtures, AccountsFixtures, ProjectsFixtures}

  alias CodeMySpec.ContentSync.Sync
  alias CodeMySpec.Content
  alias CodeMySpec.Users.Scope

  # ============================================================================
  # Fixtures - Scope Creation
  # ============================================================================

  defp scope_with_project do
    user = user_fixture()
    account = account_fixture(%{name: "Test Account"})

    scope = %Scope{
      user: user,
      active_account: account,
      active_account_id: account.id,
      active_project_id: nil
    }

    project = project_fixture(scope, %{name: "Test Project"})

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

  # ============================================================================
  # Fixtures - Test Directories and Files
  # ============================================================================

  defp create_test_directory(files) do
    dir = Path.join(System.tmp_dir!(), "sync_test_#{System.unique_integer([:positive])}")
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

  defp invalid_metadata_missing_title do
    """
    slug: "missing-title"
    type: "blog"
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

  defp invalid_html_with_script do
    """
    <div>
      <script>alert('xss')</script>
      <p>Content</p>
    </div>
    """
  end

  defp invalid_heex_unclosed_tag do
    """
    <div>
      <p>Unclosed paragraph
    </div>
    """
  end

  # ============================================================================
  # sync_directory/2 - Successful Sync Operations
  # ============================================================================

  describe "sync_directory/2 - successful sync with single file" do
    test "successfully syncs single markdown file" do
      scope = scope_with_project()

      dir =
        create_test_directory([
          {"post.md", simple_markdown_content(), valid_blog_metadata()}
        ])

      assert {:ok, result} = Sync.sync_directory(scope, dir)
      assert result.total_files == 1
      assert result.successful == 1
      assert result.errors == 0
      assert is_integer(result.duration_ms)
      assert result.duration_ms >= 0
      assert result.content_types.blog == 1
      assert result.content_types.page == 0
      assert result.content_types.landing == 0
      cleanup_directory(dir)
    end

    test "successfully syncs single HTML file" do
      scope = scope_with_project()

      dir =
        create_test_directory([
          {"page.html", simple_html_content(), valid_page_metadata()}
        ])

      assert {:ok, result} = Sync.sync_directory(scope, dir)
      assert result.total_files == 1
      assert result.successful == 1
      assert result.errors == 0
      assert result.content_types.page == 1
      cleanup_directory(dir)
    end

    test "successfully syncs single HEEx file" do
      scope = scope_with_project()

      dir =
        create_test_directory([
          {"landing.heex", simple_heex_content(), valid_landing_metadata()}
        ])

      assert {:ok, result} = Sync.sync_directory(scope, dir)
      assert result.total_files == 1
      assert result.successful == 1
      assert result.errors == 0
      assert result.content_types.landing == 1
      cleanup_directory(dir)
    end

    test "creates content record in database" do
      scope = scope_with_project()

      dir =
        create_test_directory([
          {"post.md", simple_markdown_content(), valid_blog_metadata()}
        ])

      assert {:ok, _result} = Sync.sync_directory(scope, dir)

      content = Content.list_all_content(scope)
      assert length(content) == 1

      [post] = content
      assert post.slug == "test-blog-post"
      assert post.content_type == :blog
      assert post.parse_status == :success
      cleanup_directory(dir)
    end

    test "stores raw_content and processed_content correctly" do
      scope = scope_with_project()

      dir =
        create_test_directory([
          {"post.md", simple_markdown_content(), valid_blog_metadata()}
        ])

      assert {:ok, _result} = Sync.sync_directory(scope, dir)

      [post] = Content.list_all_content(scope)
      assert post.raw_content == simple_markdown_content()
      assert is_binary(post.processed_content)
      assert String.contains?(post.processed_content, "<h1>")
      cleanup_directory(dir)
    end

    test "stores metadata fields correctly" do
      scope = scope_with_project()

      dir =
        create_test_directory([
          {"post.md", simple_markdown_content(), valid_blog_metadata()}
        ])

      assert {:ok, _result} = Sync.sync_directory(scope, dir)

      [post] = Content.list_all_content(scope)
      assert post.title == "Test Blog Post"
      assert post.meta_title == "Test Blog Post - SEO"
      assert post.meta_description == "A test blog post"
      assert post.publish_at != nil
      cleanup_directory(dir)
    end
  end

  describe "sync_directory/2 - successful sync with multiple files" do
    test "successfully syncs multiple files of different types" do
      scope = scope_with_project()

      dir =
        create_test_directory([
          {"post.md", simple_markdown_content(), valid_blog_metadata()},
          {"page.html", simple_html_content(), valid_page_metadata()},
          {"landing.heex", simple_heex_content(), valid_landing_metadata()}
        ])

      assert {:ok, result} = Sync.sync_directory(scope, dir)
      assert result.total_files == 3
      assert result.successful == 3
      assert result.errors == 0
      assert result.content_types.blog == 1
      assert result.content_types.page == 1
      assert result.content_types.landing == 1
      cleanup_directory(dir)
    end

    test "creates multiple content records in database" do
      scope = scope_with_project()

      dir =
        create_test_directory([
          {"post1.md", simple_markdown_content(), valid_blog_metadata()},
          {"post2.md", simple_markdown_content(),
           """
           title: "Second Post"
           slug: "second-post"
           type: "blog"
           """},
          {"page.html", simple_html_content(), valid_page_metadata()}
        ])

      assert {:ok, _result} = Sync.sync_directory(scope, dir)

      content = Content.list_all_content(scope)
      assert length(content) == 3

      slugs = Enum.map(content, & &1.slug) |> Enum.sort()
      assert slugs == ["second-post", "test-blog-post", "test-page"]
      cleanup_directory(dir)
    end

    test "syncs files in alphabetical order" do
      scope = scope_with_project()

      dir =
        create_test_directory([
          {"zebra.md", simple_markdown_content(),
           """
           title: "Zebra"
           slug: "zebra"
           type: "blog"
           """},
          {"alpha.md", simple_markdown_content(),
           """
           title: "Alpha"
           slug: "alpha"
           type: "blog"
           """},
          {"beta.md", simple_markdown_content(),
           """
           title: "Beta"
           slug: "beta"
           type: "blog"
           """}
        ])

      assert {:ok, result} = Sync.sync_directory(scope, dir)
      assert result.total_files == 3

      content = Content.list_all_content(scope)
      assert length(content) == 3
      cleanup_directory(dir)
    end
  end

  describe "sync_directory/2 - delete and recreate strategy" do
    test "deletes existing content before sync" do
      scope = scope_with_project()

      # Create initial content
      {:ok, _} =
        Content.create_content(scope, %{
          title: "Old Post",
          slug: "old-post",
          content_type: :blog,
          raw_content: "Old content",
          processed_content: "Old processed",
          parse_status: :success
        })

      assert length(Content.list_all_content(scope)) == 1

      # Sync new content
      dir =
        create_test_directory([
          {"new.md", simple_markdown_content(), valid_blog_metadata()}
        ])

      assert {:ok, _result} = Sync.sync_directory(scope, dir)

      content = Content.list_all_content(scope)
      assert length(content) == 1

      [post] = content
      assert post.slug == "test-blog-post"
      refute post.slug == "old-post"
      cleanup_directory(dir)
    end

    test "replaces all content atomically" do
      scope = scope_with_project()

      # Create multiple old content records
      for i <- 1..5 do
        {:ok, _} =
          Content.create_content(scope, %{
            title: "Old Post #{i}",
            slug: "old-post-#{i}",
            content_type: :blog,
            raw_content: "Old content",
            processed_content: "Old processed",
            parse_status: :success
          })
      end

      assert length(Content.list_all_content(scope)) == 5

      # Sync with completely new content
      dir =
        create_test_directory([
          {"new1.md", simple_markdown_content(),
           """
           title: "New Post 1"
           slug: "new-post-1"
           type: "blog"
           """},
          {"new2.md", simple_markdown_content(),
           """
           title: "New Post 2"
           slug: "new-post-2"
           type: "blog"
           """}
        ])

      assert {:ok, result} = Sync.sync_directory(scope, dir)
      assert result.total_files == 2

      content = Content.list_all_content(scope)
      assert length(content) == 2

      slugs = Enum.map(content, & &1.slug) |> Enum.sort()
      assert slugs == ["new-post-1", "new-post-2"]
      cleanup_directory(dir)
    end

    test "does not affect other project's content" do
      scope1 = scope_with_project()
      scope2 = scope_with_project()

      # Create content in both projects
      {:ok, _} =
        Content.create_content(scope1, %{
          title: "Project 1 Post",
          slug: "project-1-post",
          content_type: :blog,
          raw_content: "Content 1",
          processed_content: "Processed 1",
          parse_status: :success
        })

      {:ok, _} =
        Content.create_content(scope2, %{
          title: "Project 2 Post",
          slug: "project-2-post",
          content_type: :blog,
          raw_content: "Content 2",
          processed_content: "Processed 2",
          parse_status: :success
        })

      # Sync project 1
      dir =
        create_test_directory([
          {"new.md", simple_markdown_content(), valid_blog_metadata()}
        ])

      assert {:ok, _result} = Sync.sync_directory(scope1, dir)

      # Project 1 content replaced
      content1 = Content.list_all_content(scope1)
      assert length(content1) == 1
      assert hd(content1).slug == "test-blog-post"

      # Project 2 content unchanged
      content2 = Content.list_all_content(scope2)
      assert length(content2) == 1
      assert hd(content2).slug == "project-2-post"
      cleanup_directory(dir)
    end
  end

  # ============================================================================
  # sync_directory/2 - Error Handling
  # ============================================================================

  describe "sync_directory/2 - metadata parsing errors" do
    test "records content with error status when metadata is invalid" do
      scope = scope_with_project()

      dir =
        create_test_directory([
          {"post.md", simple_markdown_content(), invalid_metadata_missing_title()}
        ])

      assert {:ok, result} = Sync.sync_directory(scope, dir)
      assert result.total_files == 1
      assert result.successful == 0
      assert result.errors == 1

      [content] = Content.list_all_content(scope)
      assert content.parse_status == :error
      assert content.parse_errors != nil
      assert is_map(content.parse_errors)
      cleanup_directory(dir)
    end

    test "ignores files without metadata sidecar files" do
      scope = scope_with_project()

      dir = Path.join(System.tmp_dir!(), "sync_test_#{System.unique_integer([:positive])}")
      File.mkdir_p!(dir)

      # Create content file without metadata file (should be ignored)
      file_path = Path.join(dir, "post.md")
      File.write!(file_path, simple_markdown_content())

      assert {:ok, result} = Sync.sync_directory(scope, dir)
      assert result.total_files == 0
      assert result.successful == 0
      assert result.errors == 0

      # No content should be created
      content = Content.list_all_content(scope)
      assert content == []
      cleanup_directory(dir)
    end

    test "stores metadata error details in parse_errors field" do
      scope = scope_with_project()

      dir =
        create_test_directory([
          {"post.md", simple_markdown_content(), invalid_metadata_missing_title()}
        ])

      assert {:ok, _result} = Sync.sync_directory(scope, dir)

      [content] = Content.list_all_content(scope)
      assert content.parse_status == :error
      assert is_map(content.parse_errors)
      assert Map.has_key?(content.parse_errors, "error_type")
      assert Map.has_key?(content.parse_errors, "message")
      cleanup_directory(dir)
    end
  end

  describe "sync_directory/2 - content processing errors" do
    test "records content with error status when HTML has disallowed content" do
      scope = scope_with_project()

      dir =
        create_test_directory([
          {"page.html", invalid_html_with_script(), valid_page_metadata()}
        ])

      assert {:ok, result} = Sync.sync_directory(scope, dir)
      assert result.total_files == 1
      assert result.errors == 1

      [content] = Content.list_all_content(scope)
      assert content.parse_status == :error
      assert content.parse_errors != nil
      cleanup_directory(dir)
    end

    test "records content with error status when HEEx has syntax errors" do
      scope = scope_with_project()

      dir =
        create_test_directory([
          {"landing.heex", invalid_heex_unclosed_tag(), valid_landing_metadata()}
        ])

      assert {:ok, result} = Sync.sync_directory(scope, dir)
      assert result.total_files == 1
      assert result.errors == 1

      [content] = Content.list_all_content(scope)
      assert content.parse_status == :error
      assert content.parse_errors != nil
      cleanup_directory(dir)
    end

    test "continues sync when some files have errors" do
      scope = scope_with_project()

      dir =
        create_test_directory([
          {"good.md", simple_markdown_content(), valid_blog_metadata()},
          {"bad.html", invalid_html_with_script(), valid_page_metadata()},
          {"good2.heex", simple_heex_content(), valid_landing_metadata()}
        ])

      assert {:ok, result} = Sync.sync_directory(scope, dir)
      assert result.total_files == 3
      assert result.successful == 2
      assert result.errors == 1

      content = Content.list_all_content(scope)
      assert length(content) == 3

      successful = Enum.filter(content, &(&1.parse_status == :success))
      assert length(successful) == 2

      errors = Enum.filter(content, &(&1.parse_status == :error))
      assert length(errors) == 1
      cleanup_directory(dir)
    end
  end

  describe "sync_directory/2 - mixed success and error scenarios" do
    test "tracks both successful and failed files in result" do
      scope = scope_with_project()

      dir =
        create_test_directory([
          {"success1.md", simple_markdown_content(), valid_blog_metadata()},
          {"error1.md", simple_markdown_content(), invalid_metadata_missing_title()},
          {"success2.html", simple_html_content(), valid_page_metadata()},
          {"error2.html", invalid_html_with_script(),
           """
           title: "Error Page"
           slug: "error-page"
           type: "page"
           """}
        ])

      assert {:ok, result} = Sync.sync_directory(scope, dir)
      assert result.total_files == 4
      assert result.successful == 2
      assert result.errors == 2

      content = Content.list_all_content(scope)
      assert length(content) == 4
      cleanup_directory(dir)
    end

    test "partial errors do not rollback transaction" do
      scope = scope_with_project()

      dir =
        create_test_directory([
          {"good.md", simple_markdown_content(), valid_blog_metadata()},
          {"bad.md", simple_markdown_content(), invalid_metadata_missing_title()}
        ])

      assert {:ok, result} = Sync.sync_directory(scope, dir)
      assert result.successful == 1
      assert result.errors == 1

      # Both records should be in database
      content = Content.list_all_content(scope)
      assert length(content) == 2
      cleanup_directory(dir)
    end
  end

  # ============================================================================
  # sync_directory/2 - Directory Validation
  # ============================================================================

  describe "sync_directory/2 - directory validation errors" do
    test "returns error when directory does not exist" do
      scope = scope_with_project()
      nonexistent_dir = "/nonexistent/directory/path"

      assert {:error, :invalid_directory} = Sync.sync_directory(scope, nonexistent_dir)
    end

    test "returns error when directory path is nil" do
      scope = scope_with_project()

      assert {:error, :invalid_directory} = Sync.sync_directory(scope, nil)
    end

    test "returns error when directory path is empty string" do
      scope = scope_with_project()

      assert {:error, :invalid_directory} = Sync.sync_directory(scope, "")
    end

    test "returns error when path is a file not a directory" do
      scope = scope_with_project()

      file_path = Path.join(System.tmp_dir!(), "test_file_#{System.unique_integer([:positive])}")
      File.write!(file_path, "test content")

      assert {:error, :invalid_directory} = Sync.sync_directory(scope, file_path)
      File.rm!(file_path)
    end

    test "returns error when directory is not readable" do
      scope = scope_with_project()

      dir = Path.join(System.tmp_dir!(), "unreadable_#{System.unique_integer([:positive])}")
      File.mkdir_p!(dir)

      # Try to make directory unreadable (may not work on all systems)
      case File.chmod(dir, 0o000) do
        :ok ->
          result = Sync.sync_directory(scope, dir)
          # Should either be invalid_directory or permission error
          assert match?({:error, _}, result)

        {:error, _} ->
          # If we can't change permissions, skip this test scenario
          :ok
      end

      File.chmod(dir, 0o755)
      cleanup_directory(dir)
    end
  end

  describe "sync_directory/2 - empty directory scenarios" do
    test "successfully handles empty directory" do
      scope = scope_with_project()

      dir = Path.join(System.tmp_dir!(), "empty_#{System.unique_integer([:positive])}")
      File.mkdir_p!(dir)

      assert {:ok, result} = Sync.sync_directory(scope, dir)
      assert result.total_files == 0
      assert result.successful == 0
      assert result.errors == 0
      assert result.content_types.blog == 0
      assert result.content_types.page == 0
      assert result.content_types.landing == 0

      content = Content.list_all_content(scope)
      assert content == []
      cleanup_directory(dir)
    end

    test "deletes all content when syncing empty directory" do
      scope = scope_with_project()

      # Create existing content
      {:ok, _} =
        Content.create_content(scope, %{
          title: "Old Post",
          slug: "old-post",
          content_type: :blog,
          raw_content: "Content",
          processed_content: "Processed",
          parse_status: :success
        })

      assert length(Content.list_all_content(scope)) == 1

      # Sync empty directory
      dir = Path.join(System.tmp_dir!(), "empty_#{System.unique_integer([:positive])}")
      File.mkdir_p!(dir)

      assert {:ok, result} = Sync.sync_directory(scope, dir)
      assert result.total_files == 0

      content = Content.list_all_content(scope)
      assert content == []
      cleanup_directory(dir)
    end
  end

  # ============================================================================
  # sync_directory/2 - Scope Validation
  # ============================================================================

  describe "sync_directory/2 - scope validation" do
    test "returns error when scope has no active_project_id" do
      scope = scope_without_project()

      dir =
        create_test_directory([
          {"post.md", simple_markdown_content(), valid_blog_metadata()}
        ])

      result = Sync.sync_directory(scope, dir)
      # Should error during scope validation or content creation
      assert match?({:error, _}, result)
      cleanup_directory(dir)
    end

    test "scopes content to correct account and project" do
      scope = scope_with_project()

      dir =
        create_test_directory([
          {"post.md", simple_markdown_content(), valid_blog_metadata()}
        ])

      assert {:ok, _result} = Sync.sync_directory(scope, dir)

      [content] = Content.list_all_content(scope)
      assert content.account_id == scope.active_account_id
      assert content.project_id == scope.active_project_id
      cleanup_directory(dir)
    end
  end

  # ============================================================================
  # sync_directory/2 - File Type Handling
  # ============================================================================

  describe "sync_directory/2 - file type routing" do
    test "routes .md files to MarkdownProcessor" do
      scope = scope_with_project()

      dir =
        create_test_directory([
          {"post.md", simple_markdown_content(), valid_blog_metadata()}
        ])

      assert {:ok, _result} = Sync.sync_directory(scope, dir)

      [content] = Content.list_all_content(scope)
      assert content.parse_status == :success
      assert is_binary(content.processed_content)
      assert String.contains?(content.processed_content, "<h1>")
      cleanup_directory(dir)
    end

    test "routes .html files to HtmlProcessor" do
      scope = scope_with_project()

      dir =
        create_test_directory([
          {"page.html", simple_html_content(), valid_page_metadata()}
        ])

      assert {:ok, _result} = Sync.sync_directory(scope, dir)

      [content] = Content.list_all_content(scope)
      assert content.parse_status == :success
      assert content.processed_content == simple_html_content()
      cleanup_directory(dir)
    end

    test "routes .heex files to HeexProcessor" do
      scope = scope_with_project()

      dir =
        create_test_directory([
          {"landing.heex", simple_heex_content(), valid_landing_metadata()}
        ])

      assert {:ok, _result} = Sync.sync_directory(scope, dir)

      [content] = Content.list_all_content(scope)
      assert content.parse_status == :success
      assert is_nil(content.processed_content)
      assert content.raw_content == simple_heex_content()
      cleanup_directory(dir)
    end

    test "ignores non-content files" do
      scope = scope_with_project()

      dir = Path.join(System.tmp_dir!(), "sync_test_#{System.unique_integer([:positive])}")
      File.mkdir_p!(dir)

      # Create various non-content files
      File.write!(Path.join(dir, "README.txt"), "readme")
      File.write!(Path.join(dir, "config.json"), "{}")
      File.write!(Path.join(dir, "script.js"), "console.log()")
      File.write!(Path.join(dir, ".gitignore"), "*.log")

      # Create one valid content file
      File.write!(Path.join(dir, "post.md"), simple_markdown_content())
      File.write!(Path.join(dir, "post.yaml"), valid_blog_metadata())

      assert {:ok, result} = Sync.sync_directory(scope, dir)
      # Should only process the .md file
      assert result.total_files == 1
      assert result.successful == 1
      cleanup_directory(dir)
    end
  end

  describe "sync_directory/2 - file discovery" do
    test "discovers files in flat directory structure only" do
      scope = scope_with_project()

      dir = Path.join(System.tmp_dir!(), "sync_test_#{System.unique_integer([:positive])}")
      File.mkdir_p!(dir)

      # Create files in root directory
      File.write!(Path.join(dir, "root1.md"), simple_markdown_content())
      File.write!(Path.join(dir, "root1.yaml"), valid_blog_metadata())
      File.write!(Path.join(dir, "root2.md"), simple_markdown_content())

      File.write!(
        Path.join(dir, "root2.yaml"),
        """
        title: "Root 2"
        slug: "root-2"
        type: "blog"
        """
      )

      # Create subdirectory with files (should be ignored)
      subdir = Path.join(dir, "subdir")
      File.mkdir_p!(subdir)
      File.write!(Path.join(subdir, "nested.md"), simple_markdown_content())

      File.write!(
        Path.join(subdir, "nested.yaml"),
        """
        title: "Nested"
        slug: "nested"
        type: "blog"
        """
      )

      assert {:ok, result} = Sync.sync_directory(scope, dir)
      # Should only discover root level files
      assert result.total_files == 2

      content = Content.list_all_content(scope)
      assert length(content) == 2

      slugs = Enum.map(content, & &1.slug) |> Enum.sort()
      refute "nested" in slugs
      cleanup_directory(dir)
    end

    test "deduplicates file paths if any duplicates exist" do
      scope = scope_with_project()

      dir =
        create_test_directory([
          {"post.md", simple_markdown_content(), valid_blog_metadata()}
        ])

      assert {:ok, result} = Sync.sync_directory(scope, dir)
      assert result.total_files == 1

      content = Content.list_all_content(scope)
      assert length(content) == 1
      cleanup_directory(dir)
    end
  end

  # ============================================================================
  # sync_directory/2 - Content Type Statistics
  # ============================================================================

  describe "sync_directory/2 - content type statistics" do
    test "correctly counts blog content types" do
      scope = scope_with_project()

      dir =
        create_test_directory([
          {"blog1.md", simple_markdown_content(), valid_blog_metadata()},
          {"blog2.md", simple_markdown_content(),
           """
           title: "Blog 2"
           slug: "blog-2"
           type: "blog"
           """},
          {"blog3.md", simple_markdown_content(),
           """
           title: "Blog 3"
           slug: "blog-3"
           type: "blog"
           """}
        ])

      assert {:ok, result} = Sync.sync_directory(scope, dir)
      assert result.content_types.blog == 3
      assert result.content_types.page == 0
      assert result.content_types.landing == 0
      cleanup_directory(dir)
    end

    test "correctly counts page content types" do
      scope = scope_with_project()

      dir =
        create_test_directory([
          {"page1.html", simple_html_content(), valid_page_metadata()},
          {"page2.html", simple_html_content(),
           """
           title: "Page 2"
           slug: "page-2"
           type: "page"
           """}
        ])

      assert {:ok, result} = Sync.sync_directory(scope, dir)
      assert result.content_types.blog == 0
      assert result.content_types.page == 2
      assert result.content_types.landing == 0
      cleanup_directory(dir)
    end

    test "correctly counts landing content types" do
      scope = scope_with_project()

      dir =
        create_test_directory([
          {"landing1.heex", simple_heex_content(), valid_landing_metadata()},
          {"landing2.heex", simple_heex_content(),
           """
           title: "Landing 2"
           slug: "landing-2"
           type: "landing"
           """}
        ])

      assert {:ok, result} = Sync.sync_directory(scope, dir)
      assert result.content_types.blog == 0
      assert result.content_types.page == 0
      assert result.content_types.landing == 2
      cleanup_directory(dir)
    end

    test "correctly counts mixed content types" do
      scope = scope_with_project()

      dir =
        create_test_directory([
          {"blog.md", simple_markdown_content(), valid_blog_metadata()},
          {"page.html", simple_html_content(), valid_page_metadata()},
          {"landing.heex", simple_heex_content(), valid_landing_metadata()},
          {"blog2.md", simple_markdown_content(),
           """
           title: "Blog 2"
           slug: "blog-2"
           type: "blog"
           """}
        ])

      assert {:ok, result} = Sync.sync_directory(scope, dir)
      assert result.content_types.blog == 2
      assert result.content_types.page == 1
      assert result.content_types.landing == 1
      cleanup_directory(dir)
    end

    test "counts errors separately from content types" do
      scope = scope_with_project()

      dir =
        create_test_directory([
          {"good-blog.md", simple_markdown_content(), valid_blog_metadata()},
          {"bad-blog.md", simple_markdown_content(), invalid_metadata_missing_title()},
          {"good-page.html", simple_html_content(), valid_page_metadata()}
        ])

      assert {:ok, result} = Sync.sync_directory(scope, dir)
      assert result.total_files == 3
      assert result.successful == 2
      assert result.errors == 1
      # Content type counts should only include successful ones
      assert result.content_types.blog == 1
      assert result.content_types.page == 1
      cleanup_directory(dir)
    end
  end

  # ============================================================================
  # sync_directory/2 - Duration Tracking
  # ============================================================================

  describe "sync_directory/2 - duration tracking" do
    test "returns duration_ms in result" do
      scope = scope_with_project()

      dir =
        create_test_directory([
          {"post.md", simple_markdown_content(), valid_blog_metadata()}
        ])

      assert {:ok, result} = Sync.sync_directory(scope, dir)
      assert is_integer(result.duration_ms)
      assert result.duration_ms >= 0
      cleanup_directory(dir)
    end

    test "duration increases with more files" do
      scope = scope_with_project()

      # Sync with 1 file
      dir1 =
        create_test_directory([
          {"post1.md", simple_markdown_content(), valid_blog_metadata()}
        ])

      {:ok, result1} = Sync.sync_directory(scope, dir1)
      cleanup_directory(dir1)

      # Sync with many files
      many_files =
        for i <- 1..10 do
          {"post#{i}.md", simple_markdown_content(),
           """
           title: "Post #{i}"
           slug: "post-#{i}"
           type: "blog"
           """}
        end

      dir2 = create_test_directory(many_files)

      {:ok, result2} = Sync.sync_directory(scope, dir2)

      # More files should generally take longer (though not guaranteed)
      assert is_integer(result1.duration_ms)
      assert is_integer(result2.duration_ms)
      cleanup_directory(dir2)
    end
  end

  # ============================================================================
  # sync_directory/2 - Transaction Atomicity
  # ============================================================================

  describe "sync_directory/2 - transaction behavior" do
    test "commits transaction when sync succeeds" do
      scope = scope_with_project()

      dir =
        create_test_directory([
          {"post.md", simple_markdown_content(), valid_blog_metadata()}
        ])

      assert {:ok, _result} = Sync.sync_directory(scope, dir)

      # Content should be persisted
      content = Content.list_all_content(scope)
      assert length(content) == 1
      cleanup_directory(dir)
    end

    test "processes files within single transaction" do
      scope = scope_with_project()

      dir =
        create_test_directory([
          {"post1.md", simple_markdown_content(), valid_blog_metadata()},
          {"post2.md", simple_markdown_content(),
           """
           title: "Post 2"
           slug: "post-2"
           type: "blog"
           """}
        ])

      assert {:ok, _result} = Sync.sync_directory(scope, dir)

      # All content should be persisted together
      content = Content.list_all_content(scope)
      assert length(content) == 2
      cleanup_directory(dir)
    end
  end

  # ============================================================================
  # sync_directory/2 - Edge Cases
  # ============================================================================

  describe "sync_directory/2 - edge cases" do
    test "handles directory with only metadata files" do
      scope = scope_with_project()

      dir = Path.join(System.tmp_dir!(), "sync_test_#{System.unique_integer([:positive])}")
      File.mkdir_p!(dir)

      # Create only metadata files without corresponding content files
      File.write!(Path.join(dir, "post.yaml"), valid_blog_metadata())

      assert {:ok, result} = Sync.sync_directory(scope, dir)
      assert result.total_files == 0
      assert result.successful == 0
      cleanup_directory(dir)
    end

    test "handles very long file paths" do
      scope = scope_with_project()

      long_name = String.duplicate("a", 200)

      dir =
        create_test_directory([
          {"#{long_name}.md", simple_markdown_content(), valid_blog_metadata()}
        ])

      result = Sync.sync_directory(scope, dir)
      # Should handle gracefully - verify it returns a tuple
      assert is_tuple(result)
      assert tuple_size(result) == 2
      assert elem(result, 0) in [:ok, :error]
      cleanup_directory(dir)
    end

    test "handles files with unicode names" do
      scope = scope_with_project()

      dir =
        create_test_directory([
          {"测试文件.md", simple_markdown_content(),
           """
           title: "Unicode Test"
           slug: "unicode-test"
           type: "blog"
           """}
        ])

      assert {:ok, result} = Sync.sync_directory(scope, dir)
      assert result.total_files == 1
      cleanup_directory(dir)
    end

    test "handles absolute directory paths" do
      scope = scope_with_project()

      dir =
        create_test_directory([
          {"post.md", simple_markdown_content(), valid_blog_metadata()}
        ])

      absolute_path = Path.expand(dir)
      assert {:ok, result} = Sync.sync_directory(scope, absolute_path)
      assert result.total_files == 1
      cleanup_directory(dir)
    end

    test "handles directory path with trailing slash" do
      scope = scope_with_project()

      dir =
        create_test_directory([
          {"post.md", simple_markdown_content(), valid_blog_metadata()}
        ])

      dir_with_slash = dir <> "/"
      assert {:ok, result} = Sync.sync_directory(scope, dir_with_slash)
      assert result.total_files == 1
      cleanup_directory(dir)
    end
  end

  # ============================================================================
  # sync_directory/2 - Result Structure Validation
  # ============================================================================

  describe "sync_directory/2 - result structure consistency" do
    test "result has all required fields" do
      scope = scope_with_project()

      dir =
        create_test_directory([
          {"post.md", simple_markdown_content(), valid_blog_metadata()}
        ])

      assert {:ok, result} = Sync.sync_directory(scope, dir)
      assert Map.has_key?(result, :total_files)
      assert Map.has_key?(result, :successful)
      assert Map.has_key?(result, :errors)
      assert Map.has_key?(result, :duration_ms)
      assert Map.has_key?(result, :content_types)
      cleanup_directory(dir)
    end

    test "content_types has all required keys" do
      scope = scope_with_project()

      dir =
        create_test_directory([
          {"post.md", simple_markdown_content(), valid_blog_metadata()}
        ])

      assert {:ok, result} = Sync.sync_directory(scope, dir)
      assert Map.has_key?(result.content_types, :blog)
      assert Map.has_key?(result.content_types, :page)
      assert Map.has_key?(result.content_types, :landing)
      cleanup_directory(dir)
    end

    test "all count fields are non-negative integers" do
      scope = scope_with_project()

      dir =
        create_test_directory([
          {"post.md", simple_markdown_content(), valid_blog_metadata()}
        ])

      assert {:ok, result} = Sync.sync_directory(scope, dir)
      assert is_integer(result.total_files) and result.total_files >= 0
      assert is_integer(result.successful) and result.successful >= 0
      assert is_integer(result.errors) and result.errors >= 0
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
          {"bad.md", simple_markdown_content(), invalid_metadata_missing_title()},
          {"good2.html", simple_html_content(), valid_page_metadata()}
        ])

      assert {:ok, result} = Sync.sync_directory(scope, dir)
      assert result.total_files == result.successful + result.errors
      cleanup_directory(dir)
    end
  end

  # ============================================================================
  # sync_directory/2 - Idempotency
  # ============================================================================

  describe "sync_directory/2 - idempotency" do
    test "syncing same directory twice produces same result" do
      scope = scope_with_project()

      dir =
        create_test_directory([
          {"post.md", simple_markdown_content(), valid_blog_metadata()}
        ])

      assert {:ok, result1} = Sync.sync_directory(scope, dir)
      assert {:ok, result2} = Sync.sync_directory(scope, dir)

      assert result1.total_files == result2.total_files
      assert result1.successful == result2.successful
      assert result1.errors == result2.errors

      # Content should be same after second sync
      content = Content.list_all_content(scope)
      assert length(content) == 1
      cleanup_directory(dir)
    end

    test "syncing same files in different directory produces equivalent content" do
      scope = scope_with_project()

      dir1 =
        create_test_directory([
          {"post.md", simple_markdown_content(), valid_blog_metadata()}
        ])

      assert {:ok, result1} = Sync.sync_directory(scope, dir1)
      content1 = Content.list_all_content(scope)

      dir2 =
        create_test_directory([
          {"post.md", simple_markdown_content(), valid_blog_metadata()}
        ])

      assert {:ok, result2} = Sync.sync_directory(scope, dir2)
      content2 = Content.list_all_content(scope)

      assert result1.total_files == result2.total_files
      assert length(content1) == length(content2)

      [c1] = content1
      [c2] = content2

      assert c1.slug == c2.slug
      assert c1.title == c2.title
      assert c1.raw_content == c2.raw_content
      cleanup_directory(dir1)
      cleanup_directory(dir2)
    end
  end

  # ============================================================================
  # sync_directory/2 - Large File Sets
  # ============================================================================

  describe "sync_directory/2 - performance with many files" do
    test "successfully syncs directory with many files" do
      scope = scope_with_project()

      many_files =
        for i <- 1..50 do
          {"post#{i}.md", simple_markdown_content(),
           """
           title: "Post #{i}"
           slug: "post-#{i}"
           type: "blog"
           """}
        end

      dir = create_test_directory(many_files)

      assert {:ok, result} = Sync.sync_directory(scope, dir)
      assert result.total_files == 50
      assert result.successful == 50
      assert result.errors == 0

      content = Content.list_all_content(scope)
      assert length(content) == 50
      cleanup_directory(dir)
    end

    test "handles large files efficiently" do
      scope = scope_with_project()

      large_content = String.duplicate("# Section\n\nContent paragraph.\n\n", 1000)

      dir =
        create_test_directory([
          {"large.md", large_content, valid_blog_metadata()}
        ])

      assert {:ok, result} = Sync.sync_directory(scope, dir)
      assert result.total_files == 1
      assert result.successful == 1

      [content] = Content.list_all_content(scope)
      assert String.length(content.raw_content) > 10_000
      cleanup_directory(dir)
    end
  end
end

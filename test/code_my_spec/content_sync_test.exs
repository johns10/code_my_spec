defmodule CodeMySpec.ContentSyncTest do
  use CodeMySpec.DataCase

  import CodeMySpec.{UsersFixtures, AccountsFixtures, ProjectsFixtures}
  import Mox

  alias CodeMySpec.ContentSync
  alias CodeMySpec.Content
  alias CodeMySpec.Users.Scope

  setup tags do
    # Only verify mocks for non-integration tests
    unless tags[:integration] do
      verify_on_exit!()
    end

    :ok
  end

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
  # sync_from_git/1 - Successful Sync Operations
  # ============================================================================

  describe "sync_from_git/1 - successful git-based sync" do
    @tag :integration
    test "successfully clones repo and syncs content" do
      scope = scope_with_project(%{content_repo: "https://github.com/johns10/test_content_repo.git"})

      assert {:ok, result} = ContentSync.sync_from_git(scope)
      # test_content_repo has 5 valid files and 1 bad file (missing metadata)
      assert result.total_files >= 5
      assert result.successful >= 5
      assert result.errors >= 0
      assert is_integer(result.duration_ms)
      assert result.duration_ms >= 0

      # Verify content was created in database
      content = Content.list_all_content(scope)
      assert length(content) >= 5

      # Verify scoping
      Enum.each(content, fn item ->
        assert item.account_id == scope.active_account_id
        assert item.project_id == scope.active_project_id
      end)
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
    @tag :integration
    test "cleans up temporary directory after successful sync" do
      scope = scope_with_project(%{content_repo: "https://github.com/johns10/test_content_repo.git"})

      assert {:ok, result} = ContentSync.sync_from_git(scope)

      # Verify sync completed successfully
      assert result.total_files > 0
      assert result.successful > 0

      # Verify content was synced to database
      content = Content.list_all_content(scope)
      assert length(content) > 0
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

end
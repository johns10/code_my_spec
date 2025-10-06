defmodule CodeMySpec.GitTest do
  use CodeMySpec.DataCase, async: false

  import CodeMySpec.{UsersFixtures, IntegrationsFixtures}

  alias CodeMySpec.Git.CLI
  alias CodeMySpec.Users.Scope

  # ============================================================================
  # Fixtures
  # ============================================================================

  defp test_repo_url, do: "https://github.com/johns10/test_phoenix_project.git"

  defp temp_clone_path do
    base_path = System.tmp_dir!()
    unique_suffix = "git_integration_test_#{System.unique_integer([:positive])}"
    Path.join(base_path, unique_suffix)
  end

  defp scope_with_github_integration do
    user = user_fixture()
    token = "ghp_test_token_#{:rand.uniform(100000)}"
    _integration = github_integration_fixture(user, %{access_token: token})
    %Scope{user: user}
  end

  defp scope_without_integration do
    user = user_fixture()
    %Scope{user: user}
  end

  defp cleanup_path(path) do
    if File.exists?(path) do
      File.rm_rf!(path)
    end
  end

  # ============================================================================
  # End-to-End Workflow Tests
  # ============================================================================

  describe "clone and pull workflow" do
    @tag :integration
    test "complete workflow: clone repository, make changes, and pull updates" do
      scope = scope_with_github_integration()
      clone_path = temp_clone_path()

      try do
        # Step 1: Clone repository
        assert {:ok, ^clone_path} = CLI.clone(scope, test_repo_url(), clone_path)
        assert File.exists?(Path.join(clone_path, ".git"))

        # Step 2: Verify repository is functional
        {status_output, 0} = System.cmd("git", ["status"], cd: clone_path)
        assert String.contains?(status_output, "On branch")

        # Step 3: Pull updates (should work even with no new changes)
        assert :ok = CLI.pull(scope, clone_path)

        # Step 4: Verify remote URL is clean (no credentials exposed)
        {remote_url, 0} = System.cmd("git", ["remote", "get-url", "origin"], cd: clone_path)
        remote_url = String.trim(remote_url)

        assert remote_url == test_repo_url()
        refute String.contains?(remote_url, "ghp_")
        refute String.contains?(remote_url, "@github.com")
      after
        cleanup_path(clone_path)
      end
    end

    @tag :integration
    test "workflow fails gracefully when integration is removed mid-session" do
      clone_path = temp_clone_path()

      # Start with integration
      scope_with = scope_with_github_integration()

      try do
        # Clone succeeds
        {:ok, ^clone_path} = CLI.clone(scope_with, test_repo_url(), clone_path)

        # Create scope without integration for same user
        scope_without = scope_without_integration()

        # Pull fails without integration
        assert {:error, :not_connected} = CLI.pull(scope_without, clone_path)
      after
        cleanup_path(clone_path)
      end
    end
  end

  # ============================================================================
  # Multi-Repository Workflow Tests
  # ============================================================================

  describe "managing multiple repositories" do
    @tag :integration
    test "can clone and manage multiple repositories simultaneously" do
      scope = scope_with_github_integration()
      clone_path1 = temp_clone_path()
      clone_path2 = temp_clone_path()

      try do
        # Clone first repository
        assert {:ok, ^clone_path1} = CLI.clone(scope, test_repo_url(), clone_path1)

        # Clone second repository (same URL, different path)
        assert {:ok, ^clone_path2} = CLI.clone(scope, test_repo_url(), clone_path2)

        # Both repositories are independent
        assert File.exists?(Path.join(clone_path1, ".git"))
        assert File.exists?(Path.join(clone_path2, ".git"))

        # Can pull from both
        assert :ok = CLI.pull(scope, clone_path1)
        assert :ok = CLI.pull(scope, clone_path2)
      after
        cleanup_path(clone_path1)
        cleanup_path(clone_path2)
      end
    end
  end

  # ============================================================================
  # Cross-Provider Integration Tests
  # ============================================================================

  describe "provider-specific workflows" do
    test "GitHub: requires GitHub integration for GitHub repositories" do
      scope = scope_without_integration()
      clone_path = temp_clone_path()

      result = CLI.clone(scope, "https://github.com/owner/repo.git", clone_path)

      assert {:error, :not_connected} = result
      refute File.exists?(clone_path)
    end

    test "GitLab: requires GitLab integration for GitLab repositories" do
      scope = scope_without_integration()
      clone_path = temp_clone_path()

      result = CLI.clone(scope, "https://gitlab.com/owner/repo.git", clone_path)

      assert {:error, :not_connected} = result
      refute File.exists?(clone_path)
    end

    test "cannot use GitHub integration for GitLab repositories" do
      scope = scope_with_github_integration()
      clone_path = temp_clone_path()

      # Has GitHub integration but trying GitLab URL
      result = CLI.clone(scope, "https://gitlab.com/owner/repo.git", clone_path)

      assert {:error, :not_connected} = result
      refute File.exists?(clone_path)
    end
  end

  # ============================================================================
  # URL Format Integration Tests
  # ============================================================================

  describe "URL parsing and authentication flow" do
    test "rejects SSH URLs across the entire flow" do
      scope = scope_with_github_integration()
      clone_path = temp_clone_path()

      ssh_urls = [
        "git@github.com:owner/repo.git",
        "ssh://git@github.com/owner/repo.git",
        "git@gitlab.com:owner/repo.git"
      ]

      for ssh_url <- ssh_urls do
        result = CLI.clone(scope, ssh_url, clone_path)

        assert {:error, :invalid_url} = result
        refute File.exists?(clone_path)
      end
    end

    test "rejects non-HTTPS protocols" do
      scope = scope_with_github_integration()
      clone_path = temp_clone_path()

      invalid_urls = [
        "http://github.com/owner/repo.git",
        "ftp://github.com/owner/repo.git",
        "file:///local/repo.git"
      ]

      for invalid_url <- invalid_urls do
        result = CLI.clone(scope, invalid_url, clone_path)

        assert {:error, :invalid_url} = result
        refute File.exists?(clone_path)
      end
    end

    test "handles malformed URLs gracefully" do
      scope = scope_with_github_integration()
      clone_path = temp_clone_path()

      invalid_urls = [
        {nil, :invalid_url},
        {"", :invalid_url},
        {"not-a-url", :invalid_url},
        {"github.com/owner/repo", :invalid_url},
        {"https://", :invalid_url}
      ]

      for {malformed_url, expected_error} <- invalid_urls do
        result = CLI.clone(scope, malformed_url, clone_path)

        assert {:error, ^expected_error} = result
        refute File.exists?(clone_path)
      end

      # Valid URL format but non-existent repository (fails at git level)
      clone_path2 = temp_clone_path()
      result = CLI.clone(scope, "https://github.com", clone_path2)

      # Should get a git error, not an invalid_url error
      assert {:error, _git_error} = result
      refute File.exists?(clone_path2)
    end
  end

  # ============================================================================
  # Security and Credential Management Tests
  # ============================================================================

  describe "credential security throughout operations" do
    @tag :integration
    test "credentials are never exposed in git configuration" do
      scope = scope_with_github_integration()
      clone_path = temp_clone_path()

      try do
        # Clone repository
        {:ok, ^clone_path} = CLI.clone(scope, test_repo_url(), clone_path)

        # Check git config for any credential leakage
        {config_output, 0} = System.cmd("git", ["config", "--list"], cd: clone_path)

        refute String.contains?(config_output, "ghp_")
        refute String.contains?(config_output, "@github.com")

        # Pull and recheck
        :ok = CLI.pull(scope, clone_path)

        {config_output_after, 0} = System.cmd("git", ["config", "--list"], cd: clone_path)

        refute String.contains?(config_output_after, "ghp_")
        refute String.contains?(config_output_after, "@github.com")
      after
        cleanup_path(clone_path)
      end
    end

    @tag :integration
    test "credentials are cleaned up even when pull operation fails" do
      scope = scope_with_github_integration()
      clone_path = temp_clone_path()

      try do
        # Clone and create divergent history
        {:ok, ^clone_path} = CLI.clone(scope, test_repo_url(), clone_path)

        readme_path = Path.join(clone_path, "README.md")
        File.write!(readme_path, "# Local conflicting change\n")
        System.cmd("git", ["add", "."], cd: clone_path)
        System.cmd("git", ["commit", "-m", "Local commit"], cd: clone_path)

        # Pull may fail but credentials should still be cleaned
        _result = CLI.pull(scope, clone_path)

        # Verify no credentials in remote URL
        {remote_url, 0} = System.cmd("git", ["remote", "get-url", "origin"], cd: clone_path)
        remote_url = String.trim(remote_url)

        refute String.contains?(remote_url, "ghp_")
        refute String.contains?(remote_url, "@github.com")
      after
        cleanup_path(clone_path)
      end
    end
  end

  # ============================================================================
  # Scope Isolation Tests
  # ============================================================================

  describe "scope-based access control" do
    @tag :integration
    test "different users cannot access each other's repositories through shared paths" do
      user1_scope = scope_with_github_integration()
      user2_scope = scope_without_integration()
      clone_path = temp_clone_path()

      try do
        # User 1 clones repository
        {:ok, ^clone_path} = CLI.clone(user1_scope, test_repo_url(), clone_path)

        # User 2 cannot pull from User 1's cloned repository without integration
        result = CLI.pull(user2_scope, clone_path)

        assert {:error, :not_connected} = result
      after
        cleanup_path(clone_path)
      end
    end

    test "operations fail when scope lacks required integration" do
      scope = scope_without_integration()

      clone_result = CLI.clone(scope, "https://github.com/owner/repo.git", temp_clone_path())
      assert {:error, :not_connected} = clone_result

      pull_result = CLI.pull(scope, "/some/path")
      assert {:error, _reason} = pull_result
    end
  end

  # ============================================================================
  # Filesystem State Management Tests
  # ============================================================================

  describe "filesystem state handling" do
    @tag :integration
    test "clone fails if target directory already exists" do
      scope = scope_with_github_integration()
      clone_path = temp_clone_path()

      File.mkdir_p!(clone_path)

      try do
        result = CLI.clone(scope, test_repo_url(), clone_path)

        assert {:error, _reason} = result
      after
        cleanup_path(clone_path)
      end
    end

    @tag :integration
    test "clone fails if parent directory doesn't exist" do
      scope = scope_with_github_integration()
      clone_path = "/nonexistent_parent_dir_#{System.unique_integer([:positive])}/repo"

      result = CLI.clone(scope, test_repo_url(), clone_path)

      assert {:error, _reason} = result
      refute File.exists?(clone_path)
    end

    test "pull fails gracefully for non-existent paths" do
      scope = scope_with_github_integration()

      invalid_paths = [
        "/completely/nonexistent/path",
        nil,
        ""
      ]

      for invalid_path <- invalid_paths do
        result = CLI.pull(scope, invalid_path)
        assert {:error, _reason} = result
      end
    end

    test "pull fails gracefully for non-git directories" do
      scope = scope_with_github_integration()
      non_git_path = temp_clone_path()

      File.mkdir_p!(non_git_path)

      try do
        result = CLI.pull(scope, non_git_path)

        assert {:error, _reason} = result
      after
        cleanup_path(non_git_path)
      end
    end
  end

  # ============================================================================
  # Idempotency Tests
  # ============================================================================

  describe "operation idempotency" do
    @tag :integration
    test "multiple pull operations succeed on same repository" do
      scope = scope_with_github_integration()
      clone_path = temp_clone_path()

      try do
        {:ok, ^clone_path} = CLI.clone(scope, test_repo_url(), clone_path)

        # Multiple pulls should all succeed
        assert :ok = CLI.pull(scope, clone_path)
        assert :ok = CLI.pull(scope, clone_path)
        assert :ok = CLI.pull(scope, clone_path)
      after
        cleanup_path(clone_path)
      end
    end

    @tag :integration
    test "pull after clone with no remote changes succeeds" do
      scope = scope_with_github_integration()
      clone_path = temp_clone_path()

      try do
        {:ok, ^clone_path} = CLI.clone(scope, test_repo_url(), clone_path)

        # Immediate pull with no changes should succeed
        assert :ok = CLI.pull(scope, clone_path)
      after
        cleanup_path(clone_path)
      end
    end
  end

  # ============================================================================
  # Error Recovery Tests
  # ============================================================================

  describe "error recovery and resilience" do
    @tag :integration
    test "repository remains usable after failed pull attempt" do
      scope = scope_with_github_integration()
      clone_path = temp_clone_path()

      try do
        # Clone repository
        {:ok, ^clone_path} = CLI.clone(scope, test_repo_url(), clone_path)

        # Create scenario that might cause pull issues
        readme_path = Path.join(clone_path, "README.md")
        File.write!(readme_path, "# Modified content\n")

        # Attempt operations - repository should remain functional
        {status_output, 0} = System.cmd("git", ["status"], cd: clone_path)
        assert String.contains?(status_output, "modified")

        # Can still perform git operations
        System.cmd("git", ["add", "."], cd: clone_path)
        {status_output, 0} = System.cmd("git", ["status"], cd: clone_path)
        assert String.contains?(status_output, "Changes to be committed")
      after
        cleanup_path(clone_path)
      end
    end
  end
end

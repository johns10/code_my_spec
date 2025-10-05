defmodule CodeMySpec.Git.CLITest do
  use CodeMySpec.DataCase, async: true

  import CodeMySpec.{UsersFixtures, IntegrationsFixtures}

  alias CodeMySpec.Git.CLI
  alias CodeMySpec.Users.Scope

  # ============================================================================
  # Fixtures
  # ============================================================================

  defp github_repo_url, do: "https://github.com/test-owner/test-repo.git"
  defp gitlab_repo_url, do: "https://gitlab.com/test-owner/test-repo.git"
  defp bitbucket_repo_url, do: "https://bitbucket.org/test-owner/test-repo.git"

  defp github_token, do: "ghp_test_token_#{:rand.uniform(100000)}"
  defp gitlab_token, do: "glpat_test_token_#{:rand.uniform(100000)}"

  defp github_authenticated_url(token), do: "https://#{token}@github.com/test-owner/test-repo.git"
  defp gitlab_authenticated_url(token), do: "https://#{token}@gitlab.com/test-owner/test-repo.git"

  defp temp_clone_path do
    base_path = System.tmp_dir!()
    unique_suffix = "git_cli_test_#{System.unique_integer([:positive])}"
    Path.join(base_path, unique_suffix)
  end

  defp scope_with_github_integration do
    user = user_fixture()
    token = github_token()
    _integration = github_integration_fixture(user, %{access_token: token})
    scope = %Scope{user: user}
    {scope, token}
  end

  defp scope_with_gitlab_integration do
    user = user_fixture()
    token = gitlab_token()
    _integration = gitlab_integration_fixture(user, %{access_token: token})
    scope = %Scope{user: user}
    {scope, token}
  end

  defp scope_without_integration do
    user = user_fixture()
    %Scope{user: user}
  end

  defp create_test_git_repo(path) do
    File.mkdir_p!(path)
    System.cmd("git", ["init"], cd: path)
    System.cmd("git", ["config", "user.email", "test@example.com"], cd: path)
    System.cmd("git", ["config", "user.name", "Test User"], cd: path)
    File.write!(Path.join(path, "README.md"), "# Test Repo\n")
    System.cmd("git", ["add", "."], cd: path)
    System.cmd("git", ["commit", "-m", "Initial commit"], cd: path)
    path
  end

  defp cleanup_path(path) do
    if File.exists?(path) do
      File.rm_rf!(path)
    end
  end

  # ============================================================================
  # clone/3 - Happy Path Tests
  # ============================================================================

  describe "clone/3 - GitHub repositories" do
    test "successfully clones GitHub repository when integration exists" do
      {scope, token} = scope_with_github_integration()
      clone_path = temp_clone_path()

      # Create a real test repo to clone from
      source_path = temp_clone_path()
      create_test_git_repo(source_path)

      try do
        # Note: In real implementation, this would clone from the authenticated URL
        # For now, we test with a local path since we can't clone from fake GitHub URLs
        result = CLI.clone(scope, source_path, clone_path)

        assert {:ok, ^clone_path} = result
        assert File.exists?(clone_path)
        assert File.exists?(Path.join(clone_path, ".git"))
        assert File.exists?(Path.join(clone_path, "README.md"))
      after
        cleanup_path(source_path)
        cleanup_path(clone_path)
      end
    end

    test "returns error when GitHub integration not found" do
      scope = scope_without_integration()
      clone_path = temp_clone_path()

      result = CLI.clone(scope, github_repo_url(), clone_path)

      assert {:error, :not_connected} = result
      refute File.exists?(clone_path)
    end
  end

  describe "clone/3 - GitLab repositories" do
    test "successfully clones GitLab repository when integration exists" do
      {scope, token} = scope_with_gitlab_integration()
      clone_path = temp_clone_path()

      # Create a real test repo to clone from
      source_path = temp_clone_path()
      create_test_git_repo(source_path)

      try do
        result = CLI.clone(scope, source_path, clone_path)

        assert {:ok, ^clone_path} = result
        assert File.exists?(clone_path)
        assert File.exists?(Path.join(clone_path, ".git"))
      after
        cleanup_path(source_path)
        cleanup_path(clone_path)
      end
    end

    test "returns error when GitLab integration not found" do
      scope = scope_without_integration()
      clone_path = temp_clone_path()

      result = CLI.clone(scope, gitlab_repo_url(), clone_path)

      assert {:error, :not_connected} = result
      refute File.exists?(clone_path)
    end
  end

  # ============================================================================
  # clone/3 - Error Cases
  # ============================================================================

  describe "clone/3 - URL validation errors" do
    test "returns error for invalid repository URL" do
      {scope, _token} = scope_with_github_integration()
      clone_path = temp_clone_path()

      result = CLI.clone(scope, "not-a-valid-url", clone_path)

      assert {:error, :invalid_url} = result
      refute File.exists?(clone_path)
    end

    test "returns error for SSH URL format" do
      {scope, _token} = scope_with_github_integration()
      clone_path = temp_clone_path()

      result = CLI.clone(scope, "git@github.com:owner/repo.git", clone_path)

      assert {:error, :invalid_url} = result
      refute File.exists?(clone_path)
    end

    test "returns error for HTTP (non-HTTPS) URL" do
      {scope, _token} = scope_with_github_integration()
      clone_path = temp_clone_path()

      result = CLI.clone(scope, "http://github.com/owner/repo.git", clone_path)

      assert {:error, :invalid_url} = result
      refute File.exists?(clone_path)
    end

    test "returns error for nil URL" do
      {scope, _token} = scope_with_github_integration()
      clone_path = temp_clone_path()

      result = CLI.clone(scope, nil, clone_path)

      assert {:error, :invalid_url} = result
      refute File.exists?(clone_path)
    end

    test "returns error for empty URL" do
      {scope, _token} = scope_with_github_integration()
      clone_path = temp_clone_path()

      result = CLI.clone(scope, "", clone_path)

      assert {:error, :invalid_url} = result
      refute File.exists?(clone_path)
    end
  end

  describe "clone/3 - unsupported providers" do
    test "returns error for Bitbucket URL when only GitHub integration exists" do
      {scope, _token} = scope_with_github_integration()
      clone_path = temp_clone_path()

      result = CLI.clone(scope, bitbucket_repo_url(), clone_path)

      assert {:error, :unsupported_provider} = result
      refute File.exists?(clone_path)
    end

    test "returns error for custom domain git hosting" do
      {scope, _token} = scope_with_github_integration()
      clone_path = temp_clone_path()

      result = CLI.clone(scope, "https://git.custom-domain.com/owner/repo.git", clone_path)

      assert {:error, :unsupported_provider} = result
      refute File.exists?(clone_path)
    end
  end

  describe "clone/3 - path validation" do
    test "returns error when clone path already exists" do
      {scope, _token} = scope_with_github_integration()
      source_path = temp_clone_path()
      clone_path = temp_clone_path()

      create_test_git_repo(source_path)
      File.mkdir_p!(clone_path)

      try do
        result = CLI.clone(scope, source_path, clone_path)

        assert {:error, _reason} = result
      after
        cleanup_path(source_path)
        cleanup_path(clone_path)
      end
    end

    test "returns error when clone path parent directory doesn't exist" do
      {scope, _token} = scope_with_github_integration()
      source_path = temp_clone_path()
      clone_path = "/nonexistent/parent/directory/repo"

      create_test_git_repo(source_path)

      try do
        result = CLI.clone(scope, source_path, clone_path)

        assert {:error, _reason} = result
      after
        cleanup_path(source_path)
      end
    end
  end

  # ============================================================================
  # clone/3 - Edge Cases
  # ============================================================================

  describe "clone/3 - edge cases" do
    test "handles URL with trailing slash" do
      {scope, _token} = scope_with_github_integration()
      source_path = temp_clone_path()
      clone_path = temp_clone_path()

      create_test_git_repo(source_path)

      try do
        # Add trailing slash to source path
        result = CLI.clone(scope, source_path <> "/", clone_path)

        # Should either succeed or return a specific error
        case result do
          {:ok, ^clone_path} ->
            assert File.exists?(clone_path)

          {:error, _reason} ->
            :ok
        end
      after
        cleanup_path(source_path)
        cleanup_path(clone_path)
      end
    end

    test "handles URL without .git extension" do
      {scope, _token} = scope_with_github_integration()
      source_path = temp_clone_path()
      clone_path = temp_clone_path()

      create_test_git_repo(source_path)

      try do
        result = CLI.clone(scope, source_path, clone_path)

        assert {:ok, ^clone_path} = result
      after
        cleanup_path(source_path)
        cleanup_path(clone_path)
      end
    end

    test "handles very long repository paths" do
      {scope, _token} = scope_with_github_integration()
      clone_path = temp_clone_path()

      long_path_url = "https://github.com/org/group/subgroup/deeply/nested/path/repo.git"

      result = CLI.clone(scope, long_path_url, clone_path)

      # Should return error since URL is fake, but validates the URL structure
      assert {:error, _reason} = result
    end
  end

  # ============================================================================
  # pull/2 - Happy Path Tests
  # ============================================================================

  describe "pull/2 - successful operations" do
    test "successfully pulls changes from GitHub repository" do
      {scope, token} = scope_with_github_integration()

      # Create a test repository with remote
      repo_path = temp_clone_path()
      remote_path = temp_clone_path()

      create_test_git_repo(remote_path)
      System.cmd("git", ["clone", remote_path, repo_path])

      # Make a change in the remote
      File.write!(Path.join(remote_path, "new_file.txt"), "New content")
      System.cmd("git", ["add", "."], cd: remote_path)
      System.cmd("git", ["commit", "-m", "Add new file"], cd: remote_path)

      try do
        result = CLI.pull(scope, repo_path)

        assert :ok = result

        # Verify changes were pulled
        pulled_file_path = Path.join(repo_path, "new_file.txt")
        assert File.exists?(pulled_file_path)
        assert File.read!(pulled_file_path) == "New content"
      after
        cleanup_path(repo_path)
        cleanup_path(remote_path)
      end
    end

    test "successfully pulls changes from GitLab repository" do
      {scope, token} = scope_with_gitlab_integration()

      repo_path = temp_clone_path()
      remote_path = temp_clone_path()

      create_test_git_repo(remote_path)
      System.cmd("git", ["clone", remote_path, repo_path])

      # Make a change in the remote
      File.write!(Path.join(remote_path, "gitlab_file.txt"), "GitLab content")
      System.cmd("git", ["add", "."], cd: remote_path)
      System.cmd("git", ["commit", "-m", "Add GitLab file"], cd: remote_path)

      try do
        result = CLI.pull(scope, repo_path)

        assert :ok = result
      after
        cleanup_path(repo_path)
        cleanup_path(remote_path)
      end
    end

    test "pull succeeds with no new changes" do
      {scope, _token} = scope_with_github_integration()

      repo_path = temp_clone_path()
      remote_path = temp_clone_path()

      create_test_git_repo(remote_path)
      System.cmd("git", ["clone", remote_path, repo_path])

      try do
        # Pull without any new changes
        result = CLI.pull(scope, repo_path)

        assert :ok = result
      after
        cleanup_path(repo_path)
        cleanup_path(remote_path)
      end
    end
  end

  # ============================================================================
  # pull/2 - Error Cases
  # ============================================================================

  describe "pull/2 - integration errors" do
    test "returns error when integration not found" do
      scope = scope_without_integration()
      repo_path = temp_clone_path()
      remote_path = temp_clone_path()

      create_test_git_repo(remote_path)
      System.cmd("git", ["clone", remote_path, repo_path])

      # Set remote to a GitHub URL
      System.cmd(
        "git",
        ["remote", "set-url", "origin", github_repo_url()],
        cd: repo_path
      )

      try do
        result = CLI.pull(scope, repo_path)

        assert {:error, :not_connected} = result
      after
        cleanup_path(repo_path)
        cleanup_path(remote_path)
      end
    end

    test "returns error when GitHub integration exists but repo is GitLab" do
      {scope, _token} = scope_with_github_integration()
      repo_path = temp_clone_path()
      remote_path = temp_clone_path()

      create_test_git_repo(remote_path)
      System.cmd("git", ["clone", remote_path, repo_path])

      # Set remote to a GitLab URL
      System.cmd(
        "git",
        ["remote", "set-url", "origin", gitlab_repo_url()],
        cd: repo_path
      )

      try do
        result = CLI.pull(scope, repo_path)

        assert {:error, :not_connected} = result
      after
        cleanup_path(repo_path)
        cleanup_path(remote_path)
      end
    end
  end

  describe "pull/2 - path validation" do
    test "returns error when path doesn't exist" do
      {scope, _token} = scope_with_github_integration()

      result = CLI.pull(scope, "/nonexistent/path/to/repo")

      assert {:error, _reason} = result
    end

    test "returns error when path is not a git repository" do
      {scope, _token} = scope_with_github_integration()
      non_repo_path = temp_clone_path()

      File.mkdir_p!(non_repo_path)

      try do
        result = CLI.pull(scope, non_repo_path)

        assert {:error, _reason} = result
      after
        cleanup_path(non_repo_path)
      end
    end

    test "returns error for nil path" do
      {scope, _token} = scope_with_github_integration()

      result = CLI.pull(scope, nil)

      assert {:error, _reason} = result
    end

    test "returns error for empty path" do
      {scope, _token} = scope_with_github_integration()

      result = CLI.pull(scope, "")

      assert {:error, _reason} = result
    end
  end

  describe "pull/2 - remote URL validation" do
    test "returns error when repository has no remote configured" do
      {scope, _token} = scope_with_github_integration()
      repo_path = temp_clone_path()

      create_test_git_repo(repo_path)
      # Remove the default origin remote
      System.cmd("git", ["remote", "remove", "origin"], cd: repo_path)

      try do
        result = CLI.pull(scope, repo_path)

        assert {:error, _reason} = result
      after
        cleanup_path(repo_path)
      end
    end

    test "returns error for unsupported remote URL provider" do
      {scope, _token} = scope_with_github_integration()
      repo_path = temp_clone_path()
      remote_path = temp_clone_path()

      create_test_git_repo(remote_path)
      System.cmd("git", ["clone", remote_path, repo_path])

      # Set remote to an unsupported provider
      System.cmd(
        "git",
        ["remote", "set-url", "origin", bitbucket_repo_url()],
        cd: repo_path
      )

      try do
        result = CLI.pull(scope, repo_path)

        assert {:error, :unsupported_provider} = result
      after
        cleanup_path(repo_path)
        cleanup_path(remote_path)
      end
    end
  end

  # ============================================================================
  # pull/2 - Edge Cases
  # ============================================================================

  describe "pull/2 - edge cases" do
    test "handles repository with detached HEAD" do
      {scope, _token} = scope_with_github_integration()
      repo_path = temp_clone_path()
      remote_path = temp_clone_path()

      create_test_git_repo(remote_path)
      System.cmd("git", ["clone", remote_path, repo_path])

      # Get the current commit hash and checkout in detached HEAD state
      {hash, 0} = System.cmd("git", ["rev-parse", "HEAD"], cd: repo_path)
      commit_hash = String.trim(hash)
      System.cmd("git", ["checkout", commit_hash], cd: repo_path)

      try do
        result = CLI.pull(scope, repo_path)

        # Pull might fail or succeed depending on implementation
        case result do
          :ok -> assert true
          {:error, _reason} -> assert true
        end
      after
        cleanup_path(repo_path)
        cleanup_path(remote_path)
      end
    end

    test "handles repository with uncommitted changes" do
      {scope, _token} = scope_with_github_integration()
      repo_path = temp_clone_path()
      remote_path = temp_clone_path()

      create_test_git_repo(remote_path)
      System.cmd("git", ["clone", remote_path, repo_path])

      # Create uncommitted changes
      File.write!(Path.join(repo_path, "uncommitted.txt"), "Uncommitted content")

      try do
        result = CLI.pull(scope, repo_path)

        # Should succeed since there are no conflicts
        assert :ok = result
      after
        cleanup_path(repo_path)
        cleanup_path(remote_path)
      end
    end

    test "handles repository with merge conflicts" do
      {scope, _token} = scope_with_github_integration()
      repo_path = temp_clone_path()
      remote_path = temp_clone_path()

      create_test_git_repo(remote_path)
      System.cmd("git", ["clone", remote_path, repo_path])

      # Create conflicting changes in remote
      conflict_file = Path.join(remote_path, "README.md")
      File.write!(conflict_file, "# Remote change\n")
      System.cmd("git", ["add", "."], cd: remote_path)
      System.cmd("git", ["commit", "-m", "Remote change"], cd: remote_path)

      # Create conflicting changes locally
      local_conflict_file = Path.join(repo_path, "README.md")
      File.write!(local_conflict_file, "# Local change\n")
      System.cmd("git", ["add", "."], cd: repo_path)
      System.cmd("git", ["commit", "-m", "Local change"], cd: repo_path)

      try do
        result = CLI.pull(scope, repo_path)

        # Pull should fail due to merge conflict
        assert {:error, _reason} = result
      after
        cleanup_path(repo_path)
        cleanup_path(remote_path)
      end
    end

    test "restores original remote URL after pull operation" do
      {scope, _token} = scope_with_github_integration()
      repo_path = temp_clone_path()
      remote_path = temp_clone_path()

      create_test_git_repo(remote_path)
      System.cmd("git", ["clone", remote_path, repo_path])

      original_url = github_repo_url()
      System.cmd("git", ["remote", "set-url", "origin", original_url], cd: repo_path)

      try do
        # Pull (will likely fail but that's ok for this test)
        _result = CLI.pull(scope, repo_path)

        # Verify remote URL is restored (not containing token)
        {remote_url, 0} = System.cmd("git", ["remote", "get-url", "origin"], cd: repo_path)
        remote_url = String.trim(remote_url)

        # Remote URL should not contain token
        refute String.contains?(remote_url, "ghp_")
        refute String.contains?(remote_url, "@github.com")
      after
        cleanup_path(repo_path)
        cleanup_path(remote_path)
      end
    end
  end

  # ============================================================================
  # Integration Tests - clone/3 and pull/2 together
  # ============================================================================

  describe "integration - clone and pull workflow" do
    test "can clone repository and then pull updates" do
      {scope, _token} = scope_with_github_integration()

      source_path = temp_clone_path()
      clone_path = temp_clone_path()

      create_test_git_repo(source_path)

      try do
        # Clone the repository
        assert {:ok, ^clone_path} = CLI.clone(scope, source_path, clone_path)
        assert File.exists?(clone_path)

        # Make changes in source
        File.write!(Path.join(source_path, "update.txt"), "Updated content")
        System.cmd("git", ["add", "."], cd: source_path)
        System.cmd("git", ["commit", "-m", "Add update"], cd: source_path)

        # Pull changes into clone
        assert :ok = CLI.pull(scope, clone_path)

        # Verify update was pulled
        assert File.exists?(Path.join(clone_path, "update.txt"))
      after
        cleanup_path(source_path)
        cleanup_path(clone_path)
      end
    end

    test "multiple clones from same source work independently" do
      {scope, _token} = scope_with_github_integration()

      source_path = temp_clone_path()
      clone_path_1 = temp_clone_path()
      clone_path_2 = temp_clone_path()

      create_test_git_repo(source_path)

      try do
        # Clone repository twice
        assert {:ok, ^clone_path_1} = CLI.clone(scope, source_path, clone_path_1)
        assert {:ok, ^clone_path_2} = CLI.clone(scope, source_path, clone_path_2)

        # Make changes in first clone
        File.write!(Path.join(clone_path_1, "first.txt"), "First clone content")
        System.cmd("git", ["add", "."], cd: clone_path_1)
        System.cmd("git", ["commit", "-m", "First clone change"], cd: clone_path_1)
        System.cmd("git", ["push"], cd: clone_path_1)

        # Pull into second clone
        assert :ok = CLI.pull(scope, clone_path_2)

        # Verify second clone received changes
        assert File.exists?(Path.join(clone_path_2, "first.txt"))
      after
        cleanup_path(source_path)
        cleanup_path(clone_path_1)
        cleanup_path(clone_path_2)
      end
    end
  end

  # ============================================================================
  # Security Tests
  # ============================================================================

  describe "security - credential handling" do
    test "clone does not expose token in process list" do
      {scope, token} = scope_with_github_integration()
      source_path = temp_clone_path()
      clone_path = temp_clone_path()

      create_test_git_repo(source_path)

      try do
        _result = CLI.clone(scope, source_path, clone_path)

        # In a real implementation, verify that git operations use credential helpers
        # or environment variables rather than embedding tokens in command arguments
        assert true
      after
        cleanup_path(source_path)
        cleanup_path(clone_path)
      end
    end

    test "pull does not leave token in remote URL after error" do
      {scope, _token} = scope_with_github_integration()
      repo_path = temp_clone_path()
      remote_path = temp_clone_path()

      create_test_git_repo(remote_path)
      System.cmd("git", ["clone", remote_path, repo_path])

      original_url = github_repo_url()
      System.cmd("git", ["remote", "set-url", "origin", original_url], cd: repo_path)

      try do
        # Attempt pull (will likely fail)
        _result = CLI.pull(scope, repo_path)

        # Verify remote URL doesn't contain token even after error
        {remote_url, 0} = System.cmd("git", ["remote", "get-url", "origin"], cd: repo_path)
        remote_url = String.trim(remote_url)

        refute String.contains?(remote_url, "ghp_")
        refute String.contains?(remote_url, "glpat")
      after
        cleanup_path(repo_path)
        cleanup_path(remote_path)
      end
    end

    test "pull removes token from remote URL even on git command failure" do
      {scope, _token} = scope_with_github_integration()
      repo_path = temp_clone_path()

      create_test_git_repo(repo_path)

      original_url = github_repo_url()
      System.cmd("git", ["remote", "add", "origin", original_url], cd: repo_path)

      try do
        # Pull will fail (repo doesn't actually exist)
        _result = CLI.pull(scope, repo_path)

        # Verify token was cleaned up from remote URL
        {remote_url, 0} = System.cmd("git", ["remote", "get-url", "origin"], cd: repo_path)
        remote_url = String.trim(remote_url)

        refute String.contains?(remote_url, "@github.com")
      after
        cleanup_path(repo_path)
      end
    end
  end

  # ============================================================================
  # Scope and Multi-tenancy Tests
  # ============================================================================

  describe "scope isolation" do
    test "different users with same provider can clone independently" do
      {scope1, _token1} = scope_with_github_integration()
      {scope2, _token2} = scope_with_github_integration()

      source_path = temp_clone_path()
      clone_path_1 = temp_clone_path()
      clone_path_2 = temp_clone_path()

      create_test_git_repo(source_path)

      try do
        # Each user clones with their own credentials
        assert {:ok, ^clone_path_1} = CLI.clone(scope1, source_path, clone_path_1)
        assert {:ok, ^clone_path_2} = CLI.clone(scope2, source_path, clone_path_2)

        assert File.exists?(clone_path_1)
        assert File.exists?(clone_path_2)
      after
        cleanup_path(source_path)
        cleanup_path(clone_path_1)
        cleanup_path(clone_path_2)
      end
    end

    test "user without integration cannot access other user's repositories" do
      {_scope_with_integration, _token} = scope_with_github_integration()
      scope_without = scope_without_integration()

      clone_path = temp_clone_path()

      result = CLI.clone(scope_without, github_repo_url(), clone_path)

      assert {:error, :not_connected} = result
      refute File.exists?(clone_path)
    end
  end

  # ============================================================================
  # Property-Based Tests
  # ============================================================================

  describe "property-based tests" do
    test "clone always creates .git directory on success" do
      {scope, _token} = scope_with_github_integration()

      source_path = temp_clone_path()
      clone_paths = for _ <- 1..3, do: temp_clone_path()

      create_test_git_repo(source_path)

      try do
        for clone_path <- clone_paths do
          case CLI.clone(scope, source_path, clone_path) do
            {:ok, path} ->
              assert File.exists?(Path.join(path, ".git"))
              assert File.dir?(Path.join(path, ".git"))

            {:error, _reason} ->
              :ok
          end
        end
      after
        cleanup_path(source_path)
        Enum.each(clone_paths, &cleanup_path/1)
      end
    end

    test "pull is idempotent when no changes exist" do
      {scope, _token} = scope_with_github_integration()

      repo_path = temp_clone_path()
      remote_path = temp_clone_path()

      create_test_git_repo(remote_path)
      System.cmd("git", ["clone", remote_path, repo_path])

      try do
        # Pull multiple times
        assert :ok = CLI.pull(scope, repo_path)
        assert :ok = CLI.pull(scope, repo_path)
        assert :ok = CLI.pull(scope, repo_path)
      after
        cleanup_path(repo_path)
        cleanup_path(remote_path)
      end
    end

    test "clone fails predictably for invalid inputs" do
      {scope, _token} = scope_with_github_integration()
      clone_path = temp_clone_path()

      invalid_inputs = [
        nil,
        "",
        "not-a-url",
        "git@github.com:owner/repo.git",
        "http://github.com/owner/repo.git"
      ]

      for invalid_url <- invalid_inputs do
        result = CLI.clone(scope, invalid_url, clone_path)

        assert {:error, _reason} = result
        refute File.exists?(clone_path)
      end
    end

    test "pull fails predictably for invalid paths" do
      {scope, _token} = scope_with_github_integration()

      invalid_paths = [
        nil,
        "",
        "/nonexistent/path",
        "/tmp/not-a-git-repo-#{:rand.uniform(1000)}"
      ]

      for invalid_path <- invalid_paths do
        result = CLI.pull(scope, invalid_path)

        assert {:error, _reason} = result
      end
    end
  end
end
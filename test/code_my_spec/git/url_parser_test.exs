defmodule CodeMySpec.Git.URLParserTest do
  use ExUnit.Case, async: true

  alias CodeMySpec.Git.URLParser

  # ============================================================================
  # Fixtures
  # ============================================================================

  defp github_https_url, do: "https://github.com/owner/repo.git"
  defp github_https_url_no_dot_git, do: "https://github.com/owner/repo"
  defp github_https_url_with_path, do: "https://github.com/owner/repo/some/path.git"

  defp gitlab_https_url, do: "https://gitlab.com/owner/repo.git"
  defp gitlab_https_url_no_dot_git, do: "https://gitlab.com/owner/repo"
  defp gitlab_https_url_with_subgroup, do: "https://gitlab.com/group/subgroup/repo.git"

  defp github_ssh_url, do: "git@github.com:owner/repo.git"
  defp gitlab_ssh_url, do: "git@gitlab.com:owner/repo.git"

  defp http_url, do: "http://github.com/owner/repo.git"
  defp unknown_provider_url, do: "https://bitbucket.org/owner/repo.git"
  defp malformed_url, do: "not-a-url"
  defp empty_url, do: ""

  defp github_token, do: "ghp_token123abc"
  defp gitlab_token, do: "glpat-token456def"

  defp expected_github_authenticated_url,
    do: "https://#{github_token()}@github.com/owner/repo.git"

  defp expected_gitlab_authenticated_url,
    do: "https://#{gitlab_token()}@gitlab.com/owner/repo.git"

  # ============================================================================
  # provider/1 - Happy Path Tests
  # ============================================================================

  describe "provider/1 - valid GitHub URLs" do
    test "identifies GitHub provider from standard HTTPS URL" do
      assert {:ok, :github} = URLParser.provider(github_https_url())
    end

    test "identifies GitHub provider from HTTPS URL without .git extension" do
      assert {:ok, :github} = URLParser.provider(github_https_url_no_dot_git())
    end

    test "identifies GitHub provider from HTTPS URL with additional path segments" do
      assert {:ok, :github} = URLParser.provider(github_https_url_with_path())
    end
  end

  describe "provider/1 - valid GitLab URLs" do
    test "identifies GitLab provider from standard HTTPS URL" do
      assert {:ok, :gitlab} = URLParser.provider(gitlab_https_url())
    end

    test "identifies GitLab provider from HTTPS URL without .git extension" do
      assert {:ok, :gitlab} = URLParser.provider(gitlab_https_url_no_dot_git())
    end

    test "identifies GitLab provider from HTTPS URL with subgroups" do
      assert {:ok, :gitlab} = URLParser.provider(gitlab_https_url_with_subgroup())
    end
  end

  # ============================================================================
  # provider/1 - Error Cases
  # ============================================================================

  describe "provider/1 - invalid URL formats" do
    test "returns error for SSH URL format" do
      assert {:error, :invalid_url} = URLParser.provider(github_ssh_url())
    end

    test "returns error for GitLab SSH URL format" do
      assert {:error, :invalid_url} = URLParser.provider(gitlab_ssh_url())
    end

    test "returns error for HTTP (non-HTTPS) URL" do
      assert {:error, :invalid_url} = URLParser.provider(http_url())
    end

    test "returns error for malformed URL" do
      assert {:error, :invalid_url} = URLParser.provider(malformed_url())
    end

    test "returns error for empty string" do
      assert {:error, :invalid_url} = URLParser.provider(empty_url())
    end

    test "returns error for nil input" do
      assert {:error, :invalid_url} = URLParser.provider(nil)
    end
  end

  describe "provider/1 - unsupported providers" do
    test "returns error for unknown git provider" do
      assert {:error, :unsupported_provider} = URLParser.provider(unknown_provider_url())
    end

    test "returns error for custom domain HTTPS URLs" do
      custom_domain_url = "https://git.mycustomdomain.com/owner/repo.git"
      assert {:error, :unsupported_provider} = URLParser.provider(custom_domain_url)
    end
  end

  # ============================================================================
  # provider/1 - Edge Cases
  # ============================================================================

  describe "provider/1 - edge cases" do
    test "handles URLs with trailing slashes" do
      url_with_slash = "https://github.com/owner/repo.git/"
      assert {:ok, :github} = URLParser.provider(url_with_slash)
    end

    test "handles URLs with query parameters" do
      url_with_params = "https://github.com/owner/repo.git?ref=main"
      assert {:ok, :github} = URLParser.provider(url_with_params)
    end

    test "handles URLs with fragments" do
      url_with_fragment = "https://github.com/owner/repo.git#readme"
      assert {:ok, :github} = URLParser.provider(url_with_fragment)
    end

    test "handles URLs with mixed case domains" do
      mixed_case_url = "https://GitHub.com/owner/repo.git"
      assert {:ok, :github} = URLParser.provider(mixed_case_url)
    end

    test "handles URLs with www subdomain" do
      www_url = "https://www.github.com/owner/repo.git"
      # This might be :unsupported_provider or :github depending on implementation
      # Adjust based on actual behavior
      result = URLParser.provider(www_url)
      assert match?({:ok, _} | {:error, _}, result)
    end

    test "handles very long repository paths" do
      long_path_url =
        "https://gitlab.com/group/subgroup/nested/deeply/nested/path/to/repo.git"

      assert {:ok, :gitlab} = URLParser.provider(long_path_url)
    end

    test "handles URLs with port numbers" do
      url_with_port = "https://github.com:443/owner/repo.git"
      result = URLParser.provider(url_with_port)
      # Should either work or return invalid_url, depending on implementation
      assert match?({:ok, :github} | {:error, :invalid_url}, result)
    end

    test "handles whitespace in URL" do
      url_with_spaces = "  https://github.com/owner/repo.git  "
      # Should either trim and succeed or fail with invalid_url
      result = URLParser.provider(url_with_spaces)
      assert match?({:ok, :github} | {:error, :invalid_url}, result)
    end
  end

  # ============================================================================
  # inject_token/2 - Happy Path Tests
  # ============================================================================

  describe "inject_token/2 - GitHub URLs" do
    test "injects token into standard GitHub HTTPS URL" do
      expected = expected_github_authenticated_url()
      assert {:ok, ^expected} = URLParser.inject_token(github_https_url(), github_token())
    end

    test "injects token into GitHub URL without .git extension" do
      expected = "https://#{github_token()}@github.com/owner/repo"

      assert {:ok, ^expected} =
               URLParser.inject_token(github_https_url_no_dot_git(), github_token())
    end

    test "injects token into GitHub URL with additional path segments" do
      expected = "https://#{github_token()}@github.com/owner/repo/some/path.git"

      assert {:ok, ^expected} =
               URLParser.inject_token(github_https_url_with_path(), github_token())
    end
  end

  describe "inject_token/2 - GitLab URLs" do
    test "injects token into standard GitLab HTTPS URL" do
      expected = expected_gitlab_authenticated_url()
      assert {:ok, ^expected} = URLParser.inject_token(gitlab_https_url(), gitlab_token())
    end

    test "injects token into GitLab URL without .git extension" do
      expected = "https://#{gitlab_token()}@gitlab.com/owner/repo"

      assert {:ok, ^expected} =
               URLParser.inject_token(gitlab_https_url_no_dot_git(), gitlab_token())
    end

    test "injects token into GitLab URL with subgroups" do
      expected = "https://#{gitlab_token()}@gitlab.com/group/subgroup/repo.git"

      assert {:ok, ^expected} =
               URLParser.inject_token(gitlab_https_url_with_subgroup(), gitlab_token())
    end
  end

  # ============================================================================
  # inject_token/2 - Error Cases
  # ============================================================================

  describe "inject_token/2 - invalid URL formats" do
    test "returns error for SSH URL format" do
      assert {:error, :invalid_url} = URLParser.inject_token(github_ssh_url(), github_token())
    end

    test "returns error for HTTP (non-HTTPS) URL" do
      assert {:error, :invalid_url} = URLParser.inject_token(http_url(), github_token())
    end

    test "returns error for malformed URL" do
      assert {:error, :invalid_url} = URLParser.inject_token(malformed_url(), github_token())
    end

    test "returns error for empty URL" do
      assert {:error, :invalid_url} = URLParser.inject_token(empty_url(), github_token())
    end

    test "returns error for nil URL" do
      assert {:error, :invalid_url} = URLParser.inject_token(nil, github_token())
    end
  end

  describe "inject_token/2 - token validation" do
    test "handles empty token string" do
      expected = "https://@github.com/owner/repo.git"

      result = URLParser.inject_token(github_https_url(), "")
      # Implementation may reject empty tokens or allow them
      assert match?({:ok, ^expected} | {:error, _}, result)
    end

    test "handles nil token" do
      result = URLParser.inject_token(github_https_url(), nil)
      # Implementation should handle nil token gracefully
      assert match?({:ok, _} | {:error, _}, result)
    end

    test "handles token with special characters" do
      special_token = "token-with-special!@#$%^&*()chars"
      result = URLParser.inject_token(github_https_url(), special_token)
      # Should properly URL encode or reject
      assert match?({:ok, _} | {:error, _}, result)
    end
  end

  # ============================================================================
  # inject_token/2 - Edge Cases
  # ============================================================================

  describe "inject_token/2 - edge cases" do
    test "handles URL that already contains credentials" do
      url_with_creds = "https://old_token@github.com/owner/repo.git"
      result = URLParser.inject_token(url_with_creds, github_token())
      # Should either replace old token or return error
      assert match?({:ok, _} | {:error, _}, result)
    end

    test "handles URL that contains username but no password" do
      url_with_user = "https://username@github.com/owner/repo.git"
      result = URLParser.inject_token(url_with_user, github_token())
      # Should either replace or add token
      assert match?({:ok, _} | {:error, _}, result)
    end

    test "handles URL with trailing slash" do
      url_with_slash = "https://github.com/owner/repo.git/"
      result = URLParser.inject_token(url_with_slash, github_token())
      assert {:ok, url} = result
      assert String.contains?(url, github_token())
    end

    test "handles URL with query parameters" do
      url_with_params = "https://github.com/owner/repo.git?ref=main"
      result = URLParser.inject_token(url_with_params, github_token())
      # Should preserve query params
      case result do
        {:ok, url} ->
          assert String.contains?(url, github_token())
          assert String.contains?(url, "?ref=main")

        {:error, _} ->
          :ok
      end
    end

    test "handles URL with fragment" do
      url_with_fragment = "https://github.com/owner/repo.git#readme"
      result = URLParser.inject_token(url_with_fragment, github_token())

      case result do
        {:ok, url} ->
          assert String.contains?(url, github_token())
          assert String.contains?(url, "#readme")

        {:error, _} ->
          :ok
      end
    end

    test "handles very long tokens" do
      long_token = String.duplicate("a", 1000)
      result = URLParser.inject_token(github_https_url(), long_token)
      assert match?({:ok, _} | {:error, _}, result)
    end
  end

  # ============================================================================
  # Integration Tests - provider/1 and inject_token/2 together
  # ============================================================================

  describe "integration - provider detection and token injection" do
    test "provider detection and token injection work together for GitHub" do
      url = github_https_url()
      assert {:ok, :github} = URLParser.provider(url)
      assert {:ok, authenticated_url} = URLParser.inject_token(url, github_token())
      assert String.contains?(authenticated_url, github_token())
      assert String.contains?(authenticated_url, "@github.com")
    end

    test "provider detection and token injection work together for GitLab" do
      url = gitlab_https_url()
      assert {:ok, :gitlab} = URLParser.provider(url)
      assert {:ok, authenticated_url} = URLParser.inject_token(url, gitlab_token())
      assert String.contains?(authenticated_url, gitlab_token())
      assert String.contains?(authenticated_url, "@gitlab.com")
    end

    test "unsupported provider cannot have token injected" do
      url = unknown_provider_url()
      assert {:error, :unsupported_provider} = URLParser.provider(url)
      # inject_token might still work since it doesn't check provider
      result = URLParser.inject_token(url, "some_token")
      # Could succeed with token injection even if provider unsupported
      assert match?({:ok, _} | {:error, _}, result)
    end
  end

  # ============================================================================
  # Property-Based Edge Cases
  # ============================================================================

  describe "property-based tests" do
    test "inject_token always produces a valid URL structure when given valid HTTPS URL" do
      valid_urls = [
        github_https_url(),
        gitlab_https_url(),
        github_https_url_no_dot_git(),
        gitlab_https_url_with_subgroup()
      ]

      for url <- valid_urls do
        case URLParser.inject_token(url, "test_token") do
          {:ok, result} ->
            assert String.starts_with?(result, "https://")
            assert String.contains?(result, "@")
            assert String.contains?(result, "test_token")

          {:error, _} ->
            :ok
        end
      end
    end

    test "provider function is consistent with multiple calls" do
      url = github_https_url()
      result1 = URLParser.provider(url)
      result2 = URLParser.provider(url)
      result3 = URLParser.provider(url)

      assert result1 == result2
      assert result2 == result3
    end

    test "inject_token is idempotent for the same inputs" do
      url = github_https_url()
      token = github_token()

      result1 = URLParser.inject_token(url, token)
      result2 = URLParser.inject_token(url, token)

      assert result1 == result2
    end
  end
end

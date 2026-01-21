defmodule CodeMySpecCli.Auth.OAuthClientTest do
  use ExUnit.Case, async: true

  alias CodeMySpecCli.Auth.OAuthClient
  alias CodeMySpec.ClientUsers.ClientUser

  # ============================================================================
  # extract_expires_in/1 Tests
  #
  # This function extracts expires_in (seconds) from an OAuth2.AccessToken.
  # The bug it prevents: using expires_at (Unix timestamp like 1737245961)
  # instead of expires_in (seconds like 7200), which would cause tokens to
  # be stored with wildly incorrect expiration times (55+ years instead of 2 hours).
  # ============================================================================

  describe "extract_expires_in/1" do
    test "returns expires_in from other_params when present" do
      token = %OAuth2.AccessToken{
        access_token: "test_token",
        refresh_token: "test_refresh",
        expires_at: 1_737_245_961,
        other_params: %{"expires_in" => 7200, "scope" => "read write"}
      }

      assert OAuthClient.extract_expires_in(token) == 7200
    end

    test "calculates expires_in from expires_at when other_params missing" do
      # Set expires_at to 1 hour from now
      now = System.system_time(:second)
      one_hour_from_now = now + 3600

      token = %OAuth2.AccessToken{
        access_token: "test_token",
        refresh_token: "test_refresh",
        expires_at: one_hour_from_now,
        other_params: %{}
      }

      result = OAuthClient.extract_expires_in(token)

      # Should be approximately 3600 seconds (allow for test execution time)
      assert result >= 3598
      assert result <= 3600
    end

    test "returns default 7200 when both expires_in and expires_at are nil" do
      token = %OAuth2.AccessToken{
        access_token: "test_token",
        refresh_token: "test_refresh",
        expires_at: nil,
        other_params: %{}
      }

      assert OAuthClient.extract_expires_in(token) == 7200
    end

    test "returns 0 when expires_at is in the past" do
      # Set expires_at to 1 hour ago
      now = System.system_time(:second)
      one_hour_ago = now - 3600

      token = %OAuth2.AccessToken{
        access_token: "test_token",
        refresh_token: "test_refresh",
        expires_at: one_hour_ago,
        other_params: %{}
      }

      # Should return 0, not a negative number
      assert OAuthClient.extract_expires_in(token) == 0
    end

    test "prefers other_params expires_in over calculated value" do
      # This tests that we don't accidentally use the timestamp when
      # the server provides expires_in directly
      now = System.system_time(:second)

      token = %OAuth2.AccessToken{
        access_token: "test_token",
        refresh_token: "test_refresh",
        expires_at: now + 3600,
        other_params: %{"expires_in" => 1800}
      }

      # Should use 1800 from other_params, not calculate from expires_at
      assert OAuthClient.extract_expires_in(token) == 1800
    end

    test "handles large Unix timestamps correctly (the original bug)" do
      # This is the bug we're preventing: expires_at is a Unix timestamp
      # like 1737245961, which should NOT be used directly as expires_in
      token = %OAuth2.AccessToken{
        access_token: "test_token",
        refresh_token: "test_refresh",
        expires_at: 1_737_245_961,
        other_params: %{}
      }

      result = OAuthClient.extract_expires_in(token)

      # Result should be reasonable (< 1 year in seconds)
      # NOT the raw timestamp value which would be ~55 years
      assert result < 31_536_000, "expires_in should be less than 1 year, got #{result}"

      # And definitely not the raw timestamp
      refute result == 1_737_245_961, "Should not return raw Unix timestamp as expires_in"
    end
  end

  # ============================================================================
  # token_expired?/1 Tests
  #
  # This function checks if a user's OAuth token has expired.
  # Tokens are considered expired if:
  # - oauth_expires_at is nil
  # - Less than 5 minutes remain before expiration
  # ============================================================================

  describe "token_expired?/1" do
    test "returns true when oauth_expires_at is nil" do
      user = %ClientUser{
        id: "user_123",
        email: "test@example.com",
        oauth_token: "some_token",
        oauth_refresh_token: "some_refresh",
        oauth_expires_at: nil
      }

      assert OAuthClient.token_expired?(user) == true
    end

    test "returns true when token expires in less than 5 minutes" do
      # Token expires in 4 minutes (240 seconds)
      expires_at = DateTime.add(DateTime.utc_now(), 240, :second)

      user = %ClientUser{
        id: "user_123",
        email: "test@example.com",
        oauth_token: "some_token",
        oauth_refresh_token: "some_refresh",
        oauth_expires_at: expires_at
      }

      assert OAuthClient.token_expired?(user) == true
    end

    test "returns false when token expires in more than 5 minutes" do
      # Token expires in 10 minutes (600 seconds)
      expires_at = DateTime.add(DateTime.utc_now(), 600, :second)

      user = %ClientUser{
        id: "user_123",
        email: "test@example.com",
        oauth_token: "some_token",
        oauth_refresh_token: "some_refresh",
        oauth_expires_at: expires_at
      }

      assert OAuthClient.token_expired?(user) == false
    end

    test "returns true when token already expired" do
      # Token expired 1 hour ago
      expires_at = DateTime.add(DateTime.utc_now(), -3600, :second)

      user = %ClientUser{
        id: "user_123",
        email: "test@example.com",
        oauth_token: "some_token",
        oauth_refresh_token: "some_refresh",
        oauth_expires_at: expires_at
      }

      assert OAuthClient.token_expired?(user) == true
    end

    test "returns false when token expires exactly at 5 minute boundary" do
      # Token expires in exactly 5 minutes (300 seconds)
      # Should return false because we check for "less than 5 minutes"
      expires_at = DateTime.add(DateTime.utc_now(), 301, :second)

      user = %ClientUser{
        id: "user_123",
        email: "test@example.com",
        oauth_token: "some_token",
        oauth_refresh_token: "some_refresh",
        oauth_expires_at: expires_at
      }

      assert OAuthClient.token_expired?(user) == false
    end

    test "handles far future expiration dates" do
      # Token expires in 1 year
      expires_at = DateTime.add(DateTime.utc_now(), 365 * 24 * 3600, :second)

      user = %ClientUser{
        id: "user_123",
        email: "test@example.com",
        oauth_token: "some_token",
        oauth_refresh_token: "some_refresh",
        oauth_expires_at: expires_at
      }

      assert OAuthClient.token_expired?(user) == false
    end
  end
end

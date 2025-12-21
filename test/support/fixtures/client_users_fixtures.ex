defmodule CodeMySpec.ClientUsersFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `CodeMySpec.ClientUsers` context.
  """

  @doc """
  Generate a client_user.
  """
  def client_user_fixture(attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        id: 123,
        email: "client#{System.unique_integer([:positive])}@example.com",
        oauth_expires_at: ~U[2025-11-27 22:18:00Z],
        oauth_refresh_token: "some oauth_refresh_token",
        oauth_token: "some oauth_token"
      })

    {:ok, client_user} = CodeMySpec.ClientUsers.create_client_user(attrs)
    client_user
  end

  @doc """
  Sets up an authenticated client user for testing RemoteClient functionality.
  Creates a ClientUser record with valid OAuth token and sets it as the current user.

  This enables `CodeMySpecCli.Auth.OAuthClient.get_token/0` to work properly in tests.

  When recording VCR cassettes, set the OAUTH_TOKEN environment variable.
  When replaying cassettes, any token will work since it's filtered out by ExVCR.

  Call `cleanup_authenticated_client_user/1` in test teardown to clean up the config file.
  """
  def authenticated_client_user_fixture(attrs \\ %{}) do
    # Create a far-future expiration date so token doesn't expire during tests
    expires_at = DateTime.add(DateTime.utc_now(), 86400, :second)  # 24 hours from now

    # Use token from environment (for recording) or placeholder (for replay)
    token = System.get_env("OAUTH_TOKEN") || "test_token_placeholder"

    default_attrs = %{
      id: System.unique_integer([:positive]),
      email: "authenticated_client#{System.unique_integer([:positive])}@example.com",
      oauth_expires_at: expires_at,
      oauth_refresh_token: "test_refresh_token",
      oauth_token: token
    }

    attrs = Enum.into(attrs, default_attrs)

    # Create the client user in the database
    {:ok, client_user} = CodeMySpec.ClientUsers.create_client_user(attrs)

    # Set this user as the current user in the CLI config
    :ok = CodeMySpecCli.Config.set_current_user_email(client_user.email)

    client_user
  end

  @doc """
  Cleans up the authenticated client user config.
  Call this in test teardown (on_exit callback).
  """
  def cleanup_authenticated_client_user(_client_user) do
    CodeMySpecCli.Config.clear_current_user_email()
  end
end

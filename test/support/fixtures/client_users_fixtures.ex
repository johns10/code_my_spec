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
end

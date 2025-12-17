defmodule CodeMySpecCli.Components.AuthStatus do
  @moduledoc """
  Component that displays authentication status.

  Shows whether the user is logged in or not.
  Gets its own auth status directly from OAuthClient.
  """

  import Ratatouille.View
  alias CodeMySpecCli.Auth.OAuthClient

  @doc """
  Renders the auth status indicator.
  """
  def render do
    authenticated = OAuthClient.authenticated?()

    label do
      text(content: "Auth: ")

      text(
        content: if(authenticated, do: "✓ Logged in", else: "✗ Not logged in"),
        color: if(authenticated, do: :green, else: :red)
      )
    end
  end
end
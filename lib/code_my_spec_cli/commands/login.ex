defmodule CodeMySpecCli.Commands.Login do
  @moduledoc """
  /login command - authenticate with OAuth2
  """

  use CodeMySpecCli.Commands.CommandBehaviour

  alias CodeMySpecCli.Auth.OAuthClient

  # Login doesn't need scope (it creates scope)
  def resolve_scope(_args), do: {:ok, nil}

  @doc """
  Login command - authenticate with OAuth2.

  Usage:
    /login                    # Use default server
    /login http://localhost:4000
  """
  def execute(_scope, args) do
    server_url =
      case args do
        [url | _] -> url
        [] -> nil
      end

    opts = if server_url, do: [server_url: server_url], else: []

    # Run OAuth flow in a background task so it doesn't block the TUI
    Task.start(fn ->
      OAuthClient.authenticate_with_ui(opts)
    end)

    # Return success message
    :ok
  end
end

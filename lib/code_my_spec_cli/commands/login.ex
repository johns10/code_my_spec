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

    # Run OAuth flow in a background task so it doesn't block the REPL
    Task.start(fn ->
      case OAuthClient.authenticate(opts) do
        {:ok, _token_data} ->
          # Success message is already printed by OAuthClient.authenticate
          :ok

        {:error, reason} ->
          Owl.IO.puts(["\n", Owl.Data.tag("Login failed: #{inspect(reason)}", [:red, :bright]), "\n"])
      end
    end)

    Owl.IO.puts(["\n", Owl.Data.tag("Login started in background...", :faint), "\n"])
    :ok
  end
end

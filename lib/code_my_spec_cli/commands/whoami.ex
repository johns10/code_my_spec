defmodule CodeMySpecCli.Commands.Whoami do
  @moduledoc """
  /whoami command - show authentication status
  """

  @behaviour CodeMySpecCli.Commands.CommandBehaviour

  alias CodeMySpecCli.Auth.OAuthClient

  @doc """
  Whoami command - show authentication status.
  """
  def execute(_args) do
    case OAuthClient.get_token() do
      {:ok, token} ->
        # Extract token info (first 10 chars for security)
        token_preview = String.slice(token, 0, 10) <> "..."

        Owl.IO.puts([
          "\n",
          Owl.Data.tag("✓ Authenticated", [:green, :bright]),
          "\n",
          Owl.Data.tag("Token: #{token_preview}", :faint),
          "\n"
        ])

        :ok

      {:error, :needs_authentication} ->
        Owl.IO.puts([
          "\n",
          Owl.Data.tag("✗ Not authenticated", [:red, :bright]),
          "\n",
          Owl.Data.tag("Run /login to authenticate", :faint),
          "\n"
        ])

        :ok
    end
  end
end

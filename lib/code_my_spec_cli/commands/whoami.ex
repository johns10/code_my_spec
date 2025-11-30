defmodule CodeMySpecCli.Commands.Whoami do
  @moduledoc """
  /whoami command - show authentication status
  """

  use CodeMySpecCli.Commands.CommandBehaviour

  @doc """
  Whoami command - show authentication status and user info from database.
  """
  def execute(scope, _args) do
    case scope do
      %{user: user} when not is_nil(user) ->
        # Show user info from scope/database
        token_preview =
          if user.oauth_token do
            String.slice(user.oauth_token, 0, 10) <> "..."
          else
            "None"
          end

        expires_info =
          case user.oauth_expires_at do
            nil -> "Unknown"
            expires_at ->
              case DateTime.compare(expires_at, DateTime.utc_now()) do
                :gt -> "Valid until #{Calendar.strftime(expires_at, "%Y-%m-%d %H:%M:%S")} UTC"
                _ -> "Expired"
              end
          end

        Owl.IO.puts([
          "\n",
          Owl.Data.tag("✓ Authenticated", [:green, :bright]),
          "\n",
          Owl.Data.tag("Email: #{user.email}", :cyan),
          "\n",
          Owl.Data.tag("User ID: #{user.id}", :faint),
          "\n",
          Owl.Data.tag("Token: #{token_preview}", :faint),
          "\n",
          Owl.Data.tag("Expires: #{expires_info}", :faint),
          "\n"
        ])

        :ok

      _ ->
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

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
            nil ->
              "Unknown"

            expires_at ->
              case DateTime.compare(expires_at, DateTime.utc_now()) do
                :gt -> "Valid until #{Calendar.strftime(expires_at, "%Y-%m-%d %H:%M:%S")} UTC"
                _ -> "Expired"
              end
          end

        {:ok, "#{user.email}\ntoken: #{token_preview}\n#{expires_info}"}

      _ ->
        :ok
    end
  end
end

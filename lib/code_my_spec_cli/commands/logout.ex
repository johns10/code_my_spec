defmodule CodeMySpecCli.Commands.Logout do
  @moduledoc """
  /logout command - clear stored credentials
  """

  @behaviour CodeMySpecCli.Commands.CommandBehaviour

  alias CodeMySpecCli.Auth.OAuthClient

  @doc """
  Logout command - clear stored credentials.
  """
  def execute(_args) do
    OAuthClient.logout()
    :ok
  end
end

defmodule CodeMySpecCli.Commands.Logout do
  @moduledoc """
  /logout command - clear stored credentials
  """

  use CodeMySpecCli.Commands.CommandBehaviour

  alias CodeMySpecCli.Auth.OAuthClient

  # Logout doesn't need scope
  def resolve_scope(_args), do: {:ok, nil}

  @doc """
  Logout command - clear stored credentials.
  """
  def execute(_scope, _args) do
    OAuthClient.logout()
    :ok
  end
end

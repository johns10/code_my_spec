defmodule CodeMySpecCli.Auth.Strategy do
  @moduledoc """
  OAuth2 strategy for CodeMySpec server.
  """
  use OAuth2.Strategy

  def authorize_url(client, params) do
    OAuth2.Strategy.AuthCode.authorize_url(client, params)
  end

  def get_token(client, params, headers) do
    client
    |> put_header("accept", "application/json")
    |> OAuth2.Strategy.AuthCode.get_token(params, headers)
  end
end

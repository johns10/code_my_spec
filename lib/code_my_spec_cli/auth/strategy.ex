defmodule CodeMySpecCli.Auth.Strategy do
  @moduledoc """
  OAuth2 strategy for CodeMySpec server.
  """
  use OAuth2.Strategy

  def authorize_url(client, params) do
    OAuth2.Strategy.AuthCode.authorize_url(client, params)
  end

  # Handle refresh token flow
  def get_token(client, params, headers) when is_list(params) do
    client = put_header(client, "accept", "application/json")

    case Keyword.get(params, :grant_type) do
      "refresh_token" ->
        OAuth2.Strategy.Refresh.get_token(client, params, headers)

      _ ->
        OAuth2.Strategy.AuthCode.get_token(client, params, headers)
    end
  end
end

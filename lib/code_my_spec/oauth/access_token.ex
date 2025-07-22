defmodule CodeMySpec.Oauth.AccessToken do
  use Ecto.Schema
  use ExOauth2Provider.AccessTokens.AccessToken, otp_app: :code_my_spec

  schema "oauth_access_tokens" do
    access_token_fields()

    timestamps()
  end
end

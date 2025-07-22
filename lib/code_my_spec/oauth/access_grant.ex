defmodule CodeMySpec.Oauth.AccessGrant do
  use Ecto.Schema
  use ExOauth2Provider.AccessGrants.AccessGrant, otp_app: :code_my_spec

  schema "oauth_access_grants" do
    access_grant_fields()

    timestamps()
  end
end

defmodule CodeMySpec.Oauth.Application do
  use Ecto.Schema
  use ExOauth2Provider.Applications.Application, otp_app: :code_my_spec

  schema "oauth_applications" do
    application_fields()

    timestamps()
  end
end

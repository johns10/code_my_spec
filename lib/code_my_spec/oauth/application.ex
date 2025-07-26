defmodule CodeMySpec.Oauth.Application do
  use Ecto.Schema
  use ExOauth2Provider.Applications.Application, otp_app: :code_my_spec
  import Ecto.Changeset

  schema "oauth_applications" do
    application_fields()

    timestamps()
  end

  def changeset(application, attrs) do
    application
    |> cast(attrs, [:name, :redirect_uri, :scopes, :uid, :secret])
    |> validate_required([:name, :uid, :secret])
    |> unique_constraint(:uid)
  end
end

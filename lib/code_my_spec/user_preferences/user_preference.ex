defmodule CodeMySpec.UserPreferences.UserPreference do
  use Ecto.Schema
  import Ecto.Changeset

  schema "user_preferences" do
    field :active_account_id, :integer
    field :active_project_id, :integer
    field :token, :string
    field :user_id, :id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(user_preference, attrs, user_scope) do
    user_preference
    |> cast(attrs, [:active_account_id, :active_project_id, :token])
    |> validate_required([])
    |> put_change(:user_id, user_scope.user.id)
  end
end

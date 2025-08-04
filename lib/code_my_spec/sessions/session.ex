defmodule CodeMySpec.Sessions.Session do
  use Ecto.Schema
  import Ecto.Changeset

  schema "sessions" do
    field :type, Ecto.Enum, values: [:design, :coding, :test]
    field :environment_id, :string
    field :status, :string
    field :state, :map
    field :project_id, :id
    field :account_id, :id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(session, attrs, user_scope) do
    session
    |> cast(attrs, [:type, :environment_id, :status, :state])
    |> validate_required([:type, :environment_id, :status])
    |> put_change(:account_id, user_scope.active_account.id)
    |> put_change(:project_id, user_scope.active_project.id)
  end
end

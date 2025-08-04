defmodule CodeMySpec.Rules.Rule do
  use Ecto.Schema
  import Ecto.Changeset

  schema "rules" do
    field :name, :string
    field :content, :string
    field :component_type, :string
    field :session_type, :string
    field :account_id, :id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(rule, attrs, user_scope) do
    rule
    |> cast(attrs, [:name, :content, :component_type, :session_type])
    |> validate_required([:name, :content, :component_type, :session_type])
    |> put_change(:account_id, user_scope.active_account.id)
  end
end

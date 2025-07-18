defmodule CodeMySpec.Invitations.Invitation do
  use Ecto.Schema
  import Ecto.Changeset

  alias CodeMySpec.Accounts.Account
  alias CodeMySpec.Users.User

  @type t :: %__MODULE__{
          id: integer(),
          token: String.t(),
          email: String.t(),
          role: account_role(),
          expires_at: DateTime.t(),
          accepted_at: DateTime.t() | nil,
          cancelled_at: DateTime.t() | nil,
          account_id: integer(),
          invited_by_id: integer(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  @type account_role :: :owner | :admin | :member

  schema "invitations" do
    field :token, :string
    field :email, :string
    field :role, Ecto.Enum, values: [:owner, :admin, :member]
    field :expires_at, :utc_datetime
    field :accepted_at, :utc_datetime
    field :cancelled_at, :utc_datetime

    belongs_to :account, Account
    belongs_to :invited_by, User

    timestamps()
  end

  def changeset(invitation, attrs) do
    invitation
    |> cast(attrs, [
      :email,
      :role,
      :account_id,
      :invited_by_id,
      :accepted_at,
      :cancelled_at,
      :expires_at
    ])
    |> unique_constraint([:email, :account_id, :accepted_at, :cancelled_at],
      name: :unique_account_email_when_nulls
    )
    |> validate_required([:email, :role, :account_id, :invited_by_id])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+\.[^\s]+$/)
    |> validate_inclusion(:role, [:owner, :admin, :member])
    |> assoc_constraint(:account)
    |> assoc_constraint(:invited_by)
    |> put_token()
    |> put_expires_at()
  end

  defp put_token(changeset) do
    case changeset do
      %Ecto.Changeset{valid?: true, data: %{id: nil}} ->
        put_change(changeset, :token, generate_token())

      _ ->
        changeset
    end
  end

  defp put_expires_at(changeset) do
    case changeset do
      %Ecto.Changeset{valid?: true, data: %{id: nil}} ->
        case get_change(changeset, :expires_at) do
          nil ->
            expires_at = DateTime.utc_now() |> DateTime.add(7, :day) |> DateTime.truncate(:second)
            put_change(changeset, :expires_at, expires_at)

          _ ->
            changeset
        end

      _ ->
        changeset
    end
  end

  defp generate_token do
    Phoenix.Token.sign(CodeMySpecWeb.Endpoint, "invitation_token", System.unique_integer())
  end
end

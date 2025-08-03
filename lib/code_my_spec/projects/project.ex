defmodule CodeMySpec.Projects.Project do
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: integer() | nil,
          name: String.t(),
          description: String.t() | nil,
          code_repo: String.t() | nil,
          docs_repo: String.t() | nil,
          setup_error: String.t() | nil,
          account_id: integer() | nil,
          status:
            :created
            | :setup_queued
            | :initializing
            | :deps_installing
            | :setting_up_auth
            | :compiling
            | :testing
            | :committing
            | :ready
            | :failed,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "projects" do
    field :name, :string
    field :description, :string
    field :code_repo, :string
    field :docs_repo, :string
    field :setup_error, :string
    field :account_id, :id

    field :status, Ecto.Enum,
      values: [
        :created,
        :setup_queued,
        :initializing,
        :deps_installing,
        :setting_up_auth,
        :compiling,
        :testing,
        :committing,
        :ready,
        :failed
      ],
      default: :created

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(project, attrs, user_scope) do
    project
    |> cast(attrs, [:name, :description, :code_repo, :docs_repo, :status, :setup_error])
    |> validate_required([:name])
    |> put_change(:account_id, user_scope.active_account_id)
  end
end

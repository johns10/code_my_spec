defmodule CodeMySpec.Stories.Story do
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: integer() | nil,
          title: String.t(),
          description: String.t(),
          acceptance_criteria: [String.t()],
          priority: integer(),
          status: :in_progress | :completed | :dirty,
          locked_at: DateTime.t() | nil,
          lock_expires_at: DateTime.t() | nil,
          locked_by: integer() | nil,
          project_id: integer() | nil,
          account_id: integer() | nil,
          first_version: PaperTrail.Version.t() | nil,
          current_version: PaperTrail.Version.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "stories" do
    field :title, :string
    field :description, :string
    field :acceptance_criteria, {:array, :string}
    field :priority, :integer
    field :status, Ecto.Enum, values: [:in_progress, :completed, :dirty]
    field :locked_at, :utc_datetime
    field :lock_expires_at, :utc_datetime
    field :locked_by, :id
    field :project_id, :id
    field :account_id, :id

    belongs_to :first_version, PaperTrail.Version
    belongs_to :current_version, PaperTrail.Version, on_replace: :update

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(story, attrs, user_scope) do
    story
    |> cast(attrs, [
      :title,
      :description,
      :acceptance_criteria,
      :priority,
      :status,
      :locked_at,
      :lock_expires_at,
      :locked_by,
      :project_id
    ])
    |> validate_required([
      :title,
      :description,
      :acceptance_criteria,
      :priority,
      :status
    ])
    |> put_change(:account_id, user_scope.active_account.id)
  end

  @doc false
  def lock_changeset(story, attrs) do
    story
    |> cast(attrs, [
      :locked_at,
      :lock_expires_at,
      :locked_by
    ])
  end
end

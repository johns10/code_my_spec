defmodule CodeMySpec.Problems.Problem do
  @moduledoc """
  Schema representing a normalized problem from any analysis or testing tool.
  Supports both ephemeral (in-memory) usage during sessions and persistent
  storage for project-level fitness tracking.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias CodeMySpec.Projects.Project

  @type t :: %__MODULE__{
          id: integer() | nil,
          severity: :error | :warning | :info,
          source_type: :static_analysis | :test | :runtime,
          source: String.t(),
          file_path: String.t(),
          line: integer() | nil,
          message: String.t(),
          category: String.t(),
          rule: String.t() | nil,
          metadata: map() | nil,
          project_id: Ecto.UUID.t() | nil,
          project: Project.t() | Ecto.Association.NotLoaded.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "problems" do
    field :severity, Ecto.Enum, values: [:error, :warning, :info]

    field :source_type, Ecto.Enum,
      values: [:static_analysis, :test, :runtime],
      default: :static_analysis

    field :source, :string
    field :file_path, :string
    field :line, :integer
    field :message, :string
    field :category, :string
    field :rule, :string
    field :metadata, :map, default: %{}

    belongs_to :project, Project, type: :binary_id

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating or updating a Problem.
  """
  def changeset(problem, attrs) do
    problem
    |> cast(attrs, [
      :severity,
      :source_type,
      :source,
      :file_path,
      :line,
      :message,
      :category,
      :rule,
      :metadata,
      :project_id
    ])
    |> validate_required([
      :severity,
      :source_type,
      :source,
      :file_path,
      :message,
      :category,
      :project_id
    ])
    |> validate_inclusion(:severity, [:error, :warning, :info])
    |> validate_inclusion(:source_type, [:static_analysis, :test, :runtime])
    |> validate_length(:source, min: 1, max: 255)
    |> validate_length(:file_path, min: 1)
    |> validate_length(:category, min: 1, max: 255)
    |> validate_number(:line, greater_than: 0)
    |> foreign_key_constraint(:project_id)
  end
end

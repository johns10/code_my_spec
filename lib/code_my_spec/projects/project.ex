defmodule CodeMySpec.Projects.Project do
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: integer() | nil,
          name: String.t(),
          description: String.t() | nil,
          module_name: String.t() | nil,
          code_repo: String.t() | nil,
          docs_repo: String.t() | nil,
          content_repo: String.t() | nil,
          client_api_url: String.t() | nil,
          deploy_key: String.t() | nil,
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
    field :module_name, :string
    field :code_repo, :string
    field :docs_repo, :string
    field :content_repo, :string
    field :client_api_url, :string
    field :deploy_key, :string
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
    |> cast(attrs, [
      :name,
      :description,
      :module_name,
      :code_repo,
      :docs_repo,
      :content_repo,
      :client_api_url,
      :deploy_key,
      :status,
      :setup_error
    ])
    |> validate_required([:name])
    |> validate_format(:module_name, ~r/^[A-Z][a-zA-Z0-9]*$/,
      message: "must be a valid Elixir module name"
    )
    |> maybe_validate_url(:client_api_url)
    |> put_change(:account_id, user_scope.active_account_id)
  end

  defp maybe_validate_url(changeset, field) do
    case get_field(changeset, field) do
      nil -> changeset
      "" -> changeset
      _url -> validate_format(changeset, field, ~r/^https?:\/\/.+/, message: "must be a valid URL")
    end
  end
end

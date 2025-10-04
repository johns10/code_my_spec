defmodule CodeMySpec.Content.Tag do
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: integer() | nil,
          name: String.t(),
          slug: String.t(),
          project_id: integer(),
          account_id: integer(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "tags" do
    field :name, :string
    field :slug, :string

    belongs_to :project, CodeMySpec.Projects.Project
    belongs_to :account, CodeMySpec.Accounts.Account

    many_to_many :content, CodeMySpec.Content.Content,
      join_through: "content_tags",
      on_replace: :delete

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(tag, attrs) do
    tag
    |> cast(attrs, [:name, :project_id, :account_id])
    |> validate_required([:name, :project_id, :account_id])
    |> validate_length(:name, min: 1, max: 50)
    |> normalize_and_slugify()
    |> unique_constraint([:slug, :project_id, :account_id],
      name: :tags_slug_project_id_account_id_index
    )
  end

  defp normalize_and_slugify(changeset) do
    case get_change(changeset, :name) do
      nil ->
        changeset

      name ->
        normalized_name = String.downcase(name)
        slug = slugify(normalized_name)

        changeset
        |> put_change(:name, normalized_name)
        |> put_change(:slug, slug)
    end
  end

  defp slugify(string) do
    string
    |> String.downcase()
    |> String.replace(~r/[^\w\s-]/u, "")
    |> String.replace(~r/\s+/, "-")
    |> String.replace(~r/-+/, "-")
    |> String.trim("-")
  end
end
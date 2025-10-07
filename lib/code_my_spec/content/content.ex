defmodule CodeMySpec.Content.Content do
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: integer() | nil,
          slug: String.t(),
          title: String.t() | nil,
          content_type: :blog | :page | :landing,
          raw_content: String.t(),
          processed_content: String.t() | nil,
          protected: boolean(),
          project_id: integer(),
          account_id: integer(),
          publish_at: DateTime.t() | nil,
          expires_at: DateTime.t() | nil,
          parse_status: :pending | :success | :error,
          parse_errors: map() | nil,
          meta_title: String.t() | nil,
          meta_description: String.t() | nil,
          og_image: String.t() | nil,
          og_title: String.t() | nil,
          og_description: String.t() | nil,
          metadata: map(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "contents" do
    field :slug, :string
    field :title, :string
    field :content_type, Ecto.Enum, values: [:blog, :page, :landing]
    field :raw_content, :string
    field :processed_content, :string
    field :protected, :boolean, default: false
    field :publish_at, :utc_datetime
    field :expires_at, :utc_datetime

    field :parse_status, Ecto.Enum,
      values: [:pending, :success, :error],
      default: :pending

    field :parse_errors, :map
    field :meta_title, :string
    field :meta_description, :string
    field :og_image, :string
    field :og_title, :string
    field :og_description, :string
    field :metadata, :map, default: %{}

    belongs_to :project, CodeMySpec.Projects.Project
    belongs_to :account, CodeMySpec.Accounts.Account

    many_to_many :tags, CodeMySpec.Content.Tag,
      join_through: "content_tags",
      on_replace: :delete

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(content, attrs) do
    content
    |> cast(attrs, [
      :slug,
      :title,
      :content_type,
      :raw_content,
      :processed_content,
      :protected,
      :project_id,
      :account_id,
      :publish_at,
      :expires_at,
      :parse_status,
      :parse_errors,
      :meta_title,
      :meta_description,
      :og_image,
      :og_title,
      :og_description,
      :metadata
    ])
    |> validate_required([:slug, :content_type, :raw_content, :project_id, :account_id])
    |> validate_length(:meta_title, max: 60)
    |> validate_length(:meta_description, max: 160)
    |> validate_inclusion(:content_type, [:blog, :page, :landing])
    |> validate_expiration_after_publish()
    |> validate_parse_errors_when_error_status()
    |> unique_constraint([:slug, :content_type, :project_id],
      name: :contents_slug_content_type_project_id_index
    )
  end

  defp validate_expiration_after_publish(changeset) do
    publish_at = get_field(changeset, :publish_at)
    expires_at = get_field(changeset, :expires_at)

    case {publish_at, expires_at} do
      {%DateTime{} = pub, %DateTime{} = exp} ->
        if DateTime.compare(exp, pub) == :gt do
          changeset
        else
          add_error(changeset, :expires_at, "must be after publish_at")
        end

      _ ->
        changeset
    end
  end

  defp validate_parse_errors_when_error_status(changeset) do
    parse_status = get_field(changeset, :parse_status)
    parse_errors = get_field(changeset, :parse_errors)

    if parse_status == :error and (is_nil(parse_errors) or parse_errors == %{}) do
      add_error(changeset, :parse_errors, "must be present when parse_status is error")
    else
      changeset
    end
  end
end

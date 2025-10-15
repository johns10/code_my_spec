defmodule CodeMySpec.Repo.Migrations.UpdateContentsSchemaRemoveMultiTenantFields do
  use Ecto.Migration

  def up do
    # Drop old unique constraint that included project_id
    drop_if_exists unique_index(:contents, [:slug, :content_type, :project_id],
                     name: :contents_slug_content_type_project_id_index
                   )

    # Rename processed_content to content
    rename table(:contents), :processed_content, to: :content

    # Drop columns we no longer need
    alter table(:contents) do
      remove :account_id
      remove :project_id
      remove :parse_status
      remove :parse_errors
      remove :raw_content
    end

    # Add new unique constraint without project_id
    create unique_index(:contents, [:slug, :content_type],
             name: :contents_slug_content_type_index
           )

    # Add indexes for query performance
    create_if_not_exists index(:contents, [:content_type])
    create_if_not_exists index(:contents, [:protected])
    create_if_not_exists index(:contents, [:publish_at, :expires_at])
  end

  def down do
    # Drop new indexes
    drop_if_exists index(:contents, [:publish_at, :expires_at])
    drop_if_exists index(:contents, [:protected])
    drop_if_exists index(:contents, [:content_type])

    # Drop new unique constraint
    drop_if_exists unique_index(:contents, [:slug, :content_type],
                     name: :contents_slug_content_type_index
                   )

    # Add back removed columns
    alter table(:contents) do
      add :raw_content, :text
      add :parse_errors, :map
      add :parse_status, :string, default: "pending"
      add :project_id, references(:projects, on_delete: :delete_all)
      add :account_id, references(:accounts, on_delete: :delete_all)
    end

    # Rename content back to processed_content
    rename table(:contents), :content, to: :processed_content

    # Restore old unique constraint
    create unique_index(:contents, [:slug, :content_type, :project_id],
             name: :contents_slug_content_type_project_id_index
           )
  end
end

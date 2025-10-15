defmodule CodeMySpec.Repo.Migrations.UpdateTagsSchemaRemoveMultiTenantFields do
  use Ecto.Migration

  def up do
    # Drop old unique constraint that included project_id and account_id
    drop_if_exists unique_index(:tags, [:slug, :project_id, :account_id],
                     name: :tags_slug_project_id_account_id_index
                   )

    # Drop foreign key constraints
    drop constraint(:tags, :tags_project_id_fkey)
    drop constraint(:tags, :tags_account_id_fkey)

    # Drop columns we no longer need
    alter table(:tags) do
      remove :account_id
      remove :project_id
    end

    # Add new unique constraint on slug only (global uniqueness)
    create unique_index(:tags, [:slug], name: :tags_slug_index)
  end

  def down do
    # Drop new unique constraint
    drop_if_exists unique_index(:tags, [:slug], name: :tags_slug_index)

    # Add back removed columns
    alter table(:tags) do
      add :project_id, references(:projects, on_delete: :delete_all)
      add :account_id, references(:accounts, on_delete: :delete_all)
    end

    # Restore old unique constraint
    create unique_index(:tags, [:slug, :project_id, :account_id],
             name: :tags_slug_project_id_account_id_index
           )
  end
end
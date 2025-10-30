defmodule CodeMySpec.Repo.Migrations.RenameContentFieldsForClarity do
  use Ecto.Migration

  def up do
    # Rename contents.content to contents.processed_content for clarity
    # This makes it clear that the field contains processed HTML, not raw markdown
    rename table(:contents), :content, to: :processed_content

    # Rename content_admin.content to content_admin.raw_content for clarity
    # This distinguishes raw content from processed_content
    rename table(:content_admin), :content, to: :raw_content
  end

  def down do
    # Revert contents.processed_content to contents.content
    rename table(:contents), :processed_content, to: :content

    # Revert content_admin.raw_content to content_admin.content
    rename table(:content_admin), :raw_content, to: :content
  end
end

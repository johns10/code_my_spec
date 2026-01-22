defmodule CodeMySpec.Repo.Migrations.MigrateAcceptanceCriteriaToCriterionRecords do
  use Ecto.Migration

  def up do
    # Get all stories that have acceptance_criteria but no criteria records
    # We use a subquery to avoid migrating stories that already have criteria
    execute("""
    INSERT INTO criteria (description, verified, story_id, project_id, account_id, inserted_at, updated_at)
    SELECT
      unnest(s.acceptance_criteria) as description,
      false as verified,
      s.id as story_id,
      s.project_id,
      s.account_id,
      NOW() as inserted_at,
      NOW() as updated_at
    FROM stories s
    WHERE s.acceptance_criteria IS NOT NULL
      AND array_length(s.acceptance_criteria, 1) > 0
      AND NOT EXISTS (
        SELECT 1 FROM criteria c WHERE c.story_id = s.id
      )
    """)
  end

  def down do
    # Migrate criteria back to acceptance_criteria arrays
    # First, update stories with their criteria descriptions
    execute("""
    UPDATE stories s
    SET acceptance_criteria = (
      SELECT array_agg(c.description ORDER BY c.id)
      FROM criteria c
      WHERE c.story_id = s.id
    )
    WHERE EXISTS (
      SELECT 1 FROM criteria c WHERE c.story_id = s.id
    )
    """)

    # Then delete all criteria that were migrated (those without verified_at,
    # since manually verified ones should be preserved)
    execute("""
    DELETE FROM criteria
    WHERE verified = false
      AND verified_at IS NULL
    """)
  end
end

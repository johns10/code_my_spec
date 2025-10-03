defmodule CodeMySpec.Documents.SchemaComponentDesign do
  @moduledoc """
  Embedded schema representing a Schema Component Design specification.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @behaviour CodeMySpec.Documents.DocumentBehaviour

  @primary_key false
  embedded_schema do
    field :purpose, :string
    field :fields, :string
    field :associations, :string
    field :validation_rules, :string
    field :database_constraints, :string

    field :other_sections, :map
  end

  def changeset(schema_design, attrs, _scope \\ nil) do
    schema_design
    |> cast(attrs, [
      :purpose,
      :fields,
      :associations,
      :validation_rules,
      :database_constraints,
      :other_sections
    ])
    |> validate_required([:purpose, :fields])
    |> validate_length(:purpose, min: 1, max: 5000)
    |> validate_length(:fields, min: 1, max: 10000)
    |> validate_length(:associations, max: 5000)
    |> validate_length(:validation_rules, max: 5000)
    |> validate_length(:database_constraints, max: 5000)
  end

  def required_fields(), do: [:purpose, :fields]

  def overview do
    """
    Schema components represent Ecto schema entities that define data structures,
    relationships, and validation rules for persistence in the database. Each schema
    documents its fields, associations, validations, and database constraints.
    """
  end

  def field_descriptions do
    %{
      purpose: schema_purpose(),
      fields: schema_fields(),
      associations: schema_associations(),
      validation_rules: schema_validation_rules(),
      database_constraints: schema_database_constraints()
    }
  end

  defp schema_purpose do
    """
    Format:
    - 1-3 sentences describing what the schema represents
    - Use H2 heading

    Content:
    - High-level description of the data entity and its role in the domain
    - Focus on the business concept, not just technical structure

    Examples:
    - ## Purpose
      Represents user account entities with authentication credentials and profile information.
    """
  end

  defp schema_fields do
    """
    Format:
    - Use H2 heading
    - Table format with columns: Field, Type, Required, Description, Constraints

    Content:
    - List all schema fields with their Ecto types
    - Mark required fields clearly
    - Include constraints (length, format, enum values)
    - Document default values if applicable

    Examples:
    - ## Field Documentation

      | Field | Type | Required | Description | Constraints |
      |-------|------|----------|-------------|-------------|
      | email | string | Yes | User email address | Must be valid email format, unique |
      | age | integer | No | User age | Must be >= 18 |
    """
  end

  defp schema_associations do
    """
    Format:
    - Use H2 heading
    - Unordered list or sections for each type

    Content:
    - belongs_to relationships
    - has_many relationships
    - has_one relationships
    - many_to_many relationships
    - Include foreign key names and on_delete behavior

    Examples:
    - ## Associations
      ### belongs_to
      - **project** - References projects.id, cascade delete

      ### has_many
      - **posts** - User's blog posts through posts.user_id
    """
  end

  defp schema_validation_rules do
    """
    Format:
    - Use H2 heading
    - Organized by validation type or field grouping

    Content:
    - Required field validations
    - Length validations
    - Format validations (regex patterns)
    - Custom validations
    - Unique constraints
    - Foreign key validations

    Examples:
    - ## Validation Rules
      ### Email Validation
      - Required
      - Format: `/^[^@\\s]+@[^@\\s]+$/`
      - Unique constraint

      ### Password Validation
      - Required on create
      - Minimum length: 8 characters
    """
  end

  defp schema_database_constraints do
    """
    Format:
    - Use H2 heading
    - Subsections for Indexes, Unique Constraints, Foreign Keys

    Content:
    - Document all database-level constraints
    - Specify index types and purposes
    - List unique constraints (single and composite)
    - Detail foreign key relationships and cascade behavior

    Examples:
    - ## Database Constraints
      ### Indexes
      - Primary key on id
      - Index on email for fast lookup
      - Composite index on (project_id, slug) for scoped queries

      ### Unique Constraints
      - Unique on email (global)
      - Unique on (slug, project_id) (scoped)

      ### Foreign Keys
      - project_id references projects.id, on_delete: cascade
    """
  end
end

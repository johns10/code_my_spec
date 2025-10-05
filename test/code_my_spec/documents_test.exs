defmodule CodeMySpec.DocumentsTest do
  use ExUnit.Case, async: true
  doctest CodeMySpec.Documents

  alias CodeMySpec.Documents
  alias CodeMySpec.Documents.ContextDesign

  describe "create_context_document/2" do
    test "creates a valid context design document from markdown" do
      markdown = """
      # Test Context

      ## Purpose
      This is a test context for managing test data.

      ## Entity Ownership
      Test entities and their relationships.

      ## Access Patterns
      Uses test scopes for isolation.

      ## Public API
      Standard CRUD operations for test entities.

      ## State Management Strategy
      Test data stored in memory for fast access.

      ## Components

      ### Test.Schema
      | field | value  |
      |-------|--------|
      | type  | schema |

      Database schema for test entities

      ### Test.Repository
      | field | value      |
      |-------|------------|
      | type  | repository |

      Repository for test data operations

      ## Dependencies
      - CodeMySpec.Users.Scope
      - CodeMySpec.Projects

      ## Execution Flow
      1. Validate test scope
      2. Execute test operations
      3. Return test results
      """

      {:ok, document} = Documents.create_context_document(markdown)

      assert %ContextDesign{} = document
      assert document.purpose == "This is a test context for managing test data."
      assert document.entity_ownership == "Test entities and their relationships."
      assert document.access_patterns == "Uses test scopes for isolation."
      assert document.public_api == "Standard CRUD operations for test entities."
      assert document.state_management_strategy == "Test data stored in memory for fast access."

      assert document.execution_flow ==
               "1. Validate test scope\n2. Execute test operations\n3. Return test results"

      # Test components
      assert length(document.components) == 2
      [test_schema, test_repo] = document.components

      assert test_schema.module_name == "Test.Schema"
      assert test_schema.description == "Database schema for test entities"

      assert test_repo.module_name == "Test.Repository"
      assert test_repo.description == "Repository for test data operations"

      # Test dependencies
      assert length(document.dependencies) == 2
      assert "CodeMySpec.Users.Scope" in document.dependencies
      assert "CodeMySpec.Projects" in document.dependencies
    end

    test "returns error for missing required sections" do
      markdown = """
      # Bad Context

      ## Components

      ### BadComponent
      Description here
      """

      {:error, changeset} = Documents.create_context_document(markdown)

      assert %Ecto.Changeset{valid?: false} = changeset
      assert changeset.errors != []
    end

    test "returns error for malformed markdown" do
      {:error, changeset} = Documents.create_context_document("invalid")

      assert %Ecto.Changeset{valid?: false} = changeset
    end
  end

  describe "create_dynamic_document/3" do
    test "creates a valid schema document from markdown" do
      markdown = """
      # User Schema

      ## Purpose
      Represents user account entities with authentication credentials.

      ## Fields
      | Field | Type | Required | Description |
      |-------|------|----------|-------------|
      | email | string | Yes | User email address |
      | name | string | Yes | User full name |
      """

      {:ok, document} = Documents.create_dynamic_document(markdown, ["purpose", "fields"], type: :schema)

      assert document.type == :schema
      assert document.sections["purpose"] == "Represents user account entities with authentication credentials."
      assert String.contains?(document.sections["fields"], "email")
      assert String.contains?(document.sections["fields"], "string")
    end

    test "creates a document with only required sections" do
      markdown = """
      # Component

      ## Purpose
      Does something useful.

      ## Public API
      Functions for doing things.

      ## Execution Flow
      Step by step process.
      """

      {:ok, document} = Documents.create_dynamic_document(
        markdown,
        ["purpose", "public api", "execution flow"],
        type: :genserver
      )

      assert document.type == :genserver
      assert document.sections["purpose"] == "Does something useful."
      assert document.sections["public api"] == "Functions for doing things."
      assert document.sections["execution flow"] == "Step by step process."
    end

    test "returns error for missing required sections" do
      markdown = """
      # Incomplete

      ## Purpose
      Only has purpose.
      """

      {:error, error} = Documents.create_dynamic_document(markdown, ["purpose", "fields"])

      assert error == "Missing required sections: fields"
    end

    test "captures optional sections" do
      markdown = """
      # Schema

      ## Purpose
      Test schema.

      ## Fields
      Field list.

      ## Associations
      Has many things.

      ## Custom Section
      Extra content.
      """

      {:ok, document} = Documents.create_dynamic_document(markdown, ["purpose", "fields"])

      assert document.sections["purpose"] == "Test schema."
      assert document.sections["fields"] == "Field list."
      assert document.sections["associations"] == "Has many things."
      assert document.sections["custom section"] == "Extra content."
    end

    test "works without type option" do
      markdown = """
      # Document

      ## Purpose
      Just testing.
      """

      {:ok, document} = Documents.create_dynamic_document(markdown, ["purpose"])

      refute Map.has_key?(document, :type)
      assert document.sections["purpose"] == "Just testing."
    end
  end
end

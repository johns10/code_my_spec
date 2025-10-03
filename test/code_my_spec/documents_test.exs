defmodule CodeMySpec.DocumentsTest do
  use ExUnit.Case, async: true
  doctest CodeMySpec.Documents

  alias CodeMySpec.Documents
  alias CodeMySpec.Documents.ContextDesign

  describe "create_document/3" do
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
      Database schema for test entities

      ### Test.Repository
      Repository for test data operations

      ## Dependencies
      - CodeMySpec.Users.Scope
      - CodeMySpec.Projects

      ## Execution Flow
      1. Validate test scope
      2. Execute test operations
      3. Return test results
      """

      {:ok, document} = Documents.create_component_document(markdown, :context)

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

      # Test other sections
      assert is_map(document.other_sections)
    end

    test "returns error for invalid markdown" do
      markdown = """
      # Bad Context

      ## Components

      ### BadComponent
      """

      {:error, changeset} = Documents.create_component_document(markdown, :context)

      assert %Ecto.Changeset{valid?: false} = changeset
      assert changeset.errors != []
    end

    test "supports module name as type" do
      markdown = """
      # Test Context

      ## Purpose
      Test purpose.

      ## Components

      ### Test.Component
      A test component

      ## Dependencies
      - Test.Dependency
      """

      {:ok, document} = Documents.create_component_document(markdown, :context)

      assert %ContextDesign{} = document
      assert document.purpose == "Test purpose."
    end

    test "returns error for malformed markdown" do
      {:error, changeset} = Documents.create_component_document("invalid", :context)

      assert %Ecto.Changeset{valid?: false} = changeset
    end

    test "parses component type from table in description" do
      markdown = """
      # Test Context

      ## Purpose
      Test purpose.

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
      - Test.Dependency
      """

      {:ok, document} = Documents.create_component_document(markdown, :context)

      assert %ContextDesign{} = document
      assert length(document.components) == 2
      [test_schema, test_repo] = document.components

      assert test_schema.module_name == "Test.Schema"
      assert test_schema.table == %{"field" => "type", "value" => "schema"}
      assert test_schema.description == "Database schema for test entities"

      assert test_repo.module_name == "Test.Repository"
      assert test_repo.table == %{"field" => "type", "value" => "repository"}
      assert test_repo.description == "Repository for test data operations"
    end
  end
end

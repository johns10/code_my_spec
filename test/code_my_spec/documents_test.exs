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

  describe "create_dynamic_document/2" do
    test "creates a valid schema document from markdown" do
      markdown = """
      # User Schema

      ## Purpose
      Represents user account entities with authentication credentials.

      ## Fields
      | Field | Type | Required | Description | Constraints |
      |-------|------|----------|-------------|-------------|
      | email | string | Yes | User email address | Unique |
      | name | string | Yes | User full name | Min: 1, Max: 255 |

      ## Test Assertions
      - validates email format
      - validates name presence
      """

      {:ok, document} = Documents.create_dynamic_document(markdown, :schema)

      assert document.type == :schema
      assert document.sections["purpose"] =~ "Represents user account entities"
      # Fields section is parsed by FieldParser into list of Field structs
      assert is_list(document.sections["fields"])
    end

    test "returns error for missing required sections" do
      markdown = """
      # Incomplete

      ## Purpose
      Only has purpose.
      """

      {:error, error} = Documents.create_dynamic_document(markdown, :schema)

      assert error =~ "Missing required sections"
      assert error =~ "fields"
    end

    test "allows optional sections" do
      markdown = """
      # User Schema

      ## Purpose
      Test schema.

      ## Fields
      | Field | Type | Required |
      |-------|------|----------|
      | name | string | Yes |

      ## Test Assertions
      - test something

      ## Associations
      Has many things.
      """

      {:ok, document} = Documents.create_dynamic_document(markdown, :schema)

      assert document.sections["purpose"] == "Test schema."
      assert document.sections["associations"] == "Has many things."
    end

    test "allows additional sections when allowed_additional_sections is '*'" do
      markdown = """
      # Context

      ## Purpose
      Does context things.

      ## Entity Ownership
      Owns entities.

      ## Access Patterns
      Scoped access.

      ## Public API
      API functions.

      ## State Management Strategy
      Uses database.

      ## Execution Flow
      Process flow.

      ## Dependencies
      - Some.Module

      ## Components
      Component list.

      ## Test Strategies
      Testing approach.

      ## Test Assertions
      - test assertions

      ## Custom Section
      Extra content allowed for contexts.
      """

      {:ok, document} = Documents.create_dynamic_document(markdown, :context)

      assert document.sections["custom section"] == "Extra content allowed for contexts."
    end

    test "rejects additional sections when allowed_additional_sections is []" do
      markdown = """
      # MyModule.Spec

      ## Delegates
      - func/1: Other.func/1

      ## Functions

      ### my_func/1
      Does something.

      ## Dependencies
      - Other.Module

      ## Custom Section
      This should not be allowed for specs!
      """

      {:error, error} = Documents.create_dynamic_document(markdown, :spec)

      assert error =~ "Disallowed sections found"
      assert error =~ "custom section"
    end

    test "allows multiple disallowed sections in error message" do
      markdown = """
      # MyModule.Spec

      ## Delegates
      - func/1: Other.func/1

      ## Functions

      ### my_func/1
      Does something.

      ## Dependencies
      - Other.Module

      ## Custom One
      Not allowed.

      ## Custom Two
      Also not allowed.
      """

      {:error, error} = Documents.create_dynamic_document(markdown, :spec)

      assert error =~ "Disallowed sections found"
      assert error =~ "custom one"
      assert error =~ "custom two"
    end

    test "allows optional sections for spec documents" do
      markdown = """
      # MyModule.Spec

      ## Delegates
      - func/1: Other.func/1

      ## Functions

      ### my_func/1
      Does something.

      ## Dependencies
      - Other.Module

      ## Fields
      | Field | Type | Required |
      |-------|------|----------|
      | name | string | Yes |
      """

      {:ok, document} = Documents.create_dynamic_document(markdown, :spec)

      assert document.type == :spec
      assert is_list(document.sections["fields"])
    end
  end
end

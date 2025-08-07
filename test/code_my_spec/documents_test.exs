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

      ## Scope Integration
      Uses test scopes for isolation.

      ## Public API
      Standard CRUD operations for test entities.

      ## State Management Strategy
      Test data stored in memory for fast access.

      ## Components
      - TestSchema:
          module_name: Test.Schema
          description: Database schema for test entities
      - TestRepo:
          module_name: Test.Repository
          description: Repository for test data operations

      ## Dependencies
      - TestScope:
          module_name: Test.Scope
          description: Scoping mechanism for tests
      - Ecto:
          module_name: Ecto
          description: Database abstraction layer

      ## Execution Flow
      1. Validate test scope
      2. Execute test operations
      3. Return test results
      """

      {:ok, document} = Documents.create_document(markdown, :context_design)

      assert %ContextDesign{} = document
      assert document.purpose == "This is a test context for managing test data."
      assert document.entity_ownership == "Test entities and their relationships."
      assert document.scope_integration == "Uses test scopes for isolation."
      assert document.public_api == "Standard CRUD operations for test entities."
      assert document.state_management_strategy == "Test data stored in memory for fast access."
      assert document.execution_flow == "1. Validate test scope\n2. Execute test operations\n3. Return test results"

      # Test components
      assert length(document.components) == 2
      [test_schema, test_repo] = document.components

      assert test_schema.module_name == "Test.Schema"
      assert test_schema.description == "Database schema for test entities"

      assert test_repo.module_name == "Test.Repository"
      assert test_repo.description == "Repository for test data operations"

      # Test dependencies
      assert length(document.dependencies) == 2
      [test_scope, ecto] = document.dependencies

      assert test_scope.module_name == "Test.Scope"
      assert test_scope.description == "Scoping mechanism for tests"

      assert ecto.module_name == "Ecto"
      assert ecto.description == "Database abstraction layer"

      # Test other sections
      assert is_map(document.other_sections)
    end

    test "returns error for invalid markdown" do
      markdown = """
      # Bad Context

      ## Components
      - BadComponent: {}
      """

      {:error, changeset} = Documents.create_document(markdown, :context_design)

      assert %Ecto.Changeset{valid?: false} = changeset
      assert changeset.errors != []
    end

    test "supports module name as type" do
      markdown = """
      # Test Context

      ## Purpose
      Test purpose.

      ## Components
      - TestComponent:
          module_name: Test.Component
          description: A test component

      ## Dependencies
      - TestDep:
          module_name: Test.Dependency
          description: A test dependency
      """

      {:ok, document} = Documents.create_document(markdown, ContextDesign)

      assert %ContextDesign{} = document
      assert document.purpose == "Test purpose."
    end

    test "returns error for unknown document type" do
      {:error, changeset} = Documents.create_document("# Test", :unknown_type)

      assert %Ecto.Changeset{valid?: false} = changeset
      assert {:document, {"Unknown document module: :unknown_type", []}} in changeset.errors
    end

    test "returns error for malformed markdown" do
      {:error, changeset} = Documents.create_document("invalid", :context_design)

      assert %Ecto.Changeset{valid?: false} = changeset
    end
  end

  describe "supported_types/0" do
    test "returns list of supported document types" do
      types = Documents.supported_types()
      assert :context_design in types
    end
  end

  describe "get_document_module/1" do
    test "returns context design module for atom" do
      {:ok, module} = Documents.get_document_module(:context_design)
      assert module == ContextDesign
    end

    test "returns module if already a valid module" do
      {:ok, module} = Documents.get_document_module(ContextDesign)
      assert module == ContextDesign
    end

    test "returns error for unknown type" do
      {:error, reason} = Documents.get_document_module(:unknown)
      assert reason =~ "Unknown document module"
    end
  end
end
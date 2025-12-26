defmodule CodeMySpec.DocumentsTest do
  use ExUnit.Case, async: true
  doctest CodeMySpec.Documents

  alias CodeMySpec.Documents

  describe "create_dynamic_document/2" do
    test "creates a valid schema document from markdown" do
      markdown = """
      # User Schema
      Represents user account entities with authentication credentials.

      ## Fields
      | Field | Type | Required | Description | Constraints |
      |-------|------|----------|-------------|-------------|
      | email | string | Yes | User email address | Unique |
      | name | string | Yes | User full name | Min: 1, Max: 255 |

      ## Dependencies
      - CodeMySpec.MyModule
      """

      {:ok, document} = Documents.create_dynamic_document(markdown, :schema)

      assert document.type == :schema
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

    test "allows additional sections when allowed_additional_sections is '*'" do
      markdown = """
      # Context
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

      ## Delegates
      - func/1: Other.func/1
      """

      {:ok, document} = Documents.create_dynamic_document(markdown, :dynamic_document)

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

    test "validates OR logic - succeeds when first alternative is present" do
      # Create a test document type with OR logic
      markdown = """
      # Test

      ## Delegates
      - func/1: Other.func/1

      ## Dependencies
      - Other.Module

      ## Components
      Component list.
      """

      # Temporarily test with context_spec which has [["delegates", "functions"], "dependencies", "components"]
      {:ok, document} = Documents.create_dynamic_document(markdown, :context_spec)

      assert document.type == :context_spec
    end

    test "validates OR logic - succeeds when second alternative is present" do
      markdown = """
      # Test

      ## Functions

      ### my_func/1
      Does something.

      ## Dependencies
      - Other.Module

      ## Components
      Component list.
      """

      {:ok, document} = Documents.create_dynamic_document(markdown, :context_spec)

      assert document.type == :context_spec
    end

    test "validates OR logic - fails when none of the alternatives are present" do
      markdown = """
      # Test

      ## Dependencies
      - Other.Module

      ## Components
      Component list.
      """

      {:error, error} = Documents.create_dynamic_document(markdown, :context_spec)

      assert error =~ "Missing required sections"
      assert error =~ "delegates OR functions"
    end

    test "validates mixed OR and regular required sections" do
      markdown = """
      # Test

      ## Functions

      ### my_func/1
      Does something.

      ## Components
      Component list.
      """

      {:error, error} = Documents.create_dynamic_document(markdown, :context_spec)

      assert error =~ "Missing required sections"
      assert error =~ "dependencies"
      refute error =~ "delegates OR functions"
    end
  end
end

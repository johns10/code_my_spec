defmodule CodeMySpec.DocumentsTest do
  use ExUnit.Case, async: true
  doctest CodeMySpec.Documents

  alias CodeMySpec.Documents
  alias CodeMySpec.Documents.ContextDesign

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

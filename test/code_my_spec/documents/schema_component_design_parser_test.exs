defmodule CodeMySpec.Documents.SchemaComponentDesignParserTest do
  use ExUnit.Case, async: true

  alias CodeMySpec.Documents.SchemaComponentDesignParser

  describe "from_markdown/1" do
    test "parses schema component design markdown correctly" do
      markdown = """
      # User Schema

      ## Purpose
      Represents user account entities with authentication credentials and profile information.

      ## Field Documentation

      | Field | Type | Required | Description | Constraints |
      |-------|------|----------|-------------|-------------|
      | email | string | Yes | User email address | Must be valid email format, unique |
      | name | string | Yes | User full name | 1-255 characters |
      | age | integer | No | User age | Must be >= 18 |

      ## Associations
      ### belongs_to
      - **account** - References accounts.id, cascade delete

      ### has_many
      - **posts** - User's blog posts through posts.user_id

      ## Validation Rules
      ### Email Validation
      - Required
      - Format: `/^[^@\\s]+@[^@\\s]+$/`
      - Unique constraint

      ## Database Constraints
      ### Indexes
      - Primary key on id
      - Index on email for fast lookup

      ### Unique Constraints
      - Unique on email (global)
      """

      {:ok, result} = SchemaComponentDesignParser.from_markdown(markdown)

      assert result.purpose =~ "Represents user account entities"
      assert result.fields =~ "email"
      assert result.fields =~ "string"
      assert result.fields =~ "User email address"
      assert result.associations =~ "account"
      assert result.associations =~ "posts"
      assert result.validation_rules =~ "Email Validation"
      assert result.validation_rules =~ "Unique constraint"
      assert result.database_constraints =~ "Primary key on id"
      assert result.database_constraints =~ "Index on email"
    end

    test "handles empty optional sections gracefully" do
      markdown = """
      # Test Schema

      ## Purpose
      Test schema purpose.

      ## Field Documentation

      | Field | Type | Required |
      |-------|------|----------|
      | id | integer | Yes |

      ## Associations

      ## Validation Rules

      ## Database Constraints
      """

      {:ok, result} = SchemaComponentDesignParser.from_markdown(markdown)

      assert result.purpose == "Test schema purpose."
      assert result.fields =~ "id"
      assert result.fields =~ "integer"
      assert result.associations == ""
      assert result.validation_rules == ""
      assert result.database_constraints == ""
    end

    test "parses tables correctly in field documentation" do
      markdown = """
      # Product Schema

      ## Purpose
      Represents product catalog items.

      ## Field Documentation

      | Field | Type | Required | Description |
      |-------|------|----------|-------------|
      | sku | string | Yes | Product SKU code |
      | price | decimal | Yes | Product price in cents |
      | stock | integer | No | Available inventory |
      """

      {:ok, result} = SchemaComponentDesignParser.from_markdown(markdown)

      assert result.fields =~ "sku"
      assert result.fields =~ "price"
      assert result.fields =~ "stock"
      assert result.fields =~ "Product SKU code"
      assert result.fields =~ "Product price in cents"
    end

    test "supports alternate section name 'Fields'" do
      markdown = """
      # Test Schema

      ## Purpose
      Test schema.

      ## Fields
      - name: string
      - email: string
      """

      {:ok, result} = SchemaComponentDesignParser.from_markdown(markdown)

      assert result.purpose == "Test schema."
      assert result.fields =~ "name: string"
      assert result.fields =~ "email: string"
    end

    test "captures unknown sections in other_sections" do
      markdown = """
      # Test Schema

      ## Purpose
      Test schema.

      ## Field Documentation

      | Field | Type | Required |
      |-------|------|----------|
      | id | integer | Yes |

      ## Custom Section
      This is a custom section that should be preserved.

      ## Implementation Notes
      Additional implementation details.
      """

      {:ok, result} = SchemaComponentDesignParser.from_markdown(markdown)

      assert result.purpose == "Test schema."
      assert is_map(result.other_sections)
      assert Map.has_key?(result.other_sections, "custom section")
      assert Map.has_key?(result.other_sections, "implementation notes")
      assert result.other_sections["custom section"] =~ "custom section"
      assert result.other_sections["implementation notes"] =~ "Additional implementation"
    end

    test "handles minimal schema design" do
      markdown = """
      # Minimal Schema

      ## Purpose
      A minimal schema for testing.

      ## Field Documentation

      | Field | Type |
      |-------|------|
      | id | integer |
      """

      {:ok, result} = SchemaComponentDesignParser.from_markdown(markdown)

      assert result.purpose == "A minimal schema for testing."
      assert result.fields =~ "id"
      assert result.associations == ""
      assert result.validation_rules == ""
      assert result.database_constraints == ""
      assert result.other_sections == %{}
    end

    test "parses nested lists in validation rules" do
      markdown = """
      # User Schema

      ## Purpose
      User entity.

      ## Field Documentation

      | Field | Type | Required |
      |-------|------|----------|
      | email | string | Yes |

      ## Validation Rules
      ### Email Validation
      - Required
      - Format validation
      - Unique constraint

      ### Password Validation
      - Minimum 8 characters
      - Must contain special character
      """

      {:ok, result} = SchemaComponentDesignParser.from_markdown(markdown)

      assert result.validation_rules =~ "Email Validation"
      assert result.validation_rules =~ "- Required"
      assert result.validation_rules =~ "Password Validation"
      assert result.validation_rules =~ "- Minimum 8 characters"
    end

    test "handles complex database constraints section" do
      markdown = """
      # Order Schema

      ## Purpose
      Represents customer orders.

      ## Field Documentation

      | Field | Type | Required |
      |-------|------|----------|
      | id | integer | Yes |

      ## Database Constraints
      ### Indexes
      - Primary key on id
      - Composite index on (customer_id, order_date)
      - Index on status for filtering

      ### Unique Constraints
      - Unique on order_number (global)
      - Unique on (customer_id, external_id) (scoped)

      ### Foreign Keys
      - customer_id references customers.id, on_delete: cascade
      - product_id references products.id, on_delete: restrict
      """

      {:ok, result} = SchemaComponentDesignParser.from_markdown(markdown)

      assert result.database_constraints =~ "Primary key on id"
      assert result.database_constraints =~ "Composite index"
      assert result.database_constraints =~ "Unique on order_number"
      assert result.database_constraints =~ "customer_id references customers.id"
    end
  end
end
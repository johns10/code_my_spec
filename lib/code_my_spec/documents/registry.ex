defmodule CodeMySpec.Documents.Registry do
  @moduledoc """
  Central registry for document type definitions including section requirements,
  descriptions, and specifications used for AI-generated design documents.
  """

  alias CodeMySpec.Components.ComponentType

  @type document_definition :: %{
          overview: String.t(),
          required_sections: [String.t()],
          optional_sections: [String.t()],
          section_descriptions: %{String.t() => String.t()}
        }

  @component_purpose """
  Format:
  - 1-4 sentences describing the component
  - Use H2 heading

  Content:
  - Should include everything necessary to code a single elixir module
  - Concise description of the purpose and functionality of the module
  - Module should handle a distinct responsibility
  - Module should be easily testable with unit tests
  - Module should be reusable by bounded context, and be compatible with other modules in the context

  Examples:
  - ## Purpose
    Provides data access functions for Component entities with proper scope filtering and preloading.
  - ## Purpose
    Build nested dependency trees for components by processing them in optimal order (topologically sorted) to ensure all dependencies are fully analyzed before dependent components.
  """

  @context_purpose """
  Format:
  - 1-4 sentences describing the component
  - Use H2 heading

  Content:
  - Focus on the business domain, not technical implementation
  - Should clearly indicate the bounded context boundaries

  Examples:
  -  ## Purpose
  [Single sentence describing the bounded context]
  """

  @components """
  Format:
  - Use H2 heading
  - Use H3 headers for each component module
  - Include description text and table for metadata
  - Metadata table includes component type

  Content:
  - Module names must be valid Elixir modules (PascalCase)
  - Include brief description after each table
  - Tables are required to provide the type of the module
  - Focus on architectural relationships, not implementation details
  - Show clear separation of concerns
  - Indicate behavior contracts where applicable
  - Keep internal structure visible but not overwhelming
  - Use consistent naming conventions
  - Valid component types: #{ComponentType.to_string()}

  Examples:
  - ## Components
    ### ModuleName

    | field | value |
    | ----- | ----- |
    | type  | #{ComponentType.to_string()} |

    Brief description of the component's responsibility.
  """

  @dependencies """
  Format:
  - Use H2 heading
  - Simple bullet list of module names only.

  Content:
  - Each item must be a valid Elixir module name (PascalCase)
  - No descriptions or explanations - just the module names
  - Only include contexts found inside this application
  - Keep the list focused and concise

  Examples:
  - ### Execution Flow
  1. **Scope Validation**: Verify user scope and account access permissions
  2. **Rule Matching**: Query database for rules where:
    - session_type = "*" OR session_type = current_session_type
    - AND component_type = "*" OR component_type = current_component_type
  3. **Content Composition**: Concatenate rule content with proper separators
  4. **Result Return**: Return final composed rule string
  """

  @public_api """
  Format:
  - Use H2 heading
  - Wrap in backticks with elixir label

  Content:
  - Complete function specifications using `@spec` notation
  - All data access functions must accept a `Scope` struct as the first argument
  - Include all public functions the context exposes
  - Group related functions logically with comments
  - Error tuples should be specific and meaningful

  Examples:
  - ## Public API
  ```elixir
  # [Logical grouping of functions]
  @spec function_name(scope :: Scope.t(), params) :: return_type
  @type custom_type :: specific_definition

  # All functions must accept scope as first parameter
  @spec list_entities(Scope.t()) :: [Entity.t()]
  @spec get_entity!(Scope.t(), id :: integer()) :: Entity.t()
  @spec create_entity(Scope.t(), attrs :: map()) :: {:ok, Entity.t()} | {:error, Changeset.t()}
  ```
  """

  @execution_flow """
  Format:
  - Use H2 heading
  - Use H3 headings to define multiple execution flows (if required)

  Content:
  - Step-by-step walkthrough of primary operations
  - Show how public API functions orchestrate internal components
  - Number steps clearly for readability

  Examples:
  - ### Execution Flow
  1. **Scope Validation**: Verify user scope and account access permissions
  2. **Rule Matching**: Query database for rules where:
    - session_type = "*" OR session_type = current_session_type
    - AND component_type = "*" OR component_type = current_component_type
  3. **Content Composition**: Concatenate rule content with proper separators
  4. **Result Return**: Return final composed rule string
  """

  @entity_ownership """
  Format:
  - Use H2 heading
  - Unordered List

  Content:
  - List the primary entities this context owns and manages
  - Keep it concise - bullet points acceptable here

  Examples:
  - ## Entity Ownership
    - [Primary entities managed]
    - [Orchestration responsibilities]
  """

  @access_patterns """
  Format:
  - Use H2 heading
  - Unordered List

  Content:
  - Document how data access is controlled via scope
  - Review scope/scopes files to understand access control patterns

  Examples:
  - ## Access Patterns
  - [Description of how scope filtering works]
  - [Foreign key relationships]
  """

  @state_management_strategy """
  Format:
  - Use H2 heading
  - Use H3 headings to distinguish state management strategies
  - Unordered list describing each strategy

  Content:
  - Describe how data flows through the context
  - Persistence patterns (Ecto schemas with scope foreign keys)
  - Be explicit about persistence strategies
  - Explain any caching or performance considerations (if needed)
  - Document data flow patterns

  Examples:
  ### [Strategy Category]
  - [Description of approach with scope constraints]
  """

  @schema_purpose """
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

  @schema_fields """
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

  @schema_associations """
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

  @validation_rules """
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

  @database_constraints """
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

  @test_strategies """
  Format:
  - Use H2 heading
  - Organized sections for different testing aspects

  Content:
  - Document fixtures needed for testing this context
  - Identify which functions need recordings, mocks or doubles
  - Outline any special test setup or teardown requirements
  - Consider scope-based testing scenarios
  - Plan for edge cases and error conditions

  Examples:
  - ## Test Strategies
    ### Fixtures
    - **valid_component_attrs**: Factory for creating valid component attributes
    - **component_with_dependencies**: Pre-built component with full dependency tree

    ### Mocks and Doubles
    - Record external API calls in dependency resolution
    - Use test doubles for Agent process communication

    ### Testing Approach
    - Unit tests for pure functions (validation, parsing)
    - Integration tests for database operations with scope filtering
  """

  @test_assertions """
  Format:
  - Use H2 heading
  - Hierarchical list organized by describe blocks
  - Each describe contains related test assertions
  - Order from happiest path to least happy path

  Content:
  - Use ExUnit conventions (describe/test format)
  - One-line test descriptions that clearly state expected behavior
  - Group related tests under descriptive describe blocks
  - Progress from successful cases to error cases
  - Include edge cases and boundary conditions

  Examples:
  - ## Test Assertions
    - describe "list_components/1"
      - test "returns all components for given scope"
      - test "returns empty list when no components exist"
      - test "filters by scope correctly"
      - test "preloads associations when requested"
      - test "raises when scope is nil"

    - describe "create_component/2"
      - test "creates component with valid attributes"
      - test "returns error tuple with invalid attributes"
      - test "validates scope ownership"
      - test "raises when scope lacks permissions"
  """

  @default_component_definition %{
    overview: """
    Components are Elixir modules that encapsulate focused business logic within a Phoenix context.
    Each component handles a specific responsibility.
    The context module orchestrates these components to provide cohesive domain functionality.
    """,
    required_sections: ["purpose", "public api", "execution flow", "test assertions"],
    optional_sections: [],
    section_descriptions: %{
      "purpose" => @component_purpose,
      "public api" => @public_api,
      "execution flow" => @execution_flow,
      "test assertions" => @test_assertions
    }
  }

  @document_definitions %{
    context: %{
      overview: """
      Phoenix Contexts are the interface layer between your web application and domain logic.
      Each context groups related functionality and encapsulates access to data and business logic.
      Components within a context handle specific responsibilities and are orchestrated by the context module.
      """,
      required_sections: [
        "purpose",
        "entity ownership",
        "access patterns",
        "public api",
        "state management strategy",
        "execution flow",
        "dependencies",
        "components",
        "test strategies",
        "test assertions"
      ],
      optional_sections: [],
      section_descriptions: %{
        "purpose" => @context_purpose,
        "entity ownership" => @entity_ownership,
        "access patterns" => @access_patterns,
        "public api" => @public_api,
        "state management strategy" => @state_management_strategy,
        "execution flow" => @execution_flow,
        "dependencies" => @dependencies,
        "components" => @components,
        "test strategies" => @test_strategies,
        "test assertions" => @test_assertions
      }
    },
    coordination_context: %{
      overview: """
      Phoenix Contexts are the interface layer between your web application and domain logic.
      Each context groups related functionality and encapsulates access to data and business logic.
      Components within a context handle specific responsibilities and are orchestrated by the context module.
      """,
      required_sections: [
        "purpose",
        "execution flow",
        "access patterns",
        "public api",
        "test strategies",
        "test assertions"
      ],
      optional_sections: ["entity ownership", "state management strategy"],
      section_descriptions: %{
        "purpose" => @context_purpose,
        "entity ownership" => @entity_ownership,
        "access patterns" => @access_patterns,
        "public api" => @public_api,
        "state management strategy" => @state_management_strategy,
        "execution flow" => @execution_flow,
        "test strategies" => @test_strategies,
        "test assertions" => @test_assertions
      }
    },
    schema: %{
      overview: """
      Schema components represent Ecto schema entities that define data structures,
      relationships, and validation rules for persistence in the database. Each schema
      documents its fields, associations, validations, and database constraints.
      """,
      required_sections: ["purpose", "fields", "test assertions"],
      optional_sections: ["associations", "validation rules", "database constraints"],
      section_descriptions: %{
        "purpose" => @schema_purpose,
        "fields" => @schema_fields,
        "associations" => @schema_associations,
        "validation rules" => @validation_rules,
        "database constraints" => @database_constraints,
        "test assertions" => @test_assertions
      }
    }
  }

  def entity_ownership_field_description(), do: @entity_ownership
  def public_api_field_description(), do: @public_api
  def access_patterns_field_description(), do: @access_patterns
  def state_management_strategy_field_description(), do: @state_management_strategy
  def execution_flow_field_description(), do: @execution_flow

  @spec get_definition(atom()) :: document_definition()
  def get_definition(component_type) do
    Map.get(@document_definitions, component_type, @default_component_definition)
  end
end

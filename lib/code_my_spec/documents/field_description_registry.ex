defmodule CodeMySpec.Documents.FieldDescriptionRegistry do
  def component_purpose() do
    """
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
  end

  def entity_ownership() do
    """
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
  end

  def access_patterns() do
    """
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
  end

  def context_purpose() do
    """
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
  end

  def public_api() do
    """
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
  end

  def state_management_strategy() do
    """
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
  end

  def components() do
    """
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

    Examples:
    - ## Components
      ### ModuleName

      | field | value                                                                        |
      | ----- | ---------------------------------------------------------------------------- |
      | type  | genserver/context/coordination_context/schema/repository/task/registry/other |

      Brief description of the component's responsibility.
    """
  end

  def execution_flow() do
    """
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
  end

  def dependencies() do
    """
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
  end
end

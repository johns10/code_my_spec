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

  def public_api() do
    """
    Format:
    - Use H2 heading
    - Wrap in backticks with elixir label

    Content:
    - Complete function specifications using `@spec` notation
    - All data access functions must accept a `Scope` struct as the first argument
    - Include all public functions the module exposes
    - Group related functions logically with comments
    - Error tuples should be specific and meaningful

    Examples:
    - ## Public API
    ```elixir
    defmodule CodeMySpec.Components.DependencyTree do
      @spec apply([Component.t()]) :: [Component.t()]
      @spec apply(Component.t(), [Component.t()]) :: Component.t()
    end
    ```
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
end

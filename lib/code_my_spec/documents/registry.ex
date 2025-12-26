defmodule CodeMySpec.Documents.Registry do
  @moduledoc """
  Central registry for document type definitions including section requirements,
  descriptions, and specifications used for AI-generated design documents.
  """

  alias CodeMySpec.Components.ComponentType

  @type document_definition :: %{
          overview: String.t(),
          required_sections: [String.t() | [String.t()]],
          optional_sections: [String.t()],
          allowed_additional_sections: [String.t()] | String.t(),
          section_descriptions: %{String.t() => String.t()}
        }

  @spec_components """
  Format:
  - Use H2 heading
  - Use H3 headers for each component module
  - Include description text

  Content:
  - Module names must be valid Elixir modules (PascalCase)
  - Include brief description
  - Focus on architectural relationships, not implementation details
  - Show clear separation of concerns
  - Indicate behavior contracts where applicable
  - Use consistent naming conventions
  - Valid component types: #{ComponentType.to_string()}

  Examples:
  - ## Components
    ### ModuleName

    Brief description of the component's responsibility.
  """

  @spec_delegates """
  Format:
  - Use H2 heading
  - Simple bullet list of delegate function definitions

  Content:
  - Each item shows function/arity delegation in format: function_name/arity: Target.Module.function_name/arity
  - Only include functions that are delegated to other modules

  Examples:
  - ## Delegates
    - list_components/1: Components.ComponentRepository.list_components/1
    - get_component/2: Components.ComponentRepository.get_component/2
  """

  @spec_functions """
  Format:
  - Use H2 heading
  - Use H3 headers for each function in format: function_name/arity

  Content:
  - Document only PUBLIC functions (not private functions)
  - Each function should include:
    * Brief description of what the function does
    * Elixir @spec in code block
    * **Process**: Step-by-step description of the function's logic
    * **Test Assertions**: List of test cases for this function

  Examples:
  - ## Functions
    ### build/1
    Apply dependency tree processing to all components.
    ```elixir
    @spec build([Component.t()]) :: [Component.t()]
    ```
    **Process**:
    1. Topologically sort components to process dependencies first
    2. Reduce over sorted components, building a map of processed components
    **Test Assertions**:
    - returns empty list for empty input
    - processes components in dependency order
  """

  @spec_dependencies """
  Format:
  - Use H2 heading
  - Simple bullet list of module names

  Content:
  - Each item must be a valid Elixir module name (PascalCase)
  - No descriptions - just the module names
  - Only include modules this module depends on

  Examples:
  - ## Dependencies
    - CodeMySpec.Components
    - CodeMySpec.Utils
  """

  @spec_fields """
  Format:
  - Use H2 heading
  - Table format with columns: Field, Type, Required, Description, Constraints

  Content:
  - Only applicable for schemas and structs
  - List all schema fields with their Ecto types
  - Mark required fields clearly (Yes/No or Yes (auto) for auto-generated)
  - Include constraints (length, format, references)

  Examples:
  - ## Fields
    | Field       | Type         | Required   | Description           | Constraints         |
    | ----------- | ------------ | ---------- | --------------------- | ------------------- |
    | id          | integer      | Yes (auto) | Primary key           | Auto-generated      |
    | name        | string       | Yes        | Name field            | Min: 1, Max: 255    |
    | foreign_id  | integer      | Yes        | Foreign key           | References table.id |
  """

  @default_spec_definition %{
    overview: """
    Spec documents provide comprehensive documentation for Elixir modules following a
    structured format. Each spec includes module metadata, public API documentation,
    delegation information, dependencies, and detailed function specifications.

    Specs are parsed using convention-based section parsers:
    - "functions" section → Documents.Parsers.FunctionParser (returns structured Function schemas)
    - "fields" section → Documents.Parsers.FieldParser (returns structured Field schemas)
    - Other sections → Plain text extraction

    Specs should focus on WHAT the module does, not HOW it does it. Keep them concise
    and human-readable, as they're consumed by both humans and AI agents.
    """,
    required_sections: [["delegates", "functions"], "dependencies"],
    optional_sections: ["fields"],
    allowed_additional_sections: [],
    section_descriptions: %{
      "delegates" => @spec_delegates,
      "functions" => @spec_functions,
      "dependencies" => @spec_dependencies,
      "fields" => @spec_fields
    }
  }

  @document_definitions %{
    schema: %{
      overview: """
      Schema components represent Ecto schema entities that define data structures,
      relationships, and validation rules for persistence in the database. Each schema
      documents its fields, associations, validations, and database constraints.
      """,
      required_sections: ["fields"],
      optional_sections: ["functions", "dependencies"],
      allowed_additional_sections: [],
      section_descriptions: %{
        "functions" => @spec_functions,
        "dependencies" => @spec_dependencies,
        "fields" => @spec_fields
      }
    },
    context_spec: %{
      overview: """
      Spec documents provide comprehensive documentation for Elixir modules following a
      structured format. Each spec includes module metadata, public API documentation,
      delegation information, dependencies, detailed function specifications, and
      titles and brief descriptions of components contained by the context.

      Specs should focus on WHAT the module does, not HOW it does it. Keep them concise
      and human-readable, as they're consumed by both humans and AI agents.
      """,
      required_sections: [["delegates", "functions"], "dependencies", "components"],
      optional_sections: ["fields"],
      allowed_additional_sections: [],
      section_descriptions: %{
        "delegates" => @spec_delegates,
        "functions" => @spec_functions,
        "dependencies" => @spec_dependencies,
        "fields" => @spec_fields,
        "components" => @spec_components
      }
    },
    dynamic_document: %{
      overview: "A fully dynamic document",
      required_sections: [],
      optional_sections: [],
      allowed_additional_sections: "*"
    }
  }

  @spec get_definition(atom()) :: document_definition()
  def get_definition(component_type) do
    Map.get(@document_definitions, component_type, @default_spec_definition)
  end
end

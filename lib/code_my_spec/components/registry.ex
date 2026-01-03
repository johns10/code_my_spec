defmodule CodeMySpec.Components.Registry do
  @moduledoc """
  Central registry containing all component type-specific metadata and behavior definitions.
  Provides the authoritative source for component type characteristics including requirements,
  display properties, workflow rules, and validation logic.
  """

  alias CodeMySpec.Requirements.Requirement
  alias CodeMySpec.Components.Component

  @type type_definition :: %{
          requirements: [Requirement.requirement_spec()],
          display_name: String.t(),
          description: String.t(),
          icon: String.t() | nil,
          color: String.t() | nil
        }

  @child_designs %{
    name: :children_designs,
    checker: CodeMySpec.Requirements.HierarchicalChecker,
    satisfied_by: "ContextComponentsDesignSessions"
  }

  @child_implementations %{
    name: :children_implementations,
    checker: CodeMySpec.Requirements.HierarchicalChecker,
    satisfied_by: "ContextCodingSessions"
  }

  @dependencies %{
    name: :dependencies_satisfied,
    checker: CodeMySpec.Requirements.DependencyChecker,
    satisfied_by: nil
  }

  @context_design_file %{
    name: :spec_file,
    checker: CodeMySpec.Requirements.FileExistenceChecker,
    satisfied_by: "ContextSpecSessions"
  }

  @context_spec_validity %{
    name: :spec_valid,
    checker: CodeMySpec.Requirements.DocumentValidityChecker,
    satisfied_by: "ContextSpecSessions",
    document_type: "context_spec"
  }

  @design_file %{
    name: :spec_file,
    checker: CodeMySpec.Requirements.FileExistenceChecker,
    satisfied_by: "ComponentSpecSessions"
  }

  @component_spec_validity %{
    name: :spec_valid,
    checker: CodeMySpec.Requirements.DocumentValidityChecker,
    satisfied_by: "ComponentSpecSessions",
    document_type: "spec"
  }

  @schema_spec_validity %{
    name: :spec_valid,
    checker: CodeMySpec.Requirements.DocumentValidityChecker,
    satisfied_by: "ComponentSpecSessions",
    document_type: "schema"
  }

  @implementation_file %{
    name: :implementation_file,
    checker: CodeMySpec.Requirements.FileExistenceChecker,
    satisfied_by: "ComponentCodingSessions"
  }

  @test_file %{
    name: :test_file,
    checker: CodeMySpec.Requirements.FileExistenceChecker,
    satisfied_by: "ComponentTestSessions"
  }

  @review_file %{
    name: :review_file,
    checker: CodeMySpec.Requirements.ContextReviewFileChecker,
    satisfied_by: "ContextDesignReviewSessions"
  }

  @tests_passing %{
    name: :tests_passing,
    checker: CodeMySpec.Requirements.TestStatusChecker,
    satisfied_by: nil
  }

  @default_requirements [
    @design_file,
    @component_spec_validity,
    @test_file,
    @implementation_file,
    @tests_passing
  ]

  @type_definitions %{
    "genserver" => %{
      requirements: @default_requirements,
      display_name: "GenServer",
      description: "Stateful process that handles requests and maintains state",
      icon: "cpu-chip",
      color: "green"
    },
    "context" => %{
      requirements: [
        @context_design_file,
        @context_spec_validity,
        @child_designs,
        @review_file,
        @child_implementations,
        @dependencies,
        @implementation_file,
        @test_file,
        @tests_passing
      ],
      display_name: "Context",
      description: "Application domain boundary providing public API",
      icon: "squares-2x2",
      color: "purple"
    },
    "coordination_context" => %{
      requirements: [
        @context_design_file,
        @context_spec_validity,
        @child_designs,
        @review_file,
        @child_implementations,
        @dependencies,
        @implementation_file,
        @test_file,
        @tests_passing
      ],
      display_name: "Coordination Context",
      description: "Context that coordinates between multiple domains",
      icon: "arrow-path",
      color: "orange"
    },
    "schema" => %{
      requirements: [
        @design_file,
        @schema_spec_validity,
        @implementation_file
      ],
      display_name: "Schema",
      description: "Data structure definition with validation rules",
      icon: "table-cells",
      color: "blue"
    },
    "repository" => %{
      requirements: @default_requirements,
      display_name: "Repository",
      description: "Data access layer abstracting database operations",
      icon: "archive-box",
      color: "indigo"
    },
    "task" => %{
      requirements: @default_requirements,
      display_name: "Task",
      description: "Background job or one-time operation",
      icon: "clock",
      color: "yellow"
    },
    "registry" => %{
      requirements: @default_requirements,
      display_name: "Registry",
      description: "Process registry for dynamic process lookup",
      icon: "book-open",
      color: "teal"
    },
    "behaviour" => %{
      requirements: [
        @design_file,
        @component_spec_validity,
        @implementation_file
      ],
      display_name: "Behaviour",
      description: "Behaviour that defines callbacks for other modules",
      icon: "book-open",
      color: "teal"
    },
    "other" => %{
      requirements: @default_requirements,
      display_name: "Other",
      description: "Custom component type",
      icon: "cube",
      color: "gray"
    }
  }

  @spec get_type(Component.component_type()) :: type_definition()
  def get_type(component_type) do
    case Map.get(@type_definitions, component_type, nil) do
      nil ->
        # Return default requirements for components without a type
        %{
          requirements: @default_requirements,
          display_name: "Unknown",
          description: "Component type not yet defined",
          icon: "question-mark-circle",
          color: "gray"
        }

      type_def ->
        type_def
    end
  end

  @spec get_requirements_for_type(Component.component_type()) :: [Requirement.requirement_spec()]
  def get_requirements_for_type(component_type) do
    get_type(component_type).requirements
  end
end

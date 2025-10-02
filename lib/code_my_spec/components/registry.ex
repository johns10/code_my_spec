defmodule CodeMySpec.Components.Registry do
  @moduledoc """
  Central registry containing all component type-specific metadata and behavior definitions.
  Provides the authoritative source for component type characteristics including requirements,
  display properties, workflow rules, and validation logic.
  """

  alias CodeMySpec.Components.Requirements.Requirement
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
    checker: CodeMySpec.Components.Requirements.HierarchicalChecker,
    satisfied_by: nil
  }

  @dependencies %{
    name: :dependencies_satisfied,
    checker: CodeMySpec.Components.Requirements.DependencyChecker,
    satisfied_by: nil
  }

  @context_design_file %{
    name: :design_file,
    checker: CodeMySpec.Components.Requirements.FileExistenceChecker,
    satisfied_by: "ContextDesignSessions"
  }

  @design_file %{
    name: :design_file,
    checker: CodeMySpec.Components.Requirements.FileExistenceChecker,
    satisfied_by: "ComponentDesignSessions"
  }

  @implementation_file %{
    name: :implementation_file,
    checker: CodeMySpec.Components.Requirements.FileExistenceChecker,
    satisfied_by: "ComponentCodingSessions"
  }

  @test_file %{
    name: :test_file,
    checker: CodeMySpec.Components.Requirements.FileExistenceChecker,
    satisfied_by: nil
  }

  @tests_passing %{
    name: :tests_passing,
    checker: CodeMySpec.Components.Requirements.TestStatusChecker,
    satisfied_by: nil
  }

  @default_requirements [
    @design_file,
    @child_designs,
    @dependencies,
    @implementation_file,
    @test_file,
    @tests_passing
  ]

  @type_definitions %{
    genserver: %{
      requirements: @default_requirements,
      display_name: "GenServer",
      description: "Stateful process that handles requests and maintains state",
      icon: "cpu-chip",
      color: "green"
    },
    context: %{
      requirements: [
        @context_design_file,
        @child_designs,
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
    coordination_context: %{
      requirements: [
        @context_design_file,
        @child_designs,
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
    schema: %{
      requirements: [
        @design_file,
        @implementation_file,
        @dependencies
      ],
      display_name: "Schema",
      description: "Data structure definition with validation rules",
      icon: "table-cells",
      color: "blue"
    },
    repository: %{
      requirements: @default_requirements,
      display_name: "Repository",
      description: "Data access layer abstracting database operations",
      icon: "archive-box",
      color: "indigo"
    },
    task: %{
      requirements: @default_requirements,
      display_name: "Task",
      description: "Background job or one-time operation",
      icon: "clock",
      color: "yellow"
    },
    registry: %{
      requirements: @default_requirements,
      display_name: "Registry",
      description: "Process registry for dynamic process lookup",
      icon: "book-open",
      color: "teal"
    },
    other: %{
      requirements: @default_requirements,
      display_name: "Other",
      description: "Custom component type",
      icon: "cube",
      color: "gray"
    }
  }

  @spec get_type(Component.component_type()) :: type_definition()
  def get_type(component_type) do
    case Map.get(@type_definitions, component_type) do
      nil -> raise "Unknown component type: #{component_type}"
      type_def -> type_def
    end
  end

  @spec get_requirements_for_type(Component.component_type()) :: [Requirement.requirement_spec()]
  def get_requirements_for_type(component_type) do
    get_type(component_type).requirements
  end
end

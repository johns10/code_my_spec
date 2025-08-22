defmodule CodeMySpec.Components.Registry do
  @moduledoc """
  Central registry containing all component type-specific metadata and behavior definitions.
  Provides the authoritative source for component type characteristics including requirements,
  display properties, workflow rules, and validation logic.
  """

  alias CodeMySpec.Components.Component

  @type component_type ::
          :genserver
          | :context
          | :coordination_context
          | :schema
          | :repository
          | :task
          | :registry
          | :other

  @type type_definition :: %{
          requirements: [requirement_spec()],
          display_name: String.t(),
          description: String.t(),
          icon: String.t() | nil,
          color: String.t() | nil
        }

  @type requirement_spec :: %{
          name: atom(),
          checker: module(),
          satisfied_by: module() | nil
        }



  @default_requirements [
    %{
      name: :design_file,
      checker: CodeMySpec.Components.Requirements.FileExistenceChecker,
      satisfied_by: CodeMySpec.ContextDesignSessions
    },
    %{
      name: :implementation_file,
      checker: CodeMySpec.Components.Requirements.FileExistenceChecker,
      satisfied_by: nil
    },
    %{
      name: :test_file,
      checker: CodeMySpec.Components.Requirements.FileExistenceChecker,
      satisfied_by: nil
    },
    %{
      name: :tests_passing,
      checker: CodeMySpec.Components.Requirements.TestStatusChecker,
      satisfied_by: nil
    },
    %{
      name: :dependencies_satisfied,
      checker: CodeMySpec.Components.Requirements.DependencyChecker,
      satisfied_by: nil
    }
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
      requirements: @default_requirements,
      display_name: "Context",
      description: "Application domain boundary providing public API",
      icon: "squares-2x2",
      color: "purple"
    },
    coordination_context: %{
      requirements: @default_requirements,
      display_name: "Coordination Context",
      description: "Context that coordinates between multiple domains",
      icon: "arrow-path",
      color: "orange"
    },
    schema: %{
      requirements: [
        %{
          name: :design_file,
          checker: CodeMySpec.Components.Requirements.FileExistenceChecker,
          satisfied_by: CodeMySpec.ContextDesignSessions
        },
        %{
          name: :implementation_file,
          checker: CodeMySpec.Components.Requirements.FileExistenceChecker,
          satisfied_by: nil
        },
        %{
          name: :dependencies_satisfied,
          checker: CodeMySpec.Components.Requirements.DependencyChecker,
          satisfied_by: nil
        }
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

  @spec get_type(component_type()) :: type_definition()
  def get_type(component_type) do
    case Map.get(@type_definitions, component_type) do
      nil -> raise "Unknown component type: #{component_type}"
      type_def -> type_def
    end
  end

  @spec get_requirements_for_type(component_type()) :: [requirement_spec()]
  def get_requirements_for_type(component_type) do
    get_type(component_type).requirements
  end

  @spec requirements_satisfied?(Component.t(), map()) :: boolean()
  def requirements_satisfied?(%Component{type: type}, component_status) do
    requirements = get_requirements_for_type(type)
    
    Enum.all?(requirements, fn req_spec ->
      checker = req_spec.checker
      result = checker.check(req_spec, component_status)
      result.satisfied
    end)
  end
end

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
          requirements: [requirement_definition()],
          display_name: String.t(),
          description: String.t(),
          icon: String.t() | nil,
          color: String.t() | nil
        }

  @type requirement_definition :: %{
          name: atom(),
          type: requirement_type(),
          description: String.t(),
          checker_module: module()
        }

  @type requirement_type :: :file_existence | :test_status | :cross_component | :manual_review

  @type requirement_check :: %{
          requirement: requirement_definition(),
          satisfied: boolean(),
          details: map()
        }

  @type requirement_status :: %{
          component: Component.t(),
          requirements: [requirement_check()],
          overall_satisfied: boolean()
        }

  @type component_status :: %{
          component: Component.t(),
          design_exists: boolean(),
          code_exists: boolean(),
          test_exists: boolean(),
          test_status: :passing | :failing | :none_available | :not_run,
          missing_files: [String.t()],
          approvals: [map()]
        }

  @default_requirements [
    %{
      name: :design_file,
      type: :file_existence,
      description: "Component design documentation exists",
      checker_module: CodeMySpec.Components.Requirements.FileExistenceChecker
    },
    %{
      name: :implementation_file,
      type: :file_existence,
      description: "Component implementation file exists",
      checker_module: CodeMySpec.Components.Requirements.FileExistenceChecker
    },
    %{
      name: :test_file,
      type: :file_existence,
      description: "Component test file exists",
      checker_module: CodeMySpec.Components.Requirements.FileExistenceChecker
    },
    %{
      name: :tests_passing,
      type: :test_status,
      description: "Component tests are passing",
      checker_module: CodeMySpec.Components.Requirements.TestStatusChecker
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
          type: :file_existence,
          description: "Schema design documentation exists",
          checker_module: CodeMySpec.Components.Requirements.FileExistenceChecker
        },
        %{
          name: :implementation_file,
          type: :file_existence,
          description: "Schema implementation file exists",
          checker_module: CodeMySpec.Components.Requirements.FileExistenceChecker
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

  @spec get_requirements_for_type(component_type()) :: [requirement_definition()]
  def get_requirements_for_type(component_type) do
    get_type(component_type).requirements
  end

  @spec check_requirements_satisfied(Component.t(), component_status()) :: requirement_status()
  def check_requirements_satisfied(%Component{type: type} = component, component_status) do
    requirements = get_requirements_for_type(type)

    requirement_checks =
      Enum.map(requirements, &check_single_requirement(&1, component_status))

    %{
      component: component,
      requirements: requirement_checks,
      overall_satisfied: Enum.all?(requirement_checks, & &1.satisfied)
    }
  end

  defp check_single_requirement(req_def, component_status) do
    checker = req_def.checker_module
    result = checker.check(req_def, component_status)

    %{
      requirement: req_def,
      satisfied: result.satisfied,
      details: result.details
    }
  end
end

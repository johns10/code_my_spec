defmodule CodeMySpecCli.SlashCommands.ValidateComponentSpec do
  @moduledoc """
  Validate a component specification that Claude generated.

  Uses the ComponentSpecSession to validate the spec file against
  the document schema and provide feedback if there are errors.

  ## Usage

  From Claude Code markdown command (stop hook):
      !`MIX_ENV=cli mix cli validate-component-spec MyApp.Accounts`

  ## Output

  Outputs validation results:
  - If valid: Success message
  - If invalid: Validation errors for Claude to fix
  """

  use CodeMySpecCli.SlashCommands.SlashCommandBehaviour

  alias CodeMySpec.ComponentSpecSessions.ComponentSpecSession
  alias CodeMySpec.Components

  def execute(scope, args) do
    module_name = args.module_name

    with {:ok, component} <- get_component(scope, module_name),
         {:ok, project} <- get_project(scope),
         {:ok, session} <- build_session(component, project),
         result <- ComponentSpecSession.evaluate(scope, session) do
      handle_validation_result(result)
    else
      {:error, reason} ->
        IO.puts(:stderr, "Error: #{reason}")
        {:error, reason}
    end
  rescue
    error ->
      IO.puts(:stderr, "Failed to validate component spec: #{Exception.message(error)}")
      {:error, Exception.message(error)}
  end

  # Get component by module name
  defp get_component(scope, module_name) do
    case Components.get_component_by_module_name(scope, module_name) do
      nil -> {:error, "Component not found with module name: #{module_name}"}
      component -> {:ok, component}
    end
  end

  defp get_project(scope) do
    case scope.active_project do
      nil -> {:error, "No active project. Please set an active project."}
      project -> {:ok, project}
    end
  end

  defp build_session(component, project) do
    session = %{
      component: component,
      project: project,
      environment: :cli
    }

    {:ok, session}
  end

  defp handle_validation_result({:ok, :valid}) do
    IO.puts("✓ Component specification is valid!")
    :ok
  end

  defp handle_validation_result({:ok, :invalid, feedback}) do
    IO.puts(:stderr, "✗ Component specification validation failed:\n\n#{feedback}")
    {:error, "validation_failed"}
  end
end

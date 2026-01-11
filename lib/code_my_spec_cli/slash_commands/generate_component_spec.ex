defmodule CodeMySpecCli.SlashCommands.GenerateComponentSpec do
  @moduledoc """
  Generate a component specification prompt for Claude.

  Uses the ComponentSpecSession to build a prompt with design rules,
  document specifications, and project context.

  ## Usage

  From Claude Code markdown command:
      !`mix codemyspec generate-component-spec MyApp.Accounts`

  ## Output

  Outputs the prompt text that Claude will use to generate the component spec.
  """

  use CodeMySpecCli.SlashCommands.SlashCommandBehaviour

  alias CodeMySpec.ComponentSpecSessions.ComponentSpecSession
  alias CodeMySpec.Components

  def execute(scope, args) do
    module_name = args.module_name

    with {:ok, component} <- get_component(scope, module_name),
         {:ok, project} <- get_project(scope),
         {:ok, session} <- build_session(component, project),
         {:ok, prompt} <- ComponentSpecSession.command(scope, session) do
      # Output the prompt for Claude to consume
      IO.puts(prompt)
      :ok
    else
      {:error, reason} ->
        IO.puts(:stderr, "Error: #{reason}")
        {:error, reason}
    end
  rescue
    error ->
      IO.puts(:stderr, "Failed to generate component spec: #{Exception.message(error)}")
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
end

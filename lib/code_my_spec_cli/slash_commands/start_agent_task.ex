defmodule CodeMySpecCli.SlashCommands.StartAgentTask do
  @moduledoc """
  Start an agent task session and output the first interaction prompt.

  Creates a database Session, looks up the component by module name, and calls
  the appropriate AgentTask module to generate the prompt. Session state is
  persisted to disk via CurrentSession for the evaluate command to pick up.

  ## Usage

  From CLI:
      MIX_ENV=cli mix cli start-agent-task -t component_spec -m MyApp.Accounts

  ## Output

  On success: Outputs the prompt text directly to stdout.
  On error: Outputs error message to stderr.

  Session state is persisted to `.code_my_spec/internal/current_session/session.json`
  """

  use CodeMySpecCli.SlashCommands.SlashCommandBehaviour

  alias CodeMySpec.Components
  alias CodeMySpec.Sessions
  alias CodeMySpec.Sessions.AgentTasks
  alias CodeMySpec.Sessions.CurrentSession
  alias CodeMySpec.ProjectSync.Sync
  alias CodeMySpec.Requirements

  # Maps CLI session type names to AgentTask modules
  # Note: "spec" is handled specially in resolve_session_type/2 to auto-detect context vs component
  @session_type_map %{
    "component_spec" => AgentTasks.ComponentSpec,
    "context_spec" => AgentTasks.ContextSpec,
    "context_component_specs" => AgentTasks.ContextComponentSpecs,
    "implement_context" => AgentTasks.ContextImplementation,
    "component_code" => AgentTasks.ComponentCode,
    "component_test" => AgentTasks.ComponentTest
  }

  @valid_types ["spec" | Map.keys(@session_type_map)]

  def execute(scope, args) do
    session_type = Map.get(args, :session_type)
    module_name = Map.get(args, :module_name)

    # Fetch component before resolving session type so "spec" can auto-detect
    with {:ok, project} <- get_project(scope),
         {:ok, sync_result} <- sync_project(scope),
         {:ok, component} <- get_component(scope, module_name),
         {:ok, agent_task_module} <- resolve_session_type(session_type, component),
         {:ok, db_session} <- create_session(scope, agent_task_module, component),
         {:ok, task_session} <- build_task_session(component, project),
         {:ok, prompt} <- agent_task_module.command(scope, task_session),
         :ok <- persist_session(db_session, session_type, component) do
      output_sync_metrics(sync_result)
      # Output just the prompt for Claude to consume
      IO.puts(prompt)
      :ok
    else
      {:error, reason} ->
        IO.puts(:stderr, "Error: #{format_error(reason)}")
        {:error, reason}
    end
  rescue
    error ->
      IO.puts(:stderr, "Error: #{Exception.message(error)}")
      {:error, Exception.message(error)}
  end

  defp resolve_session_type(nil, _component) do
    {:error, "Session type is required. Valid types: #{Enum.join(@valid_types, ", ")}"}
  end

  # Auto-detect context vs component spec based on module structure
  defp resolve_session_type("spec", component) do
    if Components.context?(component) do
      {:ok, AgentTasks.ContextSpec}
    else
      {:ok, AgentTasks.ComponentSpec}
    end
  end

  defp resolve_session_type(name, _component) do
    case Map.get(@session_type_map, name) do
      nil ->
        {:error, "Unknown session type: #{name}. Valid types: #{Enum.join(@valid_types, ", ")}"}

      module ->
        {:ok, module}
    end
  end

  defp get_component(_scope, nil) do
    {:error, "Module name is required. Use -m or --module-name"}
  end

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

  defp create_session(scope, session_module, component) do
    Sessions.create_session(scope, %{
      type: session_module,
      environment: :cli,
      agent: :claude_code,
      execution_mode: :manual,
      component_id: component.id
    })
  end

  defp build_task_session(component, project) do
    {:ok,
     %{
       component: component,
       project: project,
       environment: :cli
     }}
  end

  defp persist_session(db_session, session_type, component) do
    CurrentSession.save(%{
      session_id: db_session.id,
      session_type: session_type,
      component_id: component.id,
      component_name: component.name,
      module_name: component.module_name
    })
  end

  defp sync_project(scope) do
    # Clear all requirements before resyncing
    Requirements.clear_all_project_requirements(scope)

    case Sync.sync_all(scope) do
      {:ok, result} ->
        {:ok, result}

      {:error, reason} ->
        {:error, "Sync failed: #{inspect(reason)}"}
    end
  end

  defp output_sync_metrics(%{timings: timings}) do
    # Output to stderr so prompt on stdout is clean
    IO.puts(
      :stderr,
      "Sync: contexts=#{timings.contexts_sync_ms}ms requirements=#{timings.requirements_sync_ms}ms total=#{timings.total_ms}ms"
    )
  end

  defp format_error(reason) when is_binary(reason), do: reason
  defp format_error(%Ecto.Changeset{} = changeset), do: inspect(changeset.errors)
  defp format_error(reason), do: inspect(reason)
end

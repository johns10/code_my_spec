defmodule CodeMySpecCli.SlashCommands.StartAgentTask do
  @moduledoc """
  Start an agent task session and output the first interaction prompt.

  Creates a database Session with the Claude session ID stored as external_conversation_id,
  looks up the component by module name, and calls the appropriate AgentTask module to
  generate the prompt.

  ## Usage

  From CLI (typically via cms-start script):
      MIX_ENV=cli mix cli start-agent-task -e <claude_session_id> -t spec -m MyApp.Accounts

  ## Output

  On success: Outputs the prompt text directly to stdout.
  On error: Outputs error message to stderr.
  """

  use CodeMySpecCli.SlashCommands.SlashCommandBehaviour

  alias CodeMySpec.Components
  alias CodeMySpec.ProjectSync.Sync
  alias CodeMySpec.Requirements
  alias CodeMySpec.Sessions
  alias CodeMySpec.Sessions.AgentTasks

  # Maps CLI session type names to AgentTask modules
  # Note: "spec" is handled specially in resolve_session_type/2 to auto-detect context vs component
  @session_type_map %{
    "component_spec" => AgentTasks.ComponentSpec,
    "context_spec" => AgentTasks.ContextSpec,
    "context_component_specs" => AgentTasks.ContextComponentSpecs,
    "context_design_review" => AgentTasks.ContextDesignReview,
    "implement_context" => AgentTasks.ContextImplementation,
    "component_code" => AgentTasks.ComponentCode,
    "component_test" => AgentTasks.ComponentTest
  }

  @valid_types ["spec" | Map.keys(@session_type_map)]

  def execute(scope, args) do
    external_id = Map.get(args, :external_id)
    session_type = Map.get(args, :session_type)
    module_name = Map.get(args, :module_name)

    # Fetch component before resolving session type so "spec" can auto-detect
    with {:ok, _} <- validate_external_id(external_id),
         {:ok, project} <- get_project(scope),
         {:ok, sync_result} <- sync_project(scope),
         {:ok, component} <- get_component(scope, module_name),
         {:ok, agent_task_module} <- resolve_session_type(session_type, component),
         {:ok, _db_session} <- create_session(scope, external_id, agent_task_module, component),
         {:ok, task_session} <- build_task_session(external_id, component, project),
         {:ok, prompt} <- agent_task_module.command(scope, task_session) do
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

  defp validate_external_id(nil) do
    {:error, "External ID is required. Use -e or --external-id with the Claude session ID"}
  end

  defp validate_external_id(external_id) when is_binary(external_id), do: {:ok, external_id}

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

  defp get_component(nil, _module_name) do
    {:error,
     "No project configured. Run the CLI in a directory with .code_my_spec/config.yml or run /init first."}
  end

  defp get_component(scope, module_name) do
    case Components.get_component_by_module_name(scope, module_name) do
      nil -> {:error, "Component not found with module name: #{module_name}"}
      component -> {:ok, component}
    end
  end

  defp get_project(nil) do
    {:error,
     "No project configured. Run the CLI in a directory with .code_my_spec/config.yml or run /init first."}
  end

  defp get_project(scope) do
    case scope.active_project do
      nil -> {:error, "No active project. Please set an active project."}
      project -> {:ok, project}
    end
  end

  defp create_session(scope, external_id, session_module, component) do
    Sessions.create_session(scope, %{
      type: session_module,
      environment: :cli,
      agent: :claude_code,
      execution_mode: :manual,
      component_id: component.id,
      external_conversation_id: external_id
    })
  end

  defp build_task_session(external_id, component, project) do
    {:ok,
     %{
       external_id: external_id,
       component: component,
       project: project,
       environment: :cli
     }}
  end

  defp sync_project(nil) do
    {:error,
     "No project configured. Run the CLI in a directory with .code_my_spec/config.yml or run /init first."}
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

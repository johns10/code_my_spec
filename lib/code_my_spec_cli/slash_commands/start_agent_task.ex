defmodule CodeMySpecCli.SlashCommands.StartAgentTask do
  @moduledoc """
  Start an agent task session and output the first interaction prompt.

  Creates a database Session, looks up the component by module name, and calls
  the appropriate AgentTask module to generate the prompt.

  ## Usage

  From CLI:
      MIX_ENV=cli mix cli start-agent-task -t component_spec -m MyApp.Accounts

  ## Output Format

  Outputs marker-delimited data that bash can parse:
      :::SESSION_ID:::
      <session_id>
      :::SESSION_TYPE:::
      <type>
      :::STATUS:::
      ok
      :::PROMPT:::
      <<<PROMPT_START
      <prompt text>
      >>>PROMPT_END
  """

  use CodeMySpecCli.SlashCommands.SlashCommandBehaviour

  alias CodeMySpec.Components
  alias CodeMySpec.Sessions
  alias CodeMySpec.Sessions.AgentTasks

  # Maps CLI session type names to {SessionModule, AgentTaskModule}
  @session_type_map %{
    "component_spec" => {CodeMySpec.ComponentSpecSessions, AgentTasks.ComponentSpec}
    # Add more as they're implemented:
    # "component_coding" => {CodeMySpec.ComponentCodingSessions, AgentTasks.ComponentCoding},
  }

  def execute(scope, args) do
    session_type = Map.get(args, :session_type)
    module_name = Map.get(args, :module_name)

    with {:ok, {session_module, agent_task_module}} <- resolve_session_type(session_type),
         {:ok, component} <- get_component(scope, module_name),
         {:ok, project} <- get_project(scope),
         {:ok, db_session} <- create_session(scope, session_module, component),
         {:ok, task_session} <- build_task_session(component, project),
         {:ok, prompt} <- agent_task_module.command(scope, task_session) do
      output_structured_response(db_session, session_type, component, prompt)
      :ok
    else
      {:error, reason} ->
        output_error(reason)
        {:error, reason}
    end
  rescue
    error ->
      output_error(Exception.message(error))
      {:error, Exception.message(error)}
  end

  defp resolve_session_type(nil) do
    valid_types = Map.keys(@session_type_map) |> Enum.join(", ")
    {:error, "Session type is required. Valid types: #{valid_types}"}
  end

  defp resolve_session_type(name) do
    case Map.get(@session_type_map, name) do
      nil ->
        valid_types = Map.keys(@session_type_map) |> Enum.join(", ")
        {:error, "Unknown session type: #{name}. Valid types: #{valid_types}"}

      modules ->
        {:ok, modules}
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

  defp output_structured_response(db_session, session_type, component, prompt) do
    output_field("SESSION_ID", to_string(db_session.id))
    output_field("SESSION_TYPE", session_type)
    output_field("COMPONENT", component.name)
    output_field("STATUS", "ok")
    output_multiline("PROMPT", prompt)
  end

  defp output_error(reason) do
    output_field("STATUS", "error")
    output_multiline("ERROR", format_error(reason))
  end

  defp output_field(name, value) do
    IO.puts(":::#{name}:::")
    IO.puts(value)
  end

  defp output_multiline(name, content) do
    IO.puts(":::#{name}:::")
    IO.puts("<<<#{name}_START")
    IO.puts(content)
    IO.puts(">>>#{name}_END")
  end

  defp format_error(reason) when is_binary(reason), do: reason
  defp format_error(%Ecto.Changeset{} = changeset), do: inspect(changeset.errors)
  defp format_error(reason), do: inspect(reason)
end

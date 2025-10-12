defmodule CodeMySpecWeb.SessionsJSON do
  alias CodeMySpec.Sessions.Session

  @doc """
  Renders a list of sessions.
  """
  def index(%{sessions: sessions}) do
    %{data: for(session <- sessions, do: data(session))}
  end

  @doc """
  Renders a single session.
  """
  def show(%{session: session}) do
    %{data: data(session)}
  end

  defp data(%Session{} = session) do
    %{
      id: session.id,
      type: session.type |> Atom.to_string() |> String.split(".") |> List.last(),
      agent: session.agent,
      environment: session.environment,
      execution_mode: session.execution_mode,
      status: session.status,
      state: session.state,
      external_conversation_id: session.external_conversation_id,
      project_id: session.project_id,
      project: render_project(session.project),
      account_id: session.account_id,
      user_id: session.user_id,
      component_id: session.component_id,
      component: render_component(session.component),
      interactions: render_interactions(session.interactions),
      inserted_at: session.inserted_at,
      updated_at: session.updated_at
    }
  end

  defp render_interactions(interactions) do
    Enum.map(interactions, fn interaction ->
      %{
        id: interaction.id,
        command: render_command(interaction.command),
        result: render_result(interaction.result),
        completed_at: interaction.completed_at
      }
    end)
  end

  defp render_command(nil), do: nil

  defp render_command(command) do
    %{
      module: command.module,
      command: command.command,
      pipe: command.pipe,
      metadata: command.metadata,
      timestamp: command.timestamp
    }
  end

  defp render_result(nil), do: nil

  defp render_result(result) do
    %{
      id: result.id,
      status: result.status,
      data: result.data,
      code: result.code,
      error_message: result.error_message,
      stdout: result.stdout,
      stderr: result.stderr,
      duration_ms: result.duration_ms,
      timestamp: result.timestamp
    }
  end

  defp render_project(%Ecto.Association.NotLoaded{}), do: nil
  defp render_project(nil), do: nil

  defp render_project(project) do
    %{
      id: project.id,
      name: project.name,
      module_name: project.module_name,
      status: project.status
    }
  end

  defp render_component(%Ecto.Association.NotLoaded{}), do: nil
  defp render_component(nil), do: nil

  defp render_component(component) do
    %{
      id: component.id,
      name: component.name,
      type: component.type,
      module_name: component.module_name
    }
  end
end

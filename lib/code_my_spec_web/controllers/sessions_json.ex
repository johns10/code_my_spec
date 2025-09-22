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

  @doc """
  Renders a command for execution.
  """
  def command(%{interaction_id: interaction_id, command: command_data, status: status}) do
    %{
      interaction_id: interaction_id,
      command: command_data,
      status: status
    }
  end

  defp data(%Session{} = session) do
    %{
      id: session.id,
      type: session.type |> Atom.to_string() |> String.split(".") |> List.last(),
      agent: session.agent,
      environment: session.environment,
      status: session.status,
      state: session.state,
      project_id: session.project_id,
      account_id: session.account_id,
      component_id: session.component_id,
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
      id: command.id,
      module: command.module,
      command: command.command,
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
end

defmodule CodeMySpecWeb.VSCodeChannel do
  @moduledoc """
  Channel for VS Code clients to receive session updates.

  Clients can join the channel for a specific user and receive
  real-time session updates via PubSub broadcasts.
  """
  use CodeMySpecWeb, :channel

  alias CodeMySpec.Sessions

  @impl true
  def join("vscode:user:" <> user_id_str, _payload, socket) do
    # Parse user_id from the topic
    case Integer.parse(user_id_str) do
      {user_id, ""} ->
        # Subscribe to session updates for this user
        Sessions.subscribe_user_sessions(user_id)

        {:ok, assign(socket, :user_id, user_id)}

      _ ->
        {:error, %{reason: "invalid user_id"}}
    end
  end

  @impl true
  def join(_topic, _payload, _socket) do
    {:error, %{reason: "invalid topic"}}
  end

  @impl true
  def handle_info({:created, session}, socket) do
    push(socket, "session_created", session_payload(session))
    {:noreply, socket}
  end

  @impl true
  def handle_info({:updated, session}, socket) do
    push(socket, "session_updated", session_payload(session))
    {:noreply, socket}
  end

  @impl true
  def handle_info({:deleted, session}, socket) do
    push(socket, "session_deleted", %{id: session.id})
    {:noreply, socket}
  end

  # Convert session to a JSON-friendly payload
  defp session_payload(session) do
    %{
      id: session.id,
      type: session.type,
      agent: session.agent,
      environment: session.environment,
      execution_mode: session.execution_mode,
      status: session.status,
      state: session.state,
      project_id: session.project_id,
      account_id: session.account_id,
      user_id: session.user_id,
      component_id: session.component_id,
      session_id: session.session_id,
      external_conversation_id: session.external_conversation_id,
      interactions: Enum.map(session.interactions || [], &interaction_payload/1),
      inserted_at: session.inserted_at,
      updated_at: session.updated_at
    }
  end

  defp interaction_payload(interaction) do
    %{
      id: interaction.id,
      step_name: interaction.step_name,
      command: command_payload(interaction.command),
      result: result_payload(interaction.result),
      completed_at: interaction.completed_at
    }
  end

  defp command_payload(nil), do: nil

  defp command_payload(command) do
    %{
      id: command.id,
      module: command.module,
      command: command.command,
      metadata: command.metadata,
      pipe: command.pipe,
      timestamp: command.timestamp
    }
  end

  defp result_payload(nil), do: nil

  defp result_payload(result) do
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

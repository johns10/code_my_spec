defmodule CodeMySpecWeb.VSCodeChannel do
  @moduledoc """
  Channel for VS Code clients to receive session updates.

  Clients can join the channel for a specific user and receive
  real-time session updates via PubSub broadcasts.
  """
  use CodeMySpecWeb, :channel

  alias CodeMySpec.Sessions

  @impl true
  def join("vscode:user", _payload, socket) do
    # Get user_id from socket assigns (set during authentication)
    case socket.assigns[:user_id] do
      user_id when is_integer(user_id) ->
        # Subscribe to session updates for this user
        Sessions.subscribe_user_sessions(user_id)

        # Track this user's presence
        {:ok, _} =
          CodeMySpecWeb.Presence.track(socket, "user:#{user_id}", %{
            online_at: inspect(System.system_time(:second)),
            user_id: user_id
          })

        {:ok, socket}

      _ ->
        {:error, %{reason: "not authenticated"}}
    end
  end

  @impl true
  def join(_topic, _payload, _socket) do
    {:error, %{reason: "invalid topic"}}
  end

  @impl true
  def handle_info({:created, session}, socket) do
    push(socket, "session_created", CodeMySpecWeb.SessionsJSON.show(%{session: session}))
    {:noreply, socket}
  end

  @impl true
  def handle_info({:updated, session}, socket) do
    push(socket, "session_updated", CodeMySpecWeb.SessionsJSON.show(%{session: session}))
    {:noreply, socket}
  end

  @impl true
  def handle_info({:deleted, session}, socket) do
    push(socket, "session_deleted", %{id: session.id})
    {:noreply, socket}
  end

  @impl true
  def handle_info({:session_activity, %{session_id: session_id}}, socket) do
    push(socket, "session_activity", %{session_id: session_id})
    {:noreply, socket}
  end

  @impl true
  def handle_info({:notification_hook, payload}, socket) do
    push(socket, "notification_hook", payload)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:session_mode_updated, payload}, socket) do
    push(socket, "session_mode_updated", payload)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:conversation_id_set, _payload}, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: "presence_diff", payload: diff}, socket) do
    push(socket, "presence_diff", diff)
    {:noreply, socket}
  end

  # Handle chunked sync-requirements upload
  @impl true
  def handle_in("sync_requirements:start", %{"upload_id" => upload_id}, socket) do
    # Create a temporary file for this upload
    case Briefly.create() do
      {:ok, path} ->
        socket = assign(socket, :upload_temp_path, path)
        {:reply, {:ok, %{upload_id: upload_id, status: "ready"}}, socket}

      {:error, reason} ->
        {:reply, {:error, %{reason: inspect(reason)}}, socket}
    end
  end

  @impl true
  def handle_in("sync_requirements:chunk", payload, socket) do
    %{
      "chunk_index" => chunk_index,
      "data" => chunk_data
    } = payload

    temp_path = socket.assigns[:upload_temp_path]

    if temp_path do
      # Append chunk to temp file
      case File.write(temp_path, chunk_data, [:append]) do
        :ok ->
          {:reply, {:ok, %{chunk_index: chunk_index, status: "received"}}, socket}

        {:error, reason} ->
          {:reply, {:error, %{reason: inspect(reason)}}, socket}
      end
    else
      {:reply, {:error, %{reason: "No upload in progress. Call sync_requirements:start first"}},
       socket}
    end
  end

  @impl true
  def handle_in("sync_requirements:complete", payload, socket) do
    persist = Map.get(payload, "persist", false)
    temp_path = socket.assigns[:upload_temp_path]

    if temp_path do
      # Read the complete payload from temp file
      case File.read(temp_path) do
        {:ok, json_data} ->
          case Jason.decode(json_data) do
            {:ok, data} ->
              scope = socket.assigns[:scope]
              result = process_sync_requirements(data, persist, scope)
              socket = assign(socket, :upload_temp_path, nil)
              {:reply, {:ok, result}, socket}

            {:error, reason} ->
              {:reply, {:error, %{reason: "JSON decode error: #{inspect(reason)}"}}, socket}
          end

        {:error, reason} ->
          {:reply, {:error, %{reason: "File read error: #{inspect(reason)}"}}, socket}
      end
    else
      {:reply, {:error, %{reason: "No upload in progress"}}, socket}
    end
  end

  @impl true
  def handle_in("list_sessions", payload, socket) do
    scope = socket.assigns[:scope]

    if scope do
      opts = parse_list_sessions_opts(payload)
      sessions = Sessions.list_sessions(scope, opts)
      response = CodeMySpecWeb.SessionsJSON.index(%{sessions: sessions})
      {:reply, {:ok, response}, socket}
    else
      {:reply, {:error, %{reason: "not authenticated"}}, socket}
    end
  end

  defp process_sync_requirements(data, persist, scope) do
    file_list = Map.get(data, "file_list", [])
    test_results_data = Map.get(data, "test_results", %{})

    changeset = CodeMySpec.Tests.TestRun.changeset(test_results_data)
    test_run = Ecto.Changeset.apply_changes(changeset)

    opts = [persist: persist]

    components =
      CodeMySpec.ProjectCoordinator.sync_project_requirements(scope, file_list, test_run, opts)

    # Use the JSON view to serialize components properly
    CodeMySpecWeb.ProjectCoordinatorJSON.sync_requirements(%{
      components: components,
      next_components: []
    })
  end

  defp parse_list_sessions_opts(payload) do
    case Map.get(payload, "status") do
      nil -> []
      status when is_binary(status) -> [status: [String.to_existing_atom(status)]]
      statuses when is_list(statuses) -> [status: Enum.map(statuses, &String.to_existing_atom/1)]
      _ -> []
    end
  end
end

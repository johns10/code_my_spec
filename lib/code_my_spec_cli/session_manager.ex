defmodule CodeMySpecCli.SessionManager do
  @moduledoc """
  Manages Claude Code sessions in tmux

  Sessions persist across CLI restarts because they run in tmux.
  Each session gets a unique ID and tmux session name.
  """

  use GenServer
  require Logger

  # Client API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def start_session(context_name, story_id, prompt) do
    GenServer.call(__MODULE__, {:start_session, context_name, story_id, prompt}, 30_000)
  end

  def list_sessions do
    GenServer.call(__MODULE__, :list_sessions)
  end

  def get_session(session_id) do
    GenServer.call(__MODULE__, {:get_session, session_id})
  end

  def attach_to_session(session_id) do
    # Runs synchronously, takes over terminal
    case get_session(session_id) do
      {:ok, session} ->
        # User attaches, can detach with Ctrl-B D
        System.cmd("tmux", ["attach", "-t", session.tmux_name])
        :ok

      {:error, :not_found} ->
        IO.puts("Session not found: #{session_id}")
        :error
    end
  end

  def kill_session(session_id) do
    GenServer.call(__MODULE__, {:kill_session, session_id})
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    # Verify tmux available
    case System.cmd("which", ["tmux"], stderr_to_stdout: true) do
      {_path, 0} ->
        # Also check if claude is available
        case System.cmd("which", ["claude"], stderr_to_stdout: true) do
          {_path, 0} ->
            {:ok, %{sessions: %{}}}

          _ ->
            Logger.warning("claude not found in PATH - sessions may fail to start")
            {:ok, %{sessions: %{}}}
        end

      _ ->
        Logger.error("tmux not installed. Please install tmux to use session management.")
        {:stop, :tmux_not_found}
    end
  end

  @impl true
  def handle_call({:start_session, context_name, story_id, prompt}, _from, state) do
    session_id = generate_session_id()
    tmux_name = "cms-#{session_id}"

    # Create detached tmux session
    case System.cmd("tmux", [
           "new-session",
           "-d",
           "-s",
           tmux_name,
           "-n",
           context_name
         ]) do
      {_, 0} ->
        # Start Claude in the session
        System.cmd("tmux", [
          "send-keys",
          "-t",
          tmux_name,
          "claude",
          "Enter"
        ])

        # Give it time to initialize
        :timer.sleep(1500)

        # Send the prompt
        System.cmd("tmux", [
          "send-keys",
          "-t",
          tmux_name,
          prompt,
          "Enter"
        ])

        session = %{
          id: session_id,
          tmux_name: tmux_name,
          context_name: context_name,
          story_id: story_id,
          started_at: DateTime.utc_now(),
          status: :running
        }

        new_state = put_in(state.sessions[session_id], session)
        {:reply, {:ok, session}, new_state}

      {error, _code} ->
        {:reply, {:error, error}, state}
    end
  end

  @impl true
  def handle_call(:list_sessions, _from, state) do
    # Could enhance this to check tmux for actual running sessions
    # and sync state
    sessions = Map.values(state.sessions)
    {:reply, {:ok, sessions}, state}
  end

  @impl true
  def handle_call({:get_session, session_id}, _from, state) do
    case Map.get(state.sessions, session_id) do
      nil -> {:reply, {:error, :not_found}, state}
      session -> {:reply, {:ok, session}, state}
    end
  end

  @impl true
  def handle_call({:kill_session, session_id}, _from, state) do
    case Map.get(state.sessions, session_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      session ->
        System.cmd("tmux", ["kill-session", "-t", session.tmux_name])
        new_state = %{state | sessions: Map.delete(state.sessions, session_id)}
        {:reply, :ok, new_state}
    end
  end

  # Helpers

  defp generate_session_id do
    :crypto.strong_rand_bytes(6)
    |> Base.encode16(case: :lower)
  end
end

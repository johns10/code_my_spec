defmodule CodeMySpecCli.Commands.Session do
  @moduledoc """
  Manage Claude Code sessions
  """

  alias CodeMySpecCli.SessionManager

  def list do
    case SessionManager.list_sessions() do
      {:ok, []} ->
        IO.puts("No active sessions")

      {:ok, sessions} ->
        IO.puts("\n📋 Active Sessions:\n")
        Enum.each(sessions, &print_session/1)
    end
  end

  def attach(session_id) do
    IO.puts("🔗 Attaching to #{session_id}...")
    IO.puts("   (Ctrl-B D to detach)")
    :timer.sleep(500)
    SessionManager.attach_to_session(session_id)
  end

  def kill(session_id) do
    case SessionManager.kill_session(session_id) do
      :ok -> IO.puts("✅ Killed #{session_id}")
      {:error, :not_found} -> IO.puts("❌ Not found: #{session_id}")
    end
  end

  defp print_session(s) do
    IO.puts("  #{s.id}")
    IO.puts("    Context: #{s.context_name}")
    IO.puts("    Story: #{s.story_id}")
    IO.puts("    Started: #{format_dt(s.started_at)}")
    IO.puts("    Status: #{s.status}")
    IO.puts("")
  end

  defp format_dt(dt) do
    Calendar.strftime(dt, "%Y-%m-%d %H:%M:%S UTC")
  end
end

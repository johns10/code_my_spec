defmodule CodeMySpecCli.WebServer do
  @moduledoc """
  Local HTTP server for OAuth callbacks.

  This server is started dynamically during OAuth login and stopped afterward.
  It is NOT part of the main supervision tree to avoid port conflicts when
  multiple CLI instances are running.
  """

  require Logger

  alias CodeMySpecCli.WebServer.Config

  @doc """
  Child spec for supervision tree (if needed).
  """
  def child_spec(opts) do
    port = Keyword.get(opts, :port, Config.local_server_port())

    %{
      id: __MODULE__,
      start: {Bandit, :start_link, [[plug: CodeMySpecCli.WebServer.Router, port: port]]},
      type: :worker,
      restart: :permanent
    }
  end

  @doc """
  Start the web server dynamically for OAuth callback handling.
  Returns {:ok, pid} on success or {:error, reason} on failure.
  """
  def start do
    port = Config.local_server_port()

    case Bandit.start_link(plug: CodeMySpecCli.WebServer.Router, port: port) do
      {:ok, pid} ->
        Logger.debug("WebServer started on port #{port}")
        {:ok, pid}

      {:error, {:shutdown, {:failed_to_start_child, :listener, :eaddrinuse}}} ->
        Logger.warning("Port #{port} already in use, WebServer may already be running")
        {:error, :eaddrinuse}

      {:error, reason} ->
        Logger.error("Failed to start WebServer: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Stop a dynamically started web server.
  """
  def stop(pid) when is_pid(pid) do
    Logger.debug("Stopping WebServer")
    GenServer.stop(pid, :normal)
  catch
    :exit, _ -> :ok
  end

  def stop(_), do: :ok
end

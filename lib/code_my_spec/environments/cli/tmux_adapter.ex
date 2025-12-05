defmodule CodeMySpec.Environments.Cli.TmuxAdapter do
  @moduledoc """
  Adapter for tmux operations, enabling Cli environment to be tested without actual tmux dependency.

  This module wraps tmux CLI commands and can be mocked in tests for testability.
  """

  @doc """
  Check if currently running inside a tmux session.

  Returns true if the TMUX environment variable is set and non-empty.
  """
  @spec inside_tmux?() :: boolean()
  def inside_tmux? do
    case System.get_env("TMUX") do
      nil -> false
      "" -> false
      _value -> true
    end
  end

  @doc """
  Get the name of the current tmux session.

  Returns {:ok, session_name} if inside tmux, {:error, reason} otherwise.
  """
  @spec get_current_session() :: {:ok, String.t()} | {:error, term()}
  def get_current_session do
    case System.cmd("tmux", ["display-message", "-p", "\#{session_name}"]) do
      {session, 0} ->
        {:ok, String.trim(session)}

      {error, _code} ->
        {:error, error}
    end
  rescue
    error -> {:error, error}
  end

  @doc """
  Create a new tmux window with specified name.

  Returns {:ok, window_id} on success, {:error, reason} on failure.
  """
  @spec create_window(window_name :: String.t()) :: {:ok, String.t()} | {:error, term()}
  def create_window(window_name) do
    with {:ok, session} <- get_current_session() do
      case System.cmd("tmux", [
        "new-window",
        "-t",
        session,
        "-n",
        window_name,
        "-d",
        # Don't switch to it
        "-P",
        "-F",
        "\#{window_id}"
      ]) do
        {window_id, 0} ->
          {:ok, String.trim(window_id)}

        {error, _code} ->
          {:error, error}
      end
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Kill/close a tmux window by name.

  Returns :ok on success, even if the window doesn't exist (idempotent).
  Returns {:error, reason} only for actual tmux failures.
  """
  @spec kill_window(window_name :: String.t()) :: :ok | {:error, term()}
  def kill_window(window_name) do
    with {:ok, session} <- get_current_session() do
      case System.cmd("tmux", ["kill-window", "-t", "#{session}:#{window_name}"]) do
        {_output, 0} ->
          :ok

        # Window doesn't exist - that's fine (idempotent)
        {error, _code} when is_binary(error) ->
          if String.contains?(error, "can't find window") or
               String.contains?(error, "no such window") do
            :ok
          else
            {:error, error}
          end

        {error, _code} ->
          {:error, error}
      end
    else
      {:error, _reason} -> :ok
    end
  end

  @doc """
  Send a command string to a tmux window.

  The command will be sent followed by Enter (C-m) to execute it.
  Returns :ok on success, {:error, reason} on failure.
  """
  @spec send_keys(window_name :: String.t(), command :: String.t()) :: :ok | {:error, term()}
  def send_keys(window_name, command) do
    with {:ok, session} <- get_current_session() do
      case System.cmd("tmux", [
        "send-keys",
        "-t",
        "#{session}:#{window_name}",
        command,
        "C-m"
      ]) do
        {_output, 0} ->
          :ok

        {error, _code} ->
          {:error, error}
      end
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Check if a tmux window exists by name.

  Returns true if the window exists, false otherwise.
  """
  @spec window_exists?(window_name :: String.t()) :: boolean()
  def window_exists?(window_name) do
    with {:ok, session} <- get_current_session() do
      case System.cmd("tmux", [
        "list-windows",
        "-t",
        session,
        "-F",
        "\#{window_name}"
      ]) do
        {output, 0} ->
          output
          |> String.trim()
          |> String.split("\n")
          |> Enum.any?(&(&1 == window_name))

        {_error, _code} ->
          false
      end
    else
      {:error, _} -> false
    end
  rescue
    _error -> false
  end
end
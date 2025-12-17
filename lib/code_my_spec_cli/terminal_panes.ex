defmodule CodeMySpecCli.TerminalPanes do
  @moduledoc """
  Manages a single terminal pane for visualizing CLI-bound session commands.

  Only displays when a session has terminal-bound commands (currently only "claude" commands).
  """

  alias CodeMySpec.Environments.Cli.TmuxAdapter
  require Logger

  @pane_title_prefix "terminal-session-"

  # Allow adapter injection for testing
  defp adapter do
    Application.get_env(:code_my_spec, :tmux_adapter, TmuxAdapter)
  end

  @doc """
  Show the terminal pane for a specific session.

  If the terminal is already open, this updates it to show the new session.
  If the terminal is already showing this session, this is a no-op.

  Returns :ok on success, {:error, reason} on failure.
  """
  @spec show_terminal(session_id :: integer()) :: :ok | {:error, term()}
  def show_terminal(session_id) do
    unless adapter().inside_tmux?() do
      {:error, "Not running inside tmux"}
    else
      case current_session() do
        {:ok, ^session_id} ->
          # Already showing this session
          :ok

        {:ok, _other_session} ->
          # Update pane title to new session
          update_terminal_session(session_id)

        {:error, :not_open} ->
          # Create new terminal pane
          create_terminal_pane(session_id)
      end
    end
  end

  @doc """
  Hide/close the terminal pane.

  Breaks the pane back into its session window.
  This function is idempotent - returns :ok even if the pane doesn't exist.
  """
  @spec hide_terminal() :: :ok | {:error, term()}
  def hide_terminal do
    case find_terminal_pane() do
      {:ok, pane_id} ->
        # Get the session_id from the pane title to restore window name
        case current_session() do
          {:ok, session_id} ->
            window_name = "session-#{session_id}"

            case adapter().break_pane(pane_id, window_name: window_name) do
              :ok ->
                Logger.info("Broke terminal pane back to window #{window_name}")
                :ok

              error ->
                error
            end

          {:error, _} ->
            # If we can't get session_id, just break without window name
            adapter().break_pane(pane_id)
        end

      {:error, :not_found} ->
        :ok
    end
  end

  @doc """
  Check if the terminal pane is currently open.

  Returns true if the terminal exists, false otherwise.
  """
  @spec terminal_open?() :: boolean()
  def terminal_open? do
    case find_terminal_pane() do
      {:ok, _pane_id} -> true
      {:error, :not_found} -> false
    end
  end

  @doc """
  Get the session_id currently displayed in the terminal.

  Returns {:ok, session_id} if terminal is open, {:error, :not_open} otherwise.
  """
  @spec current_session() :: {:ok, integer()} | {:error, :not_open}
  def current_session do
    case find_terminal_pane() do
      {:ok, pane_id} ->
        case adapter().get_pane_property(pane_id, "\#{pane_title}") do
          {:ok, title} ->
            parse_session_from_title(title)

          {:error, _} ->
            {:error, :not_open}
        end

      {:error, :not_found} ->
        {:error, :not_open}
    end
  end

  # Private functions

  defp create_terminal_pane(session_id) do
    window_name = "session-#{session_id}"

    # Ensure window exists before trying to join it
    # This handles the case where user opens terminal before running commands
    with :ok <- ensure_window_exists(window_name),
         {:ok, pane_id} <- adapter().join_pane(window_name, direction: "-v", size: "50%") do
      title = pane_title(session_id)

      # Set pane title to track which session this is
      adapter().set_pane_title(pane_id, title)

      Logger.info("Joined terminal pane from window #{window_name}")
      :ok
    else
      {:error, reason} ->
        Logger.error(
          "Failed to create/join terminal pane for window #{window_name}: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  defp ensure_window_exists(window_name) do
    unless adapter().window_exists?(window_name) do
      case adapter().create_window(window_name) do
        {:ok, _} ->
          Logger.debug("Created window #{window_name} for terminal display")
          :ok

        {:error, reason} ->
          {:error, reason}
      end
    else
      :ok
    end
  end

  defp update_terminal_session(session_id) do
    case find_terminal_pane() do
      {:ok, pane_id} ->
        title = pane_title(session_id)

        case adapter().set_pane_title(pane_id, title) do
          :ok ->
            Logger.info("Updated terminal to show session #{session_id}")
            :ok

          error ->
            error
        end

      error ->
        error
    end
  end

  defp find_terminal_pane do
    unless adapter().inside_tmux?() do
      {:error, :not_found}
    else
      with {:ok, session} <- adapter().get_current_session(),
           {:ok, output} <- adapter().list_panes("#{session}:0", "\#{pane_id}:\#{pane_title}") do
        panes =
          output
          |> String.trim()
          |> String.split("\n")
          |> Enum.map(fn line ->
            case String.split(line, ":", parts: 2) do
              [pane_id, pane_title] -> {pane_id, pane_title}
              _ -> {nil, nil}
            end
          end)

        case Enum.find(panes, fn {_id, title} ->
               String.starts_with?(title || "", @pane_title_prefix)
             end) do
          {pane_id, _} when not is_nil(pane_id) -> {:ok, pane_id}
          _ -> {:error, :not_found}
        end
      else
        _ -> {:error, :not_found}
      end
    end
  end

  defp pane_title(session_id), do: "#{@pane_title_prefix}#{session_id}"

  defp parse_session_from_title(title) do
    if String.starts_with?(title, @pane_title_prefix) do
      session_id_str = String.replace_prefix(title, @pane_title_prefix, "")

      case Integer.parse(session_id_str) do
        {session_id, ""} -> {:ok, session_id}
        _ -> {:error, :not_open}
      end
    else
      {:error, :not_open}
    end
  end
end

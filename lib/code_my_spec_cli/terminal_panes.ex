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
        Logger.info("Found terminal pane: #{pane_id}")

        # Get the session_id from the pane title to restore window name
        case current_session() do
          {:ok, session_id} ->
            window_name = "session-#{session_id}"
            Logger.info("Attempting to break pane back to window: #{window_name}")

            # Break pane to new window with the session name
            case adapter().break_pane(pane_id, window_name: window_name) do
              :ok ->
                Logger.info("Broke terminal pane back to window #{window_name}")
                :ok

              {:error, reason} ->
                Logger.error("Failed to hide terminal: #{inspect(reason)}")
                {:error, reason}
            end

          {:error, reason} ->
            Logger.warning("Could not get current session: #{inspect(reason)}")
            {:error, reason}
        end

      {:error, :not_found} ->
        Logger.info("No terminal pane found to hide")
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

      # Enable mouse mode for scrolling
      adapter().enable_mouse_mode()

      Logger.info("Joined terminal pane from window #{window_name} (mouse mode enabled)")
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
    exists = adapter().window_exists?(window_name)
    Logger.info("Window #{window_name} exists? #{exists}")

    unless exists do
      case adapter().create_window(window_name) do
        {:ok, window_id} ->
          Logger.info("Created window #{window_name} with ID #{window_id} for terminal display")
          :ok

        {:error, reason} ->
          Logger.error("Failed to create window #{window_name}: #{inspect(reason)}")
          {:error, reason}
      end
    else
      # Window exists - let's verify it has panes
      with {:ok, session} <- adapter().get_current_session(),
           target = "#{session}:#{window_name}",
           {:ok, panes_output} <- adapter().list_panes(target, "\#{pane_id}") do
        panes = panes_output |> String.trim() |> String.split("\n")
        Logger.info("Window #{window_name} has #{length(panes)} pane(s): #{inspect(panes)}")
        :ok
      else
        {:error, reason} ->
          Logger.warning("Could not list panes for window #{window_name}: #{inspect(reason)}")
          :ok
      end
    end
  end

  defp update_terminal_session(session_id) do
    Logger.debug("Switching terminal from current session to session #{session_id}")

    # Break current pane back to its window, then create new pane from new session
    with :ok <- hide_terminal(),
         :ok <- create_terminal_pane(session_id) do
      Logger.info("Switched terminal to show session #{session_id}")
      :ok
    else
      {:error, reason} = error ->
        Logger.error("Failed to switch terminal to session #{session_id}: #{inspect(reason)}")
        error
    end
  end

  defp find_terminal_pane do
    unless adapter().inside_tmux?() do
      {:error, :not_found}
    else
      with {:ok, session} <- adapter().get_current_session(),
           # Search across all windows by using just the session name (no window specifier)
           {:ok, output} <- adapter().list_panes(session, "\#{pane_id}:\#{pane_title}") do
        Logger.info(inspect(output))

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

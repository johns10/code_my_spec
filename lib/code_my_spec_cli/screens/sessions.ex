defmodule CodeMySpecCli.Screens.Sessions do
  @moduledoc """
  Sessions screen for Ratatouille.

  Displays a list of active sessions with navigation and actions.
  Allows viewing session details, opening terminal, closing terminal pane, destroying terminal windows, and deleting sessions.
  """

  import Ratatouille.View
  import Ratatouille.Constants, only: [key: 1]
  require Logger

  alias CodeMySpec.Sessions
  alias CodeMySpec.Sessions.{Interaction, InteractionRegistry}
  alias CodeMySpec.Users.Scope
  alias CodeMySpecCli.TerminalPanes

  # Key code constants
  @arrow_up key(:arrow_up)
  @arrow_down key(:arrow_down)
  @enter key(:enter)
  @esc key(:esc)

  defstruct [
    :scope,
    :sessions,
    :selected_session_index,
    :error_message,
    :terminal_session_id,
    :tick_count
  ]

  @type t :: %__MODULE__{
          scope: Scope.t() | nil,
          sessions: [Sessions.Session.t()],
          selected_session_index: integer(),
          error_message: String.t() | nil,
          terminal_session_id: integer() | nil,
          tick_count: integer()
        }

  @doc """
  Initialize the sessions list screen.
  """
  @spec init() :: {t(), nil}
  def init do
    scope = Scope.for_cli()

    if is_nil(scope) do
      state = %__MODULE__{
        scope: nil,
        sessions: [],
        selected_session_index: 0,
        error_message: "No active project found. Run /init to initialize a project.",
        terminal_session_id: nil,
        tick_count: 0
      }

      {state, nil}
    else
      # Load active sessions
      sessions =
        Sessions.list_sessions(scope, status: [:active])
        |> Enum.sort_by(& &1.inserted_at, {:desc, DateTime})

      state = %__MODULE__{
        scope: scope,
        sessions: sessions,
        selected_session_index: 0,
        error_message: nil,
        terminal_session_id: nil,
        tick_count: 0
      }

      {state, nil}
    end
  end

  @doc """
  Handle keyboard input and system messages.
  """
  @spec update(t(), term()) :: {:ok, t()} | {:switch_screen, atom(), t()}
  def update(model, msg) do
    case msg do
      # Tick - poll for session updates every 10 ticks (1 second)
      :tick ->
        model = check_and_cleanup_terminal(model)
        new_tick_count = model.tick_count + 1

        if rem(new_tick_count, 5) == 0 && model.scope do
          # Refetch sessions
          sessions =
            Sessions.list_sessions(model.scope, status: [:active])
            |> Enum.sort_by(& &1.inserted_at, {:desc, DateTime})

          # Preserve selected_session_index, but ensure it's still valid
          new_index =
            if model.selected_session_index >= length(sessions) do
              max(0, length(sessions) - 1)
            else
              model.selected_session_index
            end

          {:ok,
           %{
             model
             | sessions: sessions,
               selected_session_index: new_index,
               tick_count: new_tick_count
           }}
        else
          {:ok, %{model | tick_count: new_tick_count}}
        end

      # Arrow key navigation
      {:event, %{key: @arrow_up}} ->
        handle_arrow_up(model)

      {:event, %{key: @arrow_down}} ->
        handle_arrow_down(model)

      # Enter key - view session detail
      {:event, %{key: @enter}} ->
        handle_enter(model)

      # 'n' key - execute next command
      {:event, %{ch: ?n}} ->
        handle_execute_next(model)

      # 't' key - open terminal
      {:event, %{ch: ?t}} ->
        handle_open_terminal(model)

      # 'c' key - close terminal pane
      {:event, %{ch: ?c}} ->
        handle_close_terminal_pane(model)

      # 'd' key - delete session
      {:event, %{ch: ?d}} ->
        handle_delete_session(model)

      # 'k' key - kill/destroy terminal window
      {:event, %{ch: ?k}} ->
        handle_destroy_terminal(model)

      # Esc key - exit
      {:event, %{key: @esc}} ->
        handle_exit(model)

      _ ->
        {:ok, model}
    end
  end

  # Private update handlers

  defp handle_arrow_up(model) do
    new_index = max(0, model.selected_session_index - 1)
    {:ok, %{model | selected_session_index: new_index}}
  end

  defp handle_arrow_down(model) do
    new_index = min(length(model.sessions) - 1, model.selected_session_index + 1)
    {:ok, %{model | selected_session_index: new_index}}
  end

  defp handle_enter(model) do
    if length(model.sessions) > 0 and model.selected_session_index < length(model.sessions) do
      # Switch to session detail screen
      {:switch_screen, :session_detail, model}
    else
      {:ok, model}
    end
  end

  defp handle_execute_next(model) do
    if length(model.sessions) > 0 and model.selected_session_index < length(model.sessions) do
      session = Enum.at(model.sessions, model.selected_session_index)

      case Sessions.execute(model.scope, session.id) do
        {:ok, updated_session} ->
          # Update the session in the list
          new_sessions =
            model.sessions
            |> Enum.map(fn s -> if s.id == updated_session.id, do: updated_session, else: s end)
            |> sort_sessions()

          {:ok, %{model | sessions: new_sessions, error_message: nil}}

        {:error, :interaction_pending} ->
          {:ok, %{model | error_message: "Session has pending interaction"}}

        {:error, :session_complete} ->
          {:ok, %{model | error_message: "Session is already complete"}}

        {:error, reason} ->
          {:ok, %{model | error_message: "Failed to execute: #{inspect(reason)}"}}
      end
    else
      {:ok, model}
    end
  end

  defp handle_open_terminal(model) do
    if length(model.sessions) > 0 and model.selected_session_index < length(model.sessions) do
      session = Enum.at(model.sessions, model.selected_session_index)

      case TerminalPanes.show_terminal(session.id) do
        :ok ->
          {:ok, %{model | terminal_session_id: session.id, error_message: nil}}

        {:error, reason} ->
          {:ok, %{model | error_message: "Failed to open terminal: #{inspect(reason)}"}}
      end
    else
      {:ok, model}
    end
  end

  defp handle_close_terminal_pane(model) do
    if model.terminal_session_id do
      case TerminalPanes.hide_terminal() do
        :ok ->
          {:ok, %{model | terminal_session_id: nil, error_message: nil}}

        {:error, reason} ->
          {:ok, %{model | error_message: "Failed to close terminal pane: #{inspect(reason)}"}}
      end
    else
      {:ok, %{model | error_message: "No terminal pane is currently open"}}
    end
  end

  defp handle_delete_session(model) do
    if length(model.sessions) > 0 and model.selected_session_index < length(model.sessions) do
      session = Enum.at(model.sessions, model.selected_session_index)

      case Sessions.delete_session(model.scope, session) do
        {:ok, _} ->
          # Remove session from list
          new_sessions = Enum.reject(model.sessions, &(&1.id == session.id))

          # Adjust selection if needed
          new_index =
            if model.selected_session_index >= length(new_sessions) do
              max(0, length(new_sessions) - 1)
            else
              model.selected_session_index
            end

          {:ok, %{model | sessions: new_sessions, selected_session_index: new_index}}

        {:error, reason} ->
          {:ok, %{model | error_message: "Failed to delete session: #{inspect(reason)}"}}
      end
    else
      {:ok, model}
    end
  end

  defp handle_destroy_terminal(model) do
    if length(model.sessions) > 0 and model.selected_session_index < length(model.sessions) do
      session = Enum.at(model.sessions, model.selected_session_index)

      # Construct Environment struct for CLI with the session's window name
      env = %CodeMySpec.Environments.Environment{
        type: :cli,
        ref: "session-#{session.id}",
        metadata: %{}
      }

      # Destroy the terminal window
      case CodeMySpec.Environments.destroy(env) do
        :ok ->
          # Also clear terminal_session_id if this was the open terminal
          updated_model =
            if model.terminal_session_id == session.id do
              %{model | terminal_session_id: nil}
            else
              model
            end

          {:ok, %{updated_model | error_message: nil}}

        {:error, reason} ->
          {:ok, %{model | error_message: "Failed to destroy terminal: #{inspect(reason)}"}}
      end
    else
      {:ok, model}
    end
  end

  defp handle_exit(model) do
    # Close terminal if open
    if model.terminal_session_id do
      TerminalPanes.hide_terminal()
    end

    {:switch_screen, :repl, model}
  end

  @doc """
  Render the sessions list screen.
  """
  @spec render(t()) :: term()
  def render(model) do
    # Check and cleanup terminal if session ended
    session_count = length(model.sessions)

    [
      # Header row
      row do
        column(size: 12) do
          panel(title: "Active Sessions (#{session_count})") do
            [
              # Flash message if error
              if model.error_message do
                label(content: "⚠ #{model.error_message}", color: :red, attributes: [:bold])
              end,
              # Instructions
              label(
                content:
                  "↑/↓: navigate | Enter: details | n: next cmd | t: terminal | c: close pane | d: delete | k: kill | Esc: exit",
                color: :cyan
              )
            ]
          end
        end
      end,
      # Sessions list row
      row do
        column(size: 12) do
          panel(title: "Sessions", height: :fill) do
            if session_count == 0 do
              label(
                content: "No active sessions. Create a session from the components browser.",
                color: :yellow
              )
            else
              viewport do
                for {session, index} <- Enum.with_index(model.sessions) do
                  render_session_item(session, index == model.selected_session_index)
                end
              end
            end
          end
        end
      end
    ]
  end

  # Render a session list item
  defp render_session_item(session, is_selected) do
    prefix = if is_selected, do: "▶ ", else: "  "

    session_type_name =
      session.type
      |> Atom.to_string()
      |> String.split(".")
      |> List.last()
      |> Inflex.singularize()
      |> Recase.to_sentence()
      |> String.replace("session", "")
      |> String.trim()

    interaction_command_name =
      session
      |> Map.get(:interactions)
      |> List.first()
      |> case do
        nil ->
          ""

        interaction = %{} ->
          interaction
          |> Map.get(:command)
          |> Map.get(:module)
          |> Atom.to_string()
          |> String.split(".")
          |> List.last()
          |> Inflex.singularize()
          |> Recase.to_sentence()
      end

    component_name =
      with {:ok, %{} = component} <- Map.fetch(session, :component),
           {:ok, name} <- Map.fetch(component, :name) do
        name
      else
        _ -> "component no longer exists"
      end

    display_name =
      "#{session_type_name} for #{component_name} (#{interaction_command_name})"

    status_color = status_color(session.status)

    # Get current step name from pending interaction
    pending_interaction =
      Enum.find(session.interactions, fn interaction ->
        Interaction.pending?(interaction)
      end)

    step_info =
      if pending_interaction && pending_interaction.step_name do
        " - #{pending_interaction.step_name}"
      else
        ""
      end

    # Get runtime status indicator
    {indicator, indicator_color} = get_runtime_status_indicator(session)

    # Build prefix with indicator
    prefix_with_indicator =
      if indicator do
        "#{prefix}#{indicator} "
      else
        prefix
      end

    label do
      text(
        content: prefix_with_indicator,
        attributes: if(is_selected, do: [:bold], else: []),
        color: indicator_color || :white
      )

      text(
        content: display_name,
        attributes: if(is_selected, do: [:bold], else: []),
        color: if(is_selected, do: :cyan, else: :white)
      )

      text(content: " [#{session.status}]", color: status_color)

      if step_info != "" do
        text(content: step_info, color: :yellow)
      end
    end
  end

  # Helper functions

  # Check if terminal session has ended and cleanup if needed
  defp check_and_cleanup_terminal(model) do
    if model.terminal_session_id && model.scope do
      terminal_session = Sessions.get_session(model.scope, model.terminal_session_id)

      case {terminal_session, terminal_session && session_ended?(terminal_session)} do
        # Session not found - close pane and clear ID
        {nil, _} ->
          Logger.info("Terminal session #{model.terminal_session_id} not found, closing pane")
          TerminalPanes.hide_terminal()
          %{model | terminal_session_id: nil}

        # Session ended - close pane, destroy window, clear ID
        {_session, true} ->
          Logger.info("Session #{model.terminal_session_id} ended, closing terminal pane")
          TerminalPanes.hide_terminal()
          %{model | terminal_session_id: nil}

        # Session still active - no changes
        {_session, false} ->
          model
      end
    else
      # No terminal session open or no scope - no changes
      model
    end
  end

  # Check if a session has ended by looking at its RuntimeInteraction state
  defp session_ended?(%{interactions: []}), do: :ok

  defp session_ended?(%{interactions: [latest_interaction | _]}) do
    case InteractionRegistry.get_status(latest_interaction.id) do
      {:ok, runtime} ->
        runtime.agent_state == "ended"

      {:error, :not_found} ->
        false
    end
  end

  defp status_color(:active), do: :green
  defp status_color(:complete), do: :blue
  defp status_color(:failed), do: :red
  defp status_color(:cancelled), do: :yellow
  defp status_color(_), do: :white

  defp sort_sessions(sessions) do
    Enum.sort_by(sessions, & &1.inserted_at, {:desc, DateTime})
  end

  # Get runtime status indicator for a session's pending interaction.
  # Returns a tuple of {indicator, color} based on RuntimeInteraction data.
  defp get_runtime_status_indicator(session) do
    # Find pending interaction
    pending_interaction =
      Enum.find(session.interactions, fn interaction ->
        Interaction.pending?(interaction)
      end)

    case pending_interaction do
      nil ->
        {nil, nil}

      interaction ->
        case InteractionRegistry.get_status(interaction.id) do
          {:ok, runtime} ->
            compute_status_indicator(runtime)

          {:error, :not_found} ->
            # No runtime data yet - show default indicator for active sessions
            if session.status == :active do
              {"○", :white}
            else
              {nil, nil}
            end
        end
    end
  end

  defp compute_status_indicator(runtime) do
    now = DateTime.utc_now()

    # Check for notification (highest priority)
    notification_timestamp = get_timestamp(runtime.last_notification)

    if notification_timestamp &&
         is_most_recent?(notification_timestamp, [
           get_timestamp(runtime.last_activity),
           get_timestamp(runtime.last_stopped)
         ]) do
      {"🔔", :yellow}
    else
      # Check for stopped/idle state
      stopped_timestamp = get_timestamp(runtime.last_stopped)

      if stopped_timestamp &&
           is_most_recent?(stopped_timestamp, [
             get_timestamp(runtime.last_activity)
           ]) do
        {"⏸", :cyan}
      else
        # Check activity recency
        activity_timestamp = get_timestamp(runtime.last_activity)

        if activity_timestamp do
          seconds_since_activity = DateTime.diff(now, activity_timestamp, :second)

          if seconds_since_activity <= 5 do
            {"●", :green}
          else
            {"○", :white}
          end
        else
          {nil, nil}
        end
      end
    end
  end

  defp get_timestamp(nil), do: nil

  defp get_timestamp(%{"timestamp" => timestamp}) when is_binary(timestamp) do
    case DateTime.from_iso8601(timestamp) do
      {:ok, dt, _} -> dt
      _ -> nil
    end
  end

  defp get_timestamp(%{timestamp: %DateTime{} = dt}), do: dt
  defp get_timestamp(%{"timestamp" => %DateTime{} = dt}), do: dt
  defp get_timestamp(_), do: nil

  defp is_most_recent?(timestamp, other_timestamps) do
    other_timestamps
    |> Enum.reject(&is_nil/1)
    |> Enum.all?(fn other -> DateTime.compare(timestamp, other) in [:gt, :eq] end)
  end
end

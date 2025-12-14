defmodule CodeMySpecCli.Screens.Sessions do
  @moduledoc """
  Sessions screen for Ratatouille.

  Displays a list of active sessions with navigation and actions.
  Allows viewing session details, opening terminal, and deleting sessions.
  """

  import Ratatouille.View
  import Ratatouille.Constants, only: [key: 1]

  alias CodeMySpec.Sessions
  alias CodeMySpec.Sessions.{Command, Interaction}
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
    :terminal_session_id
  ]

  @type t :: %__MODULE__{
          scope: Scope.t() | nil,
          sessions: [Sessions.Session.t()],
          selected_session_index: integer(),
          error_message: String.t() | nil,
          terminal_session_id: integer() | nil
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
        terminal_session_id: nil
      }

      {state, nil}
    else
      # Subscribe to session changes
      Sessions.subscribe_user_sessions(scope)

      # Load active sessions
      sessions =
        Sessions.list_sessions(scope, status: [:active])
        |> Enum.sort_by(& &1.inserted_at, {:desc, DateTime})

      state = %__MODULE__{
        scope: scope,
        sessions: sessions,
        selected_session_index: 0,
        error_message: nil,
        terminal_session_id: nil
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

      # 'd' key - delete session
      {:event, %{ch: ?d}} ->
        handle_delete_session(model)

      # 'q' or Esc key - exit
      {:event, %{ch: ?q}} ->
        handle_exit(model)

      {:event, %{key: @esc}} ->
        handle_exit(model)

      # PubSub messages for session updates
      {:created, session} ->
        new_sessions = [session | model.sessions] |> sort_sessions()
        {:ok, %{model | sessions: new_sessions}}

      {:updated, session} ->
        new_sessions =
          model.sessions
          |> Enum.map(fn s -> if s.id == session.id, do: session, else: s end)
          |> sort_sessions()

        {:ok, %{model | sessions: new_sessions}}

      {:deleted, session} ->
        new_sessions = Enum.reject(model.sessions, &(&1.id == session.id))

        # Adjust selection if needed
        new_index =
          if model.selected_session_index >= length(new_sessions) do
            max(0, length(new_sessions) - 1)
          else
            model.selected_session_index
          end

        {:ok, %{model | sessions: new_sessions, selected_session_index: new_index}}

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

      # Check if session has any interactions with terminal-bound commands
      has_terminal_commands? =
        session.interactions
        |> Enum.any?(fn interaction ->
          interaction.command && Command.runs_in_terminal?(interaction.command)
        end)

      if has_terminal_commands? do
        case TerminalPanes.show_terminal(session.id) do
          :ok ->
            {:ok, %{model | terminal_session_id: session.id, error_message: nil}}

          {:error, reason} ->
            {:ok, %{model | error_message: "Failed to open terminal: #{inspect(reason)}"}}
        end
      else
        {:ok, %{model | error_message: "Session has no terminal commands"}}
      end
    else
      {:ok, model}
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
                content: "↑/↓: navigate | Enter: details | n: next cmd | t: terminal | d: delete | q: exit",
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
    display_name = session.display_name || "Session ##{session.id}"
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

    label do
      text(content: prefix, attributes: if(is_selected, do: [:bold], else: []))

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

  defp status_color(:active), do: :green
  defp status_color(:complete), do: :blue
  defp status_color(:failed), do: :red
  defp status_color(:cancelled), do: :yellow
  defp status_color(_), do: :white

  defp sort_sessions(sessions) do
    Enum.sort_by(sessions, & &1.inserted_at, {:desc, DateTime})
  end
end

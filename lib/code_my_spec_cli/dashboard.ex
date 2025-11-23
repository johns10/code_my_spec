defmodule CodeMySpecCli.Dashboard do
  @moduledoc """
  Interactive TUI dashboard using Ratatouille

  Shows active Claude Code sessions and allows interaction.
  """

  @behaviour Ratatouille.App

  import Ratatouille.View
  import Ratatouille.Constants, only: [key: 1]

  alias CodeMySpecCli.SessionManager

  def init(_context) do
    %{
      selected: 0,
      sessions: [],
      last_update: DateTime.utc_now()
    }
  end

  def update(model, msg) do
    case msg do
      {:event, %{ch: ?q}} ->
        exit(:normal)

      {:event, %{ch: ?a}} ->
        # Attach to selected
        session = Enum.at(model.sessions, model.selected)

        if session do
          # Exit TUI and attach
          spawn(fn ->
            :timer.sleep(100)
            SessionManager.attach_to_session(session.id)
          end)

          exit(:normal)
        end

        model

      {:event, %{key: key}} when key in [key(:arrow_up), ?k] ->
        %{model | selected: max(model.selected - 1, 0)}

      {:event, %{key: key}} when key in [key(:arrow_down), ?j] ->
        max_idx = max(length(model.sessions) - 1, 0)
        %{model | selected: min(model.selected + 1, max_idx)}

      :refresh ->
        {:ok, sessions} = SessionManager.list_sessions()
        %{model | sessions: sessions, last_update: DateTime.utc_now()}

      _ ->
        model
    end
  end

  def render(model) do
    view do
      panel title: "CodeMySpec Dashboard - [a]ttach | [q]uit", height: :fill do
        if Enum.empty?(model.sessions) do
          label(content: "No active sessions")
          label(content: "")
          label(content: "Start a session with: codemyspec generate <story_ids>")
        else
          render_table(model)
        end
      end

      panel title: "Controls" do
        label(content: "j/↓: Down | k/↑: Up | a: Attach to session | q: Quit")
      end

      panel title: "Status" do
        label(content: "Last update: #{format_time(model.last_update)}")
      end
    end
  end

  defp render_table(model) do
    table do
      table_row do
        table_cell(content: "ID")
        table_cell(content: "Context")
        table_cell(content: "Story")
        table_cell(content: "Status")
        table_cell(content: "Age")
      end

      model.sessions
      |> Enum.with_index()
      |> Enum.map(fn {session, idx} ->
        selected? = idx == model.selected
        prefix = if selected?, do: "→ ", else: "  "

        table_row do
          table_cell(content: prefix <> String.slice(session.id, 0..7))
          table_cell(content: session.context_name)
          table_cell(content: session.story_id)
          table_cell(content: to_string(session.status))
          table_cell(content: age(session.started_at))
        end
      end)
    end
  end

  defp age(dt) do
    diff = DateTime.diff(DateTime.utc_now(), dt, :second)

    cond do
      diff < 60 -> "#{diff}s"
      diff < 3600 -> "#{div(diff, 60)}m"
      true -> "#{div(diff, 3600)}h"
    end
  end

  defp format_time(dt) do
    Calendar.strftime(dt, "%H:%M:%S")
  end
end

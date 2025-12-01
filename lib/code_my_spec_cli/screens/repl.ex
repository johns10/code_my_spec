defmodule CodeMySpecCli.Screens.Repl do
  @moduledoc """
  REPL screen - command prompt interface.
  """

  import Ratatouille.View
  import Ratatouille.Constants, only: [key: 1]

  alias CodeMySpecCli.Commands.Registry, as: CommandRegistry
  alias CodeMySpecCli.Components.AuthStatus
  alias CodeMySpecCli.Components.ProjectStatus
  alias CodeMySpecCli.Components.FileSyncStatus

  defstruct [:input, :history, :output_lines]

  @doc """
  Initialize the REPL state.
  """
  def init do
    %__MODULE__{
      input: "",
      history: [],
      output_lines: []
    }
  end

  @doc """
  Update the REPL state based on messages.
  Returns {:ok, new_state} or {:switch_screen, screen_name, new_state}.
  """
  def update(state, msg) do
    case msg do
      {:event, %{ch: ch}} when ch > 0 ->
        {:ok, %{state | input: state.input <> <<ch::utf8>>}}

      {:event, %{key: k}} ->
        cond do
          k == key(:backspace) or k == key(:backspace2) ->
            {:ok, %{state | input: String.slice(state.input, 0..-2//1)}}

          k == key(:enter) ->
            handle_command(state)

          true ->
            {:ok, state}
        end

      _ ->
        {:ok, state}
    end
  end

  @doc """
  Render the REPL screen.
  """
  def render(state) do
    [
      # Status bar
      row do
        column(size: 12) do
          panel(title: "Status") do
            AuthStatus.render()
            ProjectStatus.render()
          end
        end
      end,

      # Command history area
      row do
        column(size: 12) do
          panel(title: "Output", height: :fill) do
            viewport do
              if Enum.empty?(state.output_lines) do
                label(content: "Type /help to see available commands.")
              else
                for line <- Enum.take(state.output_lines, -20) do
                  label(content: line)
                end
              end
            end
          end
        end
      end,

      # Prompt
      row do
        column(size: 12) do
          label do
            text(content: "> ", color: :cyan, attributes: [:bold])
            text(content: state.input)
            text(content: "_")
          end
        end
      end
    ]
  end

  defp handle_command(state) do
    input = String.trim(state.input)

    if input == "" do
      {:ok, %{state | input: ""}}
    else
      case CommandRegistry.execute(input) do
        :ok ->
          output = ["> #{input}" | state.output_lines]
          {:ok, %{state | input: "", output_lines: output, history: [input | state.history]}}

        {:ok, message} ->
          output = [message, "> #{input}" | state.output_lines]
          {:ok, %{state | input: "", output_lines: output, history: [input | state.history]}}

        {:switch_screen, screen} ->
          # Command wants to switch screens
          output = ["> #{input}" | state.output_lines]
          new_state = %{state | input: "", output_lines: output, history: [input | state.history]}
          {:switch_screen, screen, new_state}

        :exit ->
          # Signal exit
          System.halt(0)
          {:ok, state}

        {:error, message} ->
          output = ["Error: #{message}", "> #{input}" | state.output_lines]
          {:ok, %{state | input: "", output_lines: output, history: [input | state.history]}}
      end
    end
  end
end
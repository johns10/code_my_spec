defmodule CodeMySpecCli.Screens.Main do
  @moduledoc """
  Main REPL screen with status and command prompt.
  """
  @behaviour Ratatouille.App

  import Ratatouille.View
  import Ratatouille.Constants, only: [key: 1]

  alias CodeMySpecCli.Commands.Registry, as: CommandRegistry
  alias CodeMySpecCli.Auth.OAuthClient
  alias CodeMySpec.Users.Scope

  defstruct [:input, :history, :output_lines, :authenticated, :project_name]

  @impl true
  def init(_context) do
    # Get initial auth and project status
    authenticated = OAuthClient.authenticated?()
    scope = Scope.for_cli()
    project_name = if scope && scope.active_project, do: scope.active_project.name, else: nil

    %__MODULE__{
      input: "",
      history: [],
      output_lines: [],
      authenticated: authenticated,
      project_name: project_name
    }
  end

  @impl true
  def update(model, msg) do
    case msg do
      {:event, %{ch: ch}} when ch > 0 ->
        # Regular character input
        %{model | input: model.input <> <<ch::utf8>>}

      {:event, %{key: k}} ->
        cond do
          k == key(:backspace) or k == key(:backspace2) ->
            # Backspace
            %{model | input: String.slice(model.input, 0..-2//1)}

          k == key(:enter) ->
            # Process command
            handle_command(model)

          true ->
            model
        end

      _ ->
        model
    end
  end

  @impl true
  def render(model) do
    view do
      panel(title: "CodeMySpec", height: :fill) do
        # Status bar
        row do
          column(size: 12) do
            panel(title: "Status") do
              label do
                text(content: "Auth: ")

                text(
                  content: if(model.authenticated, do: "✓ Logged in", else: "✗ Not logged in"),
                  color: if(model.authenticated, do: :green, else: :red)
                )
              end

              label do
                text(content: "Project: ")

                if model.project_name do
                  text(content: "✓ #{model.project_name}", color: :green)
                else
                  text(content: "✗ Not initialized", color: :red)
                end
              end
            end
          end
        end

        # Command history area
        row do
          column(size: 12) do
            panel(title: "Output", height: :fill) do
              viewport do
                if Enum.empty?(model.output_lines) do
                  label(content: "Type /help to see available commands.")
                else
                  for line <- Enum.take(model.output_lines, -20) do
                    label(content: line)
                  end
                end
              end
            end
          end
        end

        # Prompt
        row do
          column(size: 12) do
            label do
              text(content: "> ", color: :cyan, attributes: [:bold])
              text(content: model.input)
              text(content: "_")
            end
          end
        end
      end
    end
  end

  defp handle_command(model) do
    input = String.trim(model.input)

    if input == "" do
      %{model | input: ""}
    else
      case CommandRegistry.execute(input) do
        :ok ->
          output = ["> #{input}" | model.output_lines]
          %{model | input: "", output_lines: output, history: [input | model.history]}

        :exit ->
          # Signal exit
          System.halt(0)
          model

        {:error, message} ->
          output = ["> #{input}", "Error: #{message}" | model.output_lines]
          %{model | input: "", output_lines: output, history: [input | model.history]}
      end
    end
  end
end

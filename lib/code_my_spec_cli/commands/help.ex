defmodule CodeMySpecCli.Commands.Help do
  @moduledoc """
  Help command to display available commands and usage.
  """

  use CodeMySpecCli.Commands.CommandBehaviour

  alias CodeMySpecCli.Commands.Registry, as: CommandRegistry

  # Help doesn't need scope
  def resolve_scope(_args), do: {:ok, nil}

  @doc """
  Show help for all commands or a specific command.

  Usage:
    /help          # Show all commands
    /help login    # Show help for /login
  """
  def execute(_scope, args) do
    case args do
      [] ->
        show_all_commands()

      [command_name | _] ->
        show_command_help(command_name)
    end
  end

  defp show_all_commands do
    commands = CommandRegistry.all_commands()

    # Group commands by category
    grouped =
      commands
      |> Enum.group_by(fn module ->
        cond do
          module in [
            CodeMySpecCli.Commands.Login,
            CodeMySpecCli.Commands.Logout,
            CodeMySpecCli.Commands.Whoami
          ] ->
            "Authentication"

          module == CodeMySpecCli.Commands.Components ->
            "Project"

          module == CodeMySpecCli.Commands.Exit ->
            "System"

          true ->
            "Other"
        end
      end)

    # Build the output text
    output =
      [""]
      |> then(fn acc ->
        Enum.reduce(grouped, acc, fn {_category, cmds}, acc ->
          commands_text =
            Enum.map(cmds, fn module ->
              # Extract moduledoc as description
              {:docs_v1, _, _, _, module_doc, _, _} = Code.fetch_docs(module)
              description = extract_description(module_doc)

              # Get command name from module
              command_name = CommandRegistry.module_name(module)

              # Format: /command - description
              "  /#{command_name} - #{description}\n"
            end)

          acc ++ [commands_text]
        end)
      end)
      |> then(fn acc -> acc ++ ["\n\nTip: Type /help <command> for detailed usage.\n"] end)
      |> Enum.join()

    {:ok, output}
  end

  defp show_command_help(command_name) do
    case CommandRegistry.get_command(command_name) do
      nil ->
        {:error, "Unknown command: /#{command_name}"}

      command_module ->
        {:docs_v1, _, _, _, module_doc, _, _} = Code.fetch_docs(command_module)
        description = extract_description(module_doc)

        output = "\n/#{command_name}\n\n#{description}\n"
        {:ok, output}
    end
  end

  defp extract_description(%{"en" => doc}) when is_binary(doc) do
    # Extract first line from moduledoc
    doc
    |> String.split("\n", parts: 2)
    |> List.first()
    |> String.trim()
  end

  defp extract_description(_), do: "No description available"
end

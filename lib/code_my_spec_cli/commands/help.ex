defmodule CodeMySpecCli.Commands.Help do
  @moduledoc """
  Help command to display available commands and usage.
  """

  @behaviour CodeMySpecCli.Commands.CommandBehaviour

  alias CodeMySpecCli.Commands.Registry, as: CommandRegistry

  @doc """
  Show help for all commands or a specific command.

  Usage:
    /help          # Show all commands
    /help login    # Show help for /login
  """
  def execute(args) do
    case args do
      [] ->
        show_all_commands()

      [command_name | _] ->
        show_command_help(command_name)
    end
  end

  defp show_all_commands do
    commands = CommandRegistry.all_commands()

    Owl.IO.puts(["\n", Owl.Data.tag("Available Commands:", [:cyan, :bright]), "\n"])

    # Group commands by category
    grouped =
      commands
      |> Enum.group_by(fn module ->
        cond do
          module in [CodeMySpecCli.Commands.Login, CodeMySpecCli.Commands.Logout, CodeMySpecCli.Commands.Whoami] ->
            "Authentication"

          module == CodeMySpecCli.Commands.Exit ->
            "System"

          true ->
            "Other"
        end
      end)

    # Display each group
    Enum.each(grouped, fn {category, cmds} ->
      Owl.IO.puts([Owl.Data.tag("\n#{category}:", [:yellow, :bright])])

      Enum.each(cmds, fn module ->
        # Extract moduledoc as description
        {:docs_v1, _, _, _, module_doc, _, _} = Code.fetch_docs(module)
        description = extract_description(module_doc)

        # Get command name from module
        command_name = CommandRegistry.module_name(module)

        # Format: /command - description
        Owl.IO.puts([
          "  ",
          Owl.Data.tag("/#{command_name}", [:green]),
          Owl.Data.tag(" - ", :faint),
          description
        ])
      end)
    end)

    Owl.IO.puts([
      "\n",
      Owl.Data.tag("Tip:", [:magenta, :bright]),
      " Type ",
      Owl.Data.tag("/help <command>", [:green]),
      " for detailed usage.",
      "\n"
    ])

    :ok
  end

  defp show_command_help(command_name) do
    case CommandRegistry.get_command(command_name) do
      nil ->
        {:error, "Unknown command: /#{command_name}"}

      command_module ->
        {:docs_v1, _, _, _, module_doc, _, _} = Code.fetch_docs(command_module)
        description = extract_description(module_doc)

        Owl.IO.puts([
          "\n",
          Owl.Data.tag("/#{command_name}", [:cyan, :bright]),
          "\n\n",
          description,
          "\n"
        ])

        :ok
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

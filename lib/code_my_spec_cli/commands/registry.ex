defmodule CodeMySpecCli.Commands.Registry do
  @moduledoc """
  Registry for CLI slash commands.

  Commands follow a slash-command style (like Discord/Slack) for extensibility.
  Each command can define its own handler, help text, and argument parsing.
  """

  @type command_result :: :ok | {:ok, String.t()} | {:error, String.t()} | :exit

  # All available command modules
  @command_modules [
    CodeMySpecCli.Commands.Init,
    CodeMySpecCli.Commands.Login,
    CodeMySpecCli.Commands.Logout,
    CodeMySpecCli.Commands.Whoami,
    CodeMySpecCli.Commands.Components,
    CodeMySpecCli.Commands.Sessions,
    CodeMySpecCli.Commands.SubmitResult,
    CodeMySpecCli.Commands.Help,
    CodeMySpecCli.Commands.Exit
  ]

  @doc """
  Get all registered command modules.
  """
  def all_commands, do: @command_modules

  @doc """
  Get a command module by name.

  The command name is derived from the module name by taking the last part
  and converting it to lowercase. For example:
  - CodeMySpecCli.Commands.Login -> "login"
  - CodeMySpecCli.Commands.Whoami -> "whoami"
  """
  def get_command(name) do
    Enum.find(@command_modules, fn module ->
      module_name(module) == name
    end)
  end

  @doc """
  Get the command name from a module.
  """
  def module_name(module) do
    module
    |> Module.split()
    |> List.last()
    |> String.downcase()
  end

  @doc """
  Execute a command string.

  Parses the input, finds the command, resolves scope, and executes the handler.
  """
  def execute(input) do
    input = String.trim(input)

    case parse_command(input) do
      {:ok, command_name, args} ->
        case get_command(command_name) do
          nil ->
            {:error, "Unknown command: /#{command_name}. Type /help for available commands."}

          command_module ->
            command_module.run(args)
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Parse a command string into command name and arguments.

  Supports:
  - /command
  - /command arg1 arg2
  - /command --flag value
  """
  def parse_command(input) do
    input = String.trim(input)

    cond do
      # Empty input
      input == "" ->
        {:error, "Empty command"}

      # Command without slash
      not String.starts_with?(input, "/") ->
        {:error, "Commands must start with /. Example: /help"}

      # Valid command
      true ->
        # Remove leading slash and split
        rest = String.trim_leading(input, "/")
        [command_name | args] = String.split(rest, ~r/\s+/, trim: true)

        {:ok, command_name, args}
    end
  end
end

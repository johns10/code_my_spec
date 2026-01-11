defmodule CodeMySpecCli.SlashCommands.SlashCommandBehaviour do
  @moduledoc """
  Behaviour for slash commands invoked by Claude Code.

  These commands are called via the CLI and output to stdout
  so Claude can see and process the results.

  ## Usage

      defmodule CodeMySpecCli.SlashCommands.GenerateContextSpec do
        use CodeMySpecCli.SlashCommands.SlashCommandBehaviour

        def execute(scope, args) do
          # Do work, write to stdout
          IO.puts(Jason.encode!(result, pretty: true))
          :ok
        end
      end

  ## Optimus Integration

  Commands are invoked from the CLI via Optimus subcommands.
  The `run/1` function is the entry point that receives parsed args.
  """

  alias CodeMySpec.Users.Scope

  @callback execute(scope :: Scope.t() | nil, args :: map()) ::
              :ok | {:error, String.t()}

  defmacro __using__(_opts) do
    quote do
      @behaviour CodeMySpecCli.SlashCommands.SlashCommandBehaviour

      @doc """
      Entry point called by the CLI with Optimus-parsed arguments.
      """
      def run(optimus_args) do
        with {:ok, scope} <- resolve_scope(optimus_args) do
          execute(scope, optimus_args)
        else
          {:error, reason} ->
            IO.puts(:stderr, "Error: #{reason}")
            {:error, reason}
        end
      end

      @doc """
      Resolve the project scope for this command.

      Override this if your command needs custom scope resolution
      or doesn't require a scope at all.
      """
      def resolve_scope(_args) do
        case Scope.for_cli() do
          # Some commands might not need scope
          nil -> {:ok, nil}
          scope -> {:ok, scope}
        end
      end

      defoverridable resolve_scope: 1
    end
  end
end

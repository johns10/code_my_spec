defmodule CodeMySpecCli.Commands.CommandBehaviour do
  @moduledoc """
  Behavior for CLI commands.

  All commands must implement:
  - execute/2 - executes the command with arguments and scope

  The command name is automatically derived from the module name.
  For example: CodeMySpecCli.Commands.Login -> "login"

  ## Usage

      defmodule CodeMySpecCli.Commands.MyCommand do
        use CodeMySpecCli.Commands.CommandBehaviour

        def execute(scope, args) do
          # Command implementation with scope available
          :ok
        end
      end

  The `use` macro automatically handles scope resolution before calling execute/2.
  Commands can optionally override `resolve_scope/1` for custom scope resolution logic.
  """

  alias CodeMySpec.Users.Scope

  @callback execute(scope :: Scope.t(), args :: [String.t()]) ::
              :ok | :exit | {:ok, String.t()} | {:error, String.t()} | {:switch_screen, atom()}

  defmacro __using__(_opts) do
    quote do
      @behaviour CodeMySpecCli.Commands.CommandBehaviour

      # Public interface called by the CLI runner
      def run(args) do
        with {:ok, scope} <- resolve_scope(args) do
          execute(scope, args)
        else
          {:error, reason} -> {:error, reason}
        end
      end

      # Default scope resolution - can be overridden by commands
      def resolve_scope(_args) do
        case Scope.for_cli() do
          nil -> {:error, "No project configured. Run /init to set up a project."}
          scope -> {:ok, scope}
        end
      end

      defoverridable resolve_scope: 1
    end
  end
end

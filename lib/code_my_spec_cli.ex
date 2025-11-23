defmodule CodeMySpecCli do
  @moduledoc """
  Main entry point for CodeMySpec CLI

  Handles both development mode (via mix/escript) and production mode (via Burrito binary).
  """

  def main(argv) do
    # Ensure app started
    Application.ensure_all_started(:code_my_spec)

    # Get args - Burrito vs escript/dev
    args = get_args(argv)

    # Parse and execute
    CodeMySpecCli.CLI.run(args)
  end

  # CRITICAL: Different arg handling for Burrito vs development
  defp get_args(_argv) do
    case Code.ensure_loaded?(Burrito.Util.Args) do
      true ->
        # Running in Burrito-wrapped binary
        Burrito.Util.Args.get_arguments()

      false ->
        # Running via mix or escript
        # System.argv() includes all args in dev mode
        System.argv()
    end
  end
end

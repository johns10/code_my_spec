defmodule CodeMySpecCli.CliRunner do
  @moduledoc """
  Runs CLI commands as part of the supervision tree.

  Starts as a Task, executes the CLI command, then halts the VM.
  If args is nil, does nothing (allows app to start without CLI).
  """
  use Task, restart: :temporary

  def start_link(nil), do: :ignore
  def start_link(args), do: Task.start_link(__MODULE__, :run, [args])

  def run(args) do
    try do
      CodeMySpecCli.Cli.run(args)
      System.halt(0)
    rescue
      e ->
        IO.puts(:stderr, "Error: #{Exception.message(e)}")
        System.halt(1)
    end
  end
end

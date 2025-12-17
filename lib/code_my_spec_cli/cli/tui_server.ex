defmodule CodeMySpecCli.Cli.TuiServer do
  @moduledoc """
  GenServer that runs the TUI interface using Ratatouille.

  This makes the CLI a proper supervised process that can be started/stopped
  and integrates cleanly with the OTP supervision tree.
  """
  use GenServer

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    # Run the Ratatouille app in the GenServer process
    # This will block, which is fine since this is the main interface process
    Ratatouille.run(CodeMySpecCli.Screens.Main, interval: 100)

    {:ok, %{}}
  end
end

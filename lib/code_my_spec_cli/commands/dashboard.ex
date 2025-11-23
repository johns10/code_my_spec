defmodule CodeMySpecCli.Commands.Dashboard do
  @moduledoc """
  Launch interactive session monitoring dashboard
  """

  def run do
    IO.puts("🎮 Launching dashboard...")
    IO.puts("   'a' to attach to selected session | 'q' to quit")
    :timer.sleep(1000)

    Ratatouille.run(CodeMySpecCli.Dashboard, interval: 1000)
  end
end

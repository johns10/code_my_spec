defmodule CodeMySpecCli.Commands.Init do
  @moduledoc """
  /init command - initialize project in current directory
  """

  use CodeMySpecCli.Commands.CommandBehaviour

  # Init doesn't need scope (it creates the project config)
  def resolve_scope(_args), do: {:ok, nil}

  @doc """
  Init command - switches to the interactive initialization screen.

  The screen handles:
    - Fetching projects from server (if logged in)
    - Interactive project selection
    - Local project creation form
  """
  def execute(_scope, _args) do
    # Tell the main router to switch to init screen
    {:switch_screen, :init}
  end
end

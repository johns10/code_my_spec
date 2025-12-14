defmodule CodeMySpecCli.Commands.Sessions do
  @moduledoc """
  Browse and manage coding sessions interactively.
  """

  use CodeMySpecCli.Commands.CommandBehaviour

  # Sessions screen handles its own scope checking
  def resolve_scope(_args), do: {:ok, nil}

  @doc """
  Opens an interactive sessions browser.

  Usage:
    /sessions    # Browse active sessions and execute commands

  The command displays a list of all active sessions in your project.
  You can select a session to view its pending commands and execute them
  one by one, with output captured and results submitted back to the session.
  """
  def execute(_scope, _args) do
    # Switch to the sessions browser screen
    {:switch_screen, :sessions}
  end
end
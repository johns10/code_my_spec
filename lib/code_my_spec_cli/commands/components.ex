defmodule CodeMySpecCli.Commands.Components do
  @moduledoc """
  Browse and search project components interactively.
  """

  use CodeMySpecCli.Commands.CommandBehaviour

  alias CodeMySpecCli.Screens.Components, as: ComponentsScreen

  @doc """
  Opens an interactive component browser with typeahead search.

  Usage:
    /components    # Browse and select components

  The command displays a searchable list of all components in your project.
  You can type to filter by module name, then select a component to view
  its details including paths, type, and relationships.
  """
  def execute(_scope, _args) do
    ComponentsScreen.show()
  end
end
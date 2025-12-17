defmodule CodeMySpecCli.Components.ProjectStatus do
  @moduledoc """
  Component that displays project initialization status.

  Shows whether a project is initialized and its name.
  Gets its own project status directly from Scope.
  """

  import Ratatouille.View
  alias CodeMySpec.Users.Scope

  @doc """
  Renders the project status indicator.
  """
  def render do
    scope = Scope.for_cli()
    project_name = if scope && scope.active_project, do: scope.active_project.name, else: nil

    label do
      text(content: "Project: ")

      if project_name do
        text(content: "✓ #{project_name}", color: :green)
      else
        text(content: "✗ Not initialized", color: :red)
      end
    end
  end
end

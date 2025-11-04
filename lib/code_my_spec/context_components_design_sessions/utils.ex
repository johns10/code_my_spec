defmodule CodeMySpec.ContextComponentsDesignSessions.Utils do
  @moduledoc """
  Utility functions for context-wide component design sessions.
  """

  alias CodeMySpec.Components.Component
  alias CodeMySpec.Sessions.Session

  @doc """
  Generates a sanitized branch name for a context-wide component design session.

  The branch name is created by:
  1. Converting the component name to lowercase
  2. Replacing non-alphanumeric characters (except hyphens/underscores) with hyphens
  3. Collapsing multiple consecutive hyphens
  4. Trimming leading/trailing hyphens
  5. Prefixing with "docs-context-components-design-session-for-"

  ## Examples

      iex> session = %Session{
      ...>   type: CodeMySpec.ContextComponentsDesignSessions,
      ...>   component: %Component{name: "User Management"}
      ...> }
      iex> CodeMySpec.ContextComponentsDesignSessions.Utils.branch_name(session)
      "docs-context-components-design-session-for-user-management"

      iex> session = %Session{
      ...>   type: CodeMySpec.ContextComponentsDesignSessions,
      ...>   component: %Component{name: "API::Handler"}
      ...> }
      iex> CodeMySpec.ContextComponentsDesignSessions.Utils.branch_name(session)
      "docs-context-components-design-session-for-api-handler"
  """
  def branch_name(%Session{
        type: CodeMySpec.ContextComponentsDesignSessions,
        component: %Component{name: name}
      }) do
    sanitized_name =
      name
      |> String.downcase()
      |> String.replace(~r/[^a-z0-9\-_]/, "-")
      |> String.replace(~r/-+/, "-")
      |> String.trim("-")

    "docs-context-components-design-session-for-#{sanitized_name}"
  end
end

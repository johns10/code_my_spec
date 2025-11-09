defmodule CodeMySpec.ContextCodingSessions.Utils do
  @moduledoc """
  Utilities for context coding sessions.
  """

  alias CodeMySpec.Components.Component
  alias CodeMySpec.Sessions.Session

  @doc """
  Generates a sanitized git branch name from a context coding session.

  ## Branch Naming Convention

  Creates a branch name with the pattern:
  `code-context-coding-session-for-{sanitized-component-name}`

  ## Sanitization Rules

  1. Convert component name to lowercase
  2. Replace non-alphanumeric characters (except hyphens/underscores) with hyphens
  3. Collapse multiple consecutive hyphens into a single hyphen
  4. Trim leading and trailing hyphens

  ## Examples

      iex> session = %Session{
      ...>   type: CodeMySpec.ContextCodingSessions,
      ...>   component: %Component{name: "User Management & Auth"}
      ...> }
      iex> Utils.branch_name(session)
      "code-context-coding-session-for-user-management-auth"

      iex> session = %Session{
      ...>   type: CodeMySpec.ContextCodingSessions,
      ...>   component: %Component{name: "API/V2/Users"}
      ...> }
      iex> Utils.branch_name(session)
      "code-context-coding-session-for-api-v2-users"
  """
  @spec branch_name(Session.t()) :: String.t()
  def branch_name(%Session{
        type: CodeMySpec.ContextCodingSessions,
        component: %Component{name: name}
      }) do
    sanitized_name =
      name
      |> String.downcase()
      |> String.replace(~r/[^a-z0-9\-_]/, "-")
      |> String.replace(~r/-+/, "-")
      |> String.trim("-")

    "code-context-coding-session-for-#{sanitized_name}"
  end
end

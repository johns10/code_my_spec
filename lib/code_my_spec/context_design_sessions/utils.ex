defmodule CodeMySpec.ContextSpecSessions.Utils do
  alias CodeMySpec.Components.Component
  alias CodeMySpec.Sessions.Session

  def branch_name(%Session{
        type: CodeMySpec.ContextSpecSessions,
        component: %Component{name: name}
      }) do
    sanitized_name =
      name
      |> String.downcase()
      |> String.replace(~r/[^a-z0-9\-_]/, "-")
      |> String.replace(~r/-+/, "-")
      |> String.trim("-")

    "docs-context-design-session-for-#{sanitized_name}"
  end
end

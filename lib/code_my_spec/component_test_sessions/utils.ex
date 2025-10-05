defmodule CodeMySpec.ComponentTestSessions.Utils do
  alias CodeMySpec.Components.Component
  alias CodeMySpec.Sessions.Session

  def branch_name(%Session{
        type: CodeMySpec.ComponentTestSessions,
        component: %Component{name: name}
      }) do
    sanitized_name =
      name
      |> String.downcase()
      |> String.replace(~r/[^a-z0-9\-_]/, "-")
      |> String.replace(~r/-+/, "-")
      |> String.trim("-")

    "component-test-session-for-#{sanitized_name}"
  end
end

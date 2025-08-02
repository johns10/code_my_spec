defmodule CodeMySpec.MCPServers.Components.Tools.ListComponentsTest do
  use ExUnit.Case, async: true

  alias CodeMySpec.MCPServers.Components.Tools.ListComponents
  alias CodeMySpec.Users.Scope
  alias Hermes.Server.Frame

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(CodeMySpec.Repo)
  end

  describe "ListComponents tool" do
    test "executes with valid params and scope" do
      params = %{project_id: "project-123"}

      scope = %Scope{
        user: %{id: 1},
        active_account: %{id: 1},
        active_account_id: 1,
        active_project: %{id: 1},
        active_project_id: 1
      }

      frame = %Frame{assigns: %{current_scope: scope}}

      assert {:reply, response, ^frame} = ListComponents.execute(params, frame)
      assert response.type == :tool
    end
  end
end
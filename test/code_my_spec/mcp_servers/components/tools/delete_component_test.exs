defmodule CodeMySpec.MCPServers.Components.Tools.DeleteComponentTest do
  use ExUnit.Case, async: true

  alias CodeMySpec.MCPServers.Components.Tools.DeleteComponent
  alias Hermes.Server.Frame
  import CodeMySpec.ComponentsFixtures
  import CodeMySpec.UsersFixtures

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(CodeMySpec.Repo)
  end

  describe "DeleteComponent tool" do
    test "executes with valid params and scope" do
      scope = full_scope_fixture()
      component = component_fixture(scope)
      params = %{id: component.id}

      frame = %Frame{assigns: %{current_scope: scope}}

      assert {:reply, response, ^frame} = DeleteComponent.execute(params, frame)
      assert response.type == :tool
      assert response.isError == false
      
      [%{"text" => json_content}] = response.content
      content = Jason.decode!(json_content)
      assert content["id"] == component.id
    end

    test "returns error for non-existent component" do
      scope = full_scope_fixture()
      params = %{id: 999999}

      frame = %Frame{assigns: %{current_scope: scope}}

      assert {:reply, response, ^frame} = DeleteComponent.execute(params, frame)
      assert response.type == :tool
      assert response.isError == true
    end

    test "returns error for invalid scope" do
      component = component_fixture(full_scope_fixture())
      params = %{id: component.id}

      frame = %Frame{assigns: %{}}

      assert {:reply, response, ^frame} = DeleteComponent.execute(params, frame)
      assert response.type == :tool
      assert response.isError == true
    end
  end
end

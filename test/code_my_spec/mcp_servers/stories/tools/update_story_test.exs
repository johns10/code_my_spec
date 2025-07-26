defmodule CodeMySpec.MCPServers.Stories.Tools.UpdateStoryTest do
  use ExUnit.Case, async: true

  alias CodeMySpec.MCPServers.Stories.Tools.UpdateStory
  alias CodeMySpec.Users.Scope
  alias Hermes.Server.Frame

  describe "UpdateStory tool" do
    test "executes with valid params and scope" do
      params = %{
        id: "story-123",
        title: "Updated User Login",
        description: "Updated description"
      }

      scope = %Scope{
        user: %{id: 1},
        active_account: %{id: 1},
        active_account_id: 1,
        active_project: %{id: 1},
        active_project_id: 1
      }

      frame = %Frame{assigns: %{current_scope: scope}}

      assert {:reply, response, ^frame} = UpdateStory.execute(params, frame)
      assert response.type == :tool
      assert response.isError == false
    end
  end
end

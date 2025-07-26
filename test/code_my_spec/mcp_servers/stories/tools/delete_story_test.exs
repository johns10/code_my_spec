defmodule CodeMySpec.MCPServers.Stories.Tools.DeleteStoryTest do
  use ExUnit.Case, async: true

  alias CodeMySpec.MCPServers.Stories.Tools.DeleteStory
  alias CodeMySpec.Users.Scope
  alias Hermes.Server.Frame

  describe "DeleteStory tool" do
    test "validates required id field" do
      # Test schema validation with missing id
      assert {:error, errors} =
        Hermes.Server.Component.validate_params(DeleteStory, %{})

      assert errors[:id] == ["is required"]
    end

    test "executes with valid params and scope" do
      params = %{id: "story-123"}

      scope = %Scope{
        user: %{id: 1},
        active_account: %{id: 1},
        active_account_id: 1,
        active_project: %{id: 1},
        active_project_id: 1
      }

      frame = %Frame{assigns: %{current_scope: scope}}

      assert {:reply, response, ^frame} = DeleteStory.execute(params, frame)
      assert response.type == :tool
      assert response.isError == false
    end
  end
end

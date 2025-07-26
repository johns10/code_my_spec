defmodule CodeMySpec.MCPServers.Stories.Tools.UpdateStoryTest do
  use ExUnit.Case, async: true

  alias CodeMySpec.MCPServers.Stories.Tools.UpdateStory
  alias Hermes.Server.Frame
  import CodeMySpec.StoriesFixtures
  import CodeMySpec.UsersFixtures

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(CodeMySpec.Repo)
  end

  describe "UpdateStory tool" do
    test "executes with valid params and scope" do
      scope = full_scope_fixture()
      story = story_fixture(scope)

      params = %{
        id: story.id,
        title: "Updated User Login",
        description: "Updated description"
      }

      frame = %Frame{assigns: %{current_scope: scope}}

      assert {:reply, response, ^frame} = UpdateStory.execute(params, frame)
      assert response.type == :tool
      assert response.isError == false
    end
  end
end

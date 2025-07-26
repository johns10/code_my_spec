defmodule CodeMySpec.MCPServers.Stories.Tools.GetStoryTest do
  use ExUnit.Case, async: true

  alias CodeMySpec.MCPServers.Stories.Tools.GetStory
  alias Hermes.Server.Frame
  import CodeMySpec.StoriesFixtures
  import CodeMySpec.UsersFixtures

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(CodeMySpec.Repo)
  end

  describe "GetStory tool" do
    test "executes with valid params and scope" do
      scope = full_scope_fixture()
      story = story_fixture(scope)
      params = %{story_id: story.id}

      frame = %Frame{assigns: %{current_scope: scope}}

      assert {:reply, response, ^frame} = GetStory.execute(params, frame)
      assert response.type == :resource
    end
  end
end

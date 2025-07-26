defmodule CodeMySpec.MCPServers.Stories.Resources.StoryTest do
  use ExUnit.Case, async: true

  alias CodeMySpec.MCPServers.Stories.Resources.Story
  alias Hermes.Server.Frame
  import CodeMySpec.StoriesFixtures
  import CodeMySpec.UsersFixtures

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(CodeMySpec.Repo)
  end

  describe "Story resource" do
    test "returns correct uri and mime_type" do
      assert Story.uri() == "story://template"
      assert Story.mime_type() == "application/json"
      assert Story.uri_template() == "story://{story_id}"
    end

    test "reads story with valid params and scope" do
      scope = full_scope_fixture()
      story = story_fixture(scope)
      params = %{"story_id" => story.id}

      frame = %Frame{assigns: %{current_scope: scope}}

      assert {:reply, response, ^frame} = Story.read(params, frame)
      assert response.type == :resource
    end
  end
end

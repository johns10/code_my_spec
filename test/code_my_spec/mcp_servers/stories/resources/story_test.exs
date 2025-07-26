defmodule CodeMySpec.MCPServers.Stories.Resources.StoryTest do
  use ExUnit.Case, async: true

  alias CodeMySpec.MCPServers.Stories.Resources.Story
  alias CodeMySpec.Users.Scope
  alias Hermes.Server.Frame

  describe "Story resource" do
    test "returns correct uri and mime_type" do
      assert Story.uri() == "story://template"
      assert Story.mime_type() == "application/json"
      assert Story.uri_template() == "story://{story_id}"
    end

    test "reads story with valid params and scope" do
      params = %{"story_id" => "story-123"}
      
      scope = %Scope{
        user: %{id: 1},
        active_account: %{id: 1},
        active_account_id: 1,
        active_project: %{id: 1},
        active_project_id: 1
      }

      frame = %Frame{assigns: %{current_scope: scope}}

      assert {:reply, response, ^frame} = Story.read(params, frame)
      assert response.type == :resource
    end
  end
end

defmodule CodeMySpec.MCPServers.Stories.Resources.StoriesListTest do
  use ExUnit.Case, async: true

  alias CodeMySpec.MCPServers.Stories.Resources.StoriesList
  alias CodeMySpec.Users.Scope
  alias Hermes.Server.Frame

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(CodeMySpec.Repo)
  end

  describe "StoriesList resource" do
    test "returns correct uri and mime_type" do
      assert StoriesList.uri() == "stories://project/template"
      assert StoriesList.mime_type() == "application/json"
      assert StoriesList.uri_template() == "stories://project/{project_id}"
    end

    test "reads stories list with valid params and scope" do
      params = %{"project_id" => "project-123"}
      
      scope = %Scope{
        user: %{id: 1},
        active_account: %{id: 1},
        active_account_id: 1,
        active_project: %{id: 1},
        active_project_id: 1
      }

      frame = %Frame{assigns: %{current_scope: scope}}

      assert {:reply, response, ^frame} = StoriesList.read(params, frame)
      assert response.type == :resource
    end
  end
end

defmodule CodeMySpec.MCPServers.Stories.Tools.StartStoryReviewTest do
  use ExUnit.Case, async: true

  alias CodeMySpec.MCPServers.Stories.Tools.StartStoryReview
  alias CodeMySpec.Users.Scope
  alias Hermes.Server.Frame

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(CodeMySpec.Repo)
  end

  describe "StartStoryReview tool" do
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

      assert {:reply, response, ^frame} = StartStoryReview.execute(params, frame)
      assert response.type == :tool
      assert response.isError == false
      [%{"text" => content}] = response.content
      assert String.contains?(content, "comprehensive story review")
    end
  end
end

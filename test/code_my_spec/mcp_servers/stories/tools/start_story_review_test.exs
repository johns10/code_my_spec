defmodule CodeMySpec.McpServers.Stories.Tools.StartStoryReviewTest do
  use ExUnit.Case, async: true
  import CodeMySpec.UsersFixtures

  alias CodeMySpec.McpServers.Stories.Tools.StartStoryReview
  alias Hermes.Server.Frame

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(CodeMySpec.Repo)
  end

  describe "StartStoryReview tool" do
    test "executes with valid params and scope" do
      scope = full_scope_fixture()
      params = %{project_id: "project-123"}
      frame = %Frame{assigns: %{current_scope: scope}}

      assert {:reply, response, ^frame} = StartStoryReview.execute(params, frame)
      assert response.type == :tool
      assert response.isError == false
      [%{"text" => content}] = response.content
      assert String.contains?(content, "comprehensive story review")
    end
  end
end

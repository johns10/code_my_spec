defmodule CodeMySpec.MCPServers.Stories.Tools.StartStoryInterviewTest do
  use ExUnit.Case, async: true
  import CodeMySpec.UsersFixtures

  alias CodeMySpec.MCPServers.Stories.Tools.StartStoryInterview
  alias Hermes.Server.Frame

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(CodeMySpec.Repo)
  end

  describe "StartStoryInterview tool" do
    test "executes with valid params and scope" do
      scope = full_scope_fixture()
      params = %{}
      frame = %Frame{assigns: %{current_scope: scope}}

      assert {:reply, response, ^frame} = StartStoryInterview.execute(params, frame)
      assert response.type == :tool
      assert response.isError == false
      [%{"text" => content}] = response.content
      assert String.contains?(content, "Product Manager")
    end
  end
end

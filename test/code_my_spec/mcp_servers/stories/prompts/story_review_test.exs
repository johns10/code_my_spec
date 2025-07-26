defmodule CodeMySpec.MCPServers.Stories.Prompts.StoryReviewTest do
  use ExUnit.Case, async: true

  alias CodeMySpec.MCPServers.Stories.Prompts.StoryReview
  alias CodeMySpec.Users.Scope
  alias Hermes.Server.Frame

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(CodeMySpec.Repo)
  end

  describe "StoryReview prompt" do
    test "generates messages with valid params and scope" do
      params = %{"project_id" => "project-123"}

      scope = %Scope{
        user: %{id: 1},
        active_account: %{id: 1},
        active_account_id: 1,
        active_project: %{id: 1},
        active_project_id: 1
      }

      frame = %Frame{assigns: %{current_scope: scope}}

      assert {:ok, messages, ^frame} = StoryReview.get_messages(params, frame)
      assert is_list(messages)
      assert length(messages) == 1
      assert %{"role" => "system", "content" => content} = hd(messages)
      assert String.contains?(content, "comprehensive story review")
    end
  end
end

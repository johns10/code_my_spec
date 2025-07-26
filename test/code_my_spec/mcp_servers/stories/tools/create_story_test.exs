defmodule CodeMySpec.MCPServers.Stories.Tools.CreateStoryTest do
  use ExUnit.Case, async: true

  alias CodeMySpec.MCPServers.Stories.Tools.CreateStory
  alias CodeMySpec.Users.Scope
  alias Hermes.Server.Frame

  describe "CreateStory tool" do
    test "validates required fields" do
      # Test schema validation with missing required fields
      assert {:error, errors} =
        Hermes.Server.Component.validate_params(CreateStory, %{})

      assert errors[:title] == ["is required"]
      assert errors[:description] == ["is required"]
      assert errors[:acceptance_criteria] == ["is required"]
    end

    test "executes with valid params and scope" do
      params = %{
        title: "User Login",
        description: "As a user I want to login",
        acceptance_criteria: ["User can enter credentials", "System validates credentials"]
      }

      scope = %Scope{
        user: %{id: 1},
        active_account: %{id: 1},
        active_account_id: 1,
        active_project: %{id: 1},
        active_project_id: 1
      }

      frame = %Frame{assigns: %{current_scope: scope}}

      assert {:reply, response, ^frame} = CreateStory.execute(params, frame)
      assert response.type == :tool
      assert response.isError == false
    end
  end
end

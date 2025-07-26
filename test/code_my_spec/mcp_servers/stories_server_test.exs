defmodule CodeMySpec.MCPServers.StoriesServerTest do
  use CodeMySpec.DataCase

  alias CodeMySpec.MCPServers.StoriesServer
  alias CodeMySpec.MCPServers.Stories.Tools.CreateStory
  alias Hermes.Server.Frame

  import CodeMySpec.UsersFixtures
  import CodeMySpec.AccountsFixtures
  import CodeMySpec.ProjectsFixtures
  import CodeMySpec.UserPreferencesFixtures
  import CodeMySpec.OauthFixtures

  describe "init/2" do
    test "successfully initializes with valid bearer token" do
      user = user_fixture()
      account = account_with_owner_fixture(user)
      scope = user_scope_fixture(user, account)
      project = project_fixture(scope)

      # Create user preferences to set active account and project
      user_preference_fixture(scope, %{
        active_account_id: account.id,
        active_project_id: project.id
      })

      # Create OAuth application first
      app = oauth_application_fixture()

      # Create a valid access token - let ExOauth2Provider generate the token
      {:ok, access_token} =
        ExOauth2Provider.AccessTokens.create_token(
          user,
          %{
            resource_owner_id: user.id,
            application_id: app.id,
            expires_in: 3600,
            scopes: ""
          },
          otp_app: :code_my_spec
        )

      frame = %Frame{
        transport: %{
          headers: %{"authorization" => "Bearer #{access_token.token}"}
        }
      }

      assert {:ok, authenticated_frame} = StoriesServer.init(nil, frame)
      assert authenticated_frame.assigns.current_scope.user.id == user.id
      assert authenticated_frame.assigns.access_token.token == access_token.token
    end

    test "fails initialization with missing bearer token" do
      frame = %Frame{transport: %{headers: %{}}}

      assert {:ok, %Frame{assigns: assigns}} = StoriesServer.init(nil, frame)
      assert Map.get(assigns, :current_scope) == nil
    end

    test "fails initialization with invalid bearer token" do
      frame = %Frame{
        transport: %{
          headers: %{"authorization" => "Bearer invalid_token"}
        }
      }

      assert {:ok, %Frame{assigns: assigns}} = StoriesServer.init(nil, frame)
      assert Map.get(assigns, :current_scope) == nil
    end
  end

  describe "CreateStory tool" do
    setup do
      user = user_fixture()
      account = account_with_owner_fixture(user)
      scope = user_scope_fixture(user, account)
      project = project_fixture(scope)

      # Update scope with active project
      scope = %{scope | active_project_id: project.id, active_project: project}

      frame = %Frame{
        assigns: %{
          current_scope: scope,
          access_token: %{token: "test_token"}
        }
      }

      %{user: user, account: account, project: project, scope: scope, frame: frame}
    end

    test "creates story successfully with valid params", %{frame: frame} do
      params = %{
        "title" => "Test Story",
        "description" => "Test description",
        "acceptance_criteria" => ["Criteria 1", "Criteria 2"],
        "priority" => 42,
        "status" => "in_progress"
      }

      assert {:reply, response, ^frame} = CreateStory.execute(params, frame)

      # The response is a Hermes.Server.Response struct with content
      assert %Hermes.Server.Response{content: [%{"text" => json_text}]} = response
      assert {:ok, story_data} = Jason.decode(json_text)

      assert story_data["title"] == "Test Story"
      assert story_data["description"] == "Test description"
      assert story_data["acceptance_criteria"] == ["Criteria 1", "Criteria 2"]
    end

    test "returns validation error with invalid params", %{frame: frame} do
      params = %{
        "title" => "",
        "description" => ""
      }

      # Validation errors return the response directly, not in a {:reply, response, frame} tuple
      assert %Hermes.Server.Response{isError: true} = CreateStory.execute(params, frame)
    end

    test "creates story with minimal required params", %{frame: frame} do
      params = %{
        "title" => "Minimal Story",
        "description" => "Minimal description",
        "acceptance_criteria" => [],
        "priority" => 1,
        "status" => "in_progress"
      }

      assert {:reply, response, ^frame} = CreateStory.execute(params, frame)

      # The response is a Hermes.Server.Response struct with content
      assert %Hermes.Server.Response{content: [%{"text" => json_text}]} = response
      assert {:ok, story_data} = Jason.decode(json_text)

      assert story_data["title"] == "Minimal Story"
      assert story_data["description"] == "Minimal description"
      assert story_data["acceptance_criteria"] == []
    end
  end
end

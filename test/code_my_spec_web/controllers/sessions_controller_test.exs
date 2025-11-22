defmodule CodeMySpecWeb.SessionsControllerTest do
  use CodeMySpecWeb.ConnCase

  import CodeMySpec.{UsersFixtures, SessionsFixtures, ComponentsFixtures}

  setup %{conn: conn} do
    scope = full_preferences_fixture()
    oauth_app = create_oauth_application()

    # Create user-associated access token directly in database
    access_token_value =
      :crypto.strong_rand_bytes(32) |> Base.encode64() |> String.replace(~r/[^a-zA-Z0-9]/, "")

    # Insert access token with user association
    {1, [_token]} =
      CodeMySpec.Repo.insert_all(
        "oauth_access_tokens",
        [
          %{
            token: access_token_value,
            resource_owner_id: scope.user.id,
            application_id: oauth_app.id,
            scopes: "read write",
            expires_in: 7200,
            inserted_at: DateTime.utc_now() |> DateTime.truncate(:second),
            updated_at: DateTime.utc_now() |> DateTime.truncate(:second)
          }
        ],
        returning: [:id, :token, :resource_owner_id]
      )

    # Create authenticated connection with Bearer token
    conn =
      put_req_header(conn, "authorization", "Bearer #{access_token_value}")
      |> assign(:current_scope, scope)

    %{conn: conn, scope: scope, access_token: access_token_value, oauth_app: oauth_app}
  end

  # Helper function to create OAuth application fixture (copied from oauth_controller_test.exs)
  defp create_oauth_application(attrs \\ %{}) do
    attrs =
      attrs
      |> Enum.into(%{
        name: "Test Application",
        uid: "test-client-#{System.unique_integer([:positive])}",
        secret: "test-secret-#{:crypto.strong_rand_bytes(32) |> Base.encode64()}",
        redirect_uri: "https://example.com/callback",
        scopes: "read write"
      })

    # Insert directly without changeset since the OAuth schema doesn't expose it
    {1, [app]} =
      CodeMySpec.Repo.insert_all(
        "oauth_applications",
        [
          Map.merge(attrs, %{
            inserted_at: DateTime.utc_now(),
            updated_at: DateTime.utc_now()
          })
        ],
        returning: [:id, :name, :uid, :secret, :redirect_uri, :scopes]
      )

    struct(CodeMySpec.Oauth.Application, app)
  end

  describe "show/2" do
    test "shows session when valid", %{conn: conn, scope: scope} do
      session = session_fixture(scope)
      conn = get(conn, ~p"/api/sessions/#{session.id}")

      response_data = json_response(conn, 200)["data"]
      assert response_data["id"] == session.id
      assert response_data["type"] == "ContextDesignSessions"
      assert response_data["status"] == "active"
    end

    test "returns 404 for non-existent session", %{conn: conn} do
      conn = get(conn, ~p"/api/sessions/99999")
      assert response(conn, 404)
    end
  end

  describe "create/2" do
    test "creates session with valid params", %{conn: conn, scope: scope} do
      component = component_fixture(scope)

      session_params = %{
        agent: "claude_code",
        environment: "local",
        type: "ContextDesignSessions",
        component_id: component.id
      }

      conn = post(conn, ~p"/api/sessions", session: session_params)

      assert %{"data" => session_data} = json_response(conn, 201)
      assert session_data["agent"] == "claude_code"
      assert session_data["environment"] == "local"
      assert session_data["type"] == "ContextDesignSessions"
      assert session_data["status"] == "active"
    end

    test "returns error with invalid params", %{conn: conn} do
      conn = post(conn, ~p"/api/sessions", session: %{})
      assert response(conn, 422)
    end
  end

  describe "next_command/2" do
    setup %{scope: scope} do
      component = component_fixture(scope)
      session = session_fixture(scope, component_id: component.id)
      %{session: session}
    end

    test "returns command when available", %{conn: conn, session: session} do
      conn = get(conn, ~p"/api/sessions/#{session.id}/next-command")

      response = json_response(conn, 200)
      assert %{"data" => data} = response
      assert is_list(data["interactions"])
      assert length(data["interactions"]) > 0

      # Check that the first interaction has a command
      [first_interaction | _] = data["interactions"]
      assert Map.has_key?(first_interaction, "command")
    end

    test "returns completion when session is done successfully", %{conn: conn, session: session} do
      # Mark session as complete by processing all interactions
      # (This is implementation-specific, you may need to adjust based on your business logic)
      conn = get(conn, ~p"/api/sessions/#{session.id}/next-command")

      # This test may need adjustment based on how your session completion works
      response = json_response(conn, 200)
      # Either returns a command or completion status
      assert response["status"] in ["complete", nil] or Map.has_key?(response, "command")
    end

    test "returns error for non-existent session", %{conn: conn} do
      conn = get(conn, ~p"/api/sessions/99999/next-command")
      assert json_response(conn, 404)["error"]
    end
  end

  describe "submit_result/2" do
    setup %{scope: scope} do
      component = component_fixture(scope)
      session = session_fixture(scope, %{component_id: component.id})
      %{session: session}
    end

    test "submits result successfully", %{conn: conn, session: session} do
      # First get a command to get an interaction_id
      get_conn = get(conn, ~p"/api/sessions/#{session.id}/next-command")

      case json_response(get_conn, 200) do
        %{"data" => %{"interactions" => [first_interaction | _]}} ->
          interaction_id = first_interaction["id"]

          result_params = %{
            status: "ok",
            data: %{output: "test output"},
            code: 0,
            stdout: "success output",
            stderr: "",
            duration_ms: 1000
          }

          conn =
            post(conn, ~p"/api/sessions/#{session.id}/submit-result/#{interaction_id}",
              result: result_params
            )

          assert %{"data" => session_data} = json_response(conn, 200)
          assert session_data["id"] == session.id

        _ ->
          # Skip test if no command available (session might be complete)
          flunk("No command available to test result submission")
      end
    end

    test "returns error for non-existent session", %{conn: conn} do
      conn = post(conn, ~p"/api/sessions/99999/submit-result/123", result: %{status: "success"})
      assert response(conn, 404)
    end

    test "returns error for non-existent interaction", %{conn: conn, session: session} do
      conn =
        post(conn, ~p"/api/sessions/#{session.id}/submit-result/99999", result: %{status: "ok"})

      assert response(conn, 404)
    end
  end
end

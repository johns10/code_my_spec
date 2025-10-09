defmodule CodeMySpec.Sessions.OrchestratorTest do
  use CodeMySpec.DataCase

  alias CodeMySpec.Sessions

  import CodeMySpec.UsersFixtures
  import CodeMySpec.ComponentsFixtures

  setup do
    scope = full_scope_fixture()
    context = component_fixture(scope, %{name: "TestContext", type: :context})

    component =
      component_fixture(scope, %{
        name: "TestComponent",
        type: :other,
        parent_component_id: context.id
      })

    {:ok, scope: scope, component: component}
  end

  describe "next_command/3" do
    test "creates first interaction when session has no interactions", %{
      scope: scope,
      component: component
    } do
      {:ok, session} =
        Sessions.create_session(scope, %{
          type: CodeMySpec.ComponentDesignSessions,
          component_id: component.id,
          environment: :local
        })

      assert {:ok, interaction} = Sessions.next_command(scope, session.id)
      assert interaction.id != nil

      # Verify session was updated with interaction
      updated_session = Sessions.get_session(scope, session.id)
      assert length(updated_session.interactions) == 1
    end

    test "returns existing pending interaction instead of creating duplicate", %{
      scope: scope,
      component: component
    } do
      {:ok, session} =
        Sessions.create_session(scope, %{
          type: CodeMySpec.ComponentDesignSessions,
          component_id: component.id,
          environment: :local
        })

      # First call creates interaction
      assert {:ok, session1} = Sessions.next_command(scope, session.id)
      [interaction1 | _] = session1.interactions
      session_after_first = Sessions.get_session(scope, session.id)
      assert length(session_after_first.interactions) == 1

      # Second call should return same interaction, not create new one
      assert {:ok, session2} = Sessions.next_command(scope, session.id)
      [interaction2 | _] = session2.interactions
      assert interaction2.id == interaction1.id
      session_after_second = Sessions.get_session(scope, session.id)
      assert length(session_after_second.interactions) == 1

      # Third call should still return same interaction
      assert {:ok, session3} = Sessions.next_command(scope, session.id)
      [interaction3 | _] = session3.interactions
      assert interaction3.id == interaction1.id
      session_after_third = Sessions.get_session(scope, session.id)
      assert length(session_after_third.interactions) == 1
    end

    test "creates new interaction after completing previous one", %{
      scope: scope,
      component: component
    } do
      {:ok, session} =
        Sessions.create_session(scope, %{
          type: CodeMySpec.ComponentDesignSessions,
          component_id: component.id,
          environment: :local
        })

      # First call creates interaction
      assert {:ok, session} = Sessions.next_command(scope, session.id)
      [interaction1 | _] = session.interactions

      # Complete the interaction
      result = %{
        status: :ok,
        code: 0,
        stdout: "test output",
        data: %{}
      }

      {:ok, completed_session} =
        Sessions.handle_result(scope, session.id, interaction1.id, result)

      # Verify first interaction is completed
      assert length(completed_session.interactions) == 1
      assert hd(completed_session.interactions).result != nil

      # Next call should create new interaction (will fail due to missing component preload, but that's OK)
      # The important part is that it doesn't return the completed interaction
      {:ok, interaction2} = Sessions.next_command(scope, session.id)
      # If it succeeds, verify it's a new interaction
      assert interaction2.id != interaction1.id
    end

    test "returns error when session is complete", %{scope: scope} do
      {:ok, session} = Sessions.create_session(scope, %{type: CodeMySpec.ComponentDesignSessions})
      {:ok, completed_session} = Sessions.update_session(scope, session, %{status: :complete})

      assert {:error, :complete} = Sessions.next_command(scope, completed_session.id)
    end

    test "returns error when session is failed", %{scope: scope} do
      {:ok, session} = Sessions.create_session(scope, %{type: CodeMySpec.ComponentDesignSessions})
      {:ok, failed_session} = Sessions.update_session(scope, session, %{status: :failed})

      assert {:error, :failed} = Sessions.next_command(scope, failed_session.id)
    end

    test "returns error when session not found", %{scope: scope} do
      assert {:error, :session_not_found} = Sessions.next_command(scope, 99999)
    end
  end
end

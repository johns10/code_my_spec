defmodule CodeMySpec.Sessions.InteractionRegistryTest do
  use ExUnit.Case, async: false

  alias CodeMySpec.Sessions.{InteractionRegistry, RuntimeInteraction}

  setup do
    # Clear registry before each test
    InteractionRegistry.clear_all()
    :ok
  end

  describe "register_status/1" do
    test "stores new status for interaction" do
      interaction_id = "test-interaction-123"
      runtime = RuntimeInteraction.new(interaction_id, %{agent_state: "running"})

      assert :ok = InteractionRegistry.register_status(runtime)
      assert {:ok, registered} = InteractionRegistry.get_status(interaction_id)
      assert registered.interaction_id == interaction_id
      assert registered.agent_state == "running"
    end

    test "overwrites existing status for interaction" do
      interaction_id = "test-interaction-123"
      first_runtime = RuntimeInteraction.new(interaction_id, %{agent_state: "running"})
      second_runtime = RuntimeInteraction.new(interaction_id, %{agent_state: "complete"})

      InteractionRegistry.register_status(first_runtime)
      InteractionRegistry.register_status(second_runtime)

      assert {:ok, registered} = InteractionRegistry.get_status(interaction_id)
      assert registered.agent_state == "complete"
    end

    test "handles notification events" do
      interaction_id = "test-interaction-123"

      runtime =
        RuntimeInteraction.new(interaction_id, %{
          agent_state: "notification",
          last_notification: %{type: "info", message: "Test notification"}
        })

      assert :ok = InteractionRegistry.register_status(runtime)
      assert {:ok, registered_status} = InteractionRegistry.get_status(interaction_id)
      assert registered_status.agent_state == "notification"
      assert registered_status.last_notification.message == "Test notification"
    end

    test "handles agent_done events" do
      interaction_id = "test-interaction-123"
      runtime = RuntimeInteraction.new(interaction_id, %{agent_state: "complete"})

      assert :ok = InteractionRegistry.register_status(runtime)
      assert {:ok, registered} = InteractionRegistry.get_status(interaction_id)
      assert registered.agent_state == "complete"
    end
  end

  describe "get_status/1" do
    test "returns status for registered interaction" do
      interaction_id = "test-interaction-123"
      runtime = RuntimeInteraction.new(interaction_id, %{agent_state: "running"})

      InteractionRegistry.register_status(runtime)

      assert {:ok, registered} = InteractionRegistry.get_status(interaction_id)
      assert registered.agent_state == "running"
    end

    test "returns error for unknown interaction" do
      assert {:error, :not_found} = InteractionRegistry.get_status("unknown-interaction")
    end

    test "returns most recent status after multiple updates" do
      interaction_id = "test-interaction-123"
      first_runtime = RuntimeInteraction.new(interaction_id, %{agent_state: "running"})
      second_runtime = RuntimeInteraction.new(interaction_id, %{agent_state: "waiting"})
      third_runtime = RuntimeInteraction.new(interaction_id, %{agent_state: "complete"})

      InteractionRegistry.register_status(first_runtime)
      InteractionRegistry.register_status(second_runtime)
      InteractionRegistry.register_status(third_runtime)

      assert {:ok, registered} = InteractionRegistry.get_status(interaction_id)
      assert registered.agent_state == "complete"
    end
  end

  describe "clear_status/1" do
    test "removes status from registry" do
      interaction_id = "test-interaction-123"
      runtime = RuntimeInteraction.new(interaction_id, %{agent_state: "running"})

      InteractionRegistry.register_status(runtime)
      assert {:ok, _} = InteractionRegistry.get_status(interaction_id)

      InteractionRegistry.clear_status(interaction_id)
      assert {:error, :not_found} = InteractionRegistry.get_status(interaction_id)
    end

    test "succeeds for non-existent interaction" do
      assert :ok = InteractionRegistry.clear_status("non-existent")
    end

    test "allows status to be re-registered after clearing" do
      interaction_id = "test-interaction-123"
      first_runtime = RuntimeInteraction.new(interaction_id, %{agent_state: "running"})
      second_runtime = RuntimeInteraction.new(interaction_id, %{agent_state: "complete"})

      InteractionRegistry.register_status(first_runtime)
      InteractionRegistry.clear_status(interaction_id)
      InteractionRegistry.register_status(second_runtime)

      assert {:ok, registered} = InteractionRegistry.get_status(interaction_id)
      assert registered.agent_state == "complete"
    end
  end

  describe "clear_all/0" do
    test "removes all registered statuses" do
      runtime1 = RuntimeInteraction.new("interaction-1", %{agent_state: "running"})
      runtime2 = RuntimeInteraction.new("interaction-2", %{agent_state: "waiting"})
      runtime3 = RuntimeInteraction.new("interaction-3", %{agent_state: "complete"})

      InteractionRegistry.register_status(runtime1)
      InteractionRegistry.register_status(runtime2)
      InteractionRegistry.register_status(runtime3)

      assert length(InteractionRegistry.list_active()) == 3

      InteractionRegistry.clear_all()

      assert InteractionRegistry.list_active() == []
      assert {:error, :not_found} = InteractionRegistry.get_status("interaction-1")
      assert {:error, :not_found} = InteractionRegistry.get_status("interaction-2")
      assert {:error, :not_found} = InteractionRegistry.get_status("interaction-3")
    end

    test "works when registry is empty" do
      assert :ok = InteractionRegistry.clear_all()
      assert InteractionRegistry.list_active() == []
    end
  end

  describe "list_active/0" do
    test "returns empty list when no statuses registered" do
      assert InteractionRegistry.list_active() == []
    end

    test "returns all registered interaction_ids" do
      runtime1 = RuntimeInteraction.new("interaction-1", %{agent_state: "running"})
      runtime2 = RuntimeInteraction.new("interaction-2", %{agent_state: "waiting"})
      runtime3 = RuntimeInteraction.new("interaction-3", %{agent_state: "complete"})

      InteractionRegistry.register_status(runtime1)
      InteractionRegistry.register_status(runtime2)
      InteractionRegistry.register_status(runtime3)

      active = InteractionRegistry.list_active()

      assert length(active) == 3
      assert "interaction-1" in active
      assert "interaction-2" in active
      assert "interaction-3" in active
    end

    test "excludes cleared interactions" do
      runtime1 = RuntimeInteraction.new("interaction-1", %{agent_state: "running"})
      runtime2 = RuntimeInteraction.new("interaction-2", %{agent_state: "waiting"})
      runtime3 = RuntimeInteraction.new("interaction-3", %{agent_state: "complete"})

      InteractionRegistry.register_status(runtime1)
      InteractionRegistry.register_status(runtime2)
      InteractionRegistry.register_status(runtime3)

      InteractionRegistry.clear_status("interaction-2")

      active = InteractionRegistry.list_active()

      assert length(active) == 2
      assert "interaction-1" in active
      assert "interaction-3" in active
      refute "interaction-2" in active
    end
  end
end

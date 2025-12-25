defmodule CodeMySpec.Environments.Cli.TmuxAdapterTest do
  use ExUnit.Case
  doctest CodeMySpec.Environments.Cli.TmuxAdapter
  alias CodeMySpec.Environments.Cli.TmuxAdapter

  describe "inside_tmux?/0" do
    test "returns true when TMUX env var is set" do
      # This test depends on whether we're actually inside tmux
      result = TmuxAdapter.inside_tmux?()

      if System.get_env("TMUX") do
        assert result == true
      else
        assert result == false
      end
    end

    test "returns false when TMUX env var is not set" do
      original = System.get_env("TMUX")
      System.delete_env("TMUX")

      assert TmuxAdapter.inside_tmux?() == false

      # Restore original value
      if original, do: System.put_env("TMUX", original)
    end

    test "returns false when TMUX env var is empty string" do
      original = System.get_env("TMUX")
      System.put_env("TMUX", "")

      assert TmuxAdapter.inside_tmux?() == false

      # Restore original value
      if original do
        System.put_env("TMUX", original)
      else
        System.delete_env("TMUX")
      end
    end
  end

  describe "get_current_session/0" do
    @tag :tmux_integration
    test "returns session name when inside tmux" do
      if TmuxAdapter.inside_tmux?() do
        assert {:ok, session_name} = TmuxAdapter.get_current_session()
        assert is_binary(session_name)
        assert String.length(session_name) > 0
      else
        # Skip if not in tmux
        :ok
      end
    end
  end

  describe "create_window/1" do
    @tag :tmux_integration
    test "creates window and returns window ID when inside tmux" do
      if TmuxAdapter.inside_tmux?() do
        window_name = "test-window-#{:rand.uniform(10000)}"

        assert {:ok, window_id} = TmuxAdapter.create_window(window_name)
        assert is_binary(window_id)

        # Verify window was created
        assert TmuxAdapter.window_exists?(window_name)

        # Cleanup
        TmuxAdapter.kill_window(window_name)
      else
        :ok
      end
    end

    @tag :tmux_integration
    test "creates window in detached mode (doesn't switch focus)" do
      if TmuxAdapter.inside_tmux?() do
        window_name = "test-detached-#{:rand.uniform(10000)}"

        # Get current window before creating new one
        {:ok, original_session} = TmuxAdapter.get_current_session()

        assert {:ok, _window_id} = TmuxAdapter.create_window(window_name)

        # Current session should be the same (focus didn't change)
        assert {:ok, ^original_session} = TmuxAdapter.get_current_session()

        # Cleanup
        TmuxAdapter.kill_window(window_name)
      else
        :ok
      end
    end

    @tag :tmux_integration
    test "handles duplicate window names gracefully" do
      if TmuxAdapter.inside_tmux?() do
        window_name = "test-duplicate-#{:rand.uniform(10000)}"

        # Create first window
        assert {:ok, _window_id1} = TmuxAdapter.create_window(window_name)

        # Create second window with same name - tmux handles this by appending numbers
        assert {:ok, _window_id2} = TmuxAdapter.create_window(window_name)

        # Cleanup
        TmuxAdapter.kill_window(window_name)
      else
        :ok
      end
    end
  end

  describe "kill_window/1" do
    @tag :tmux_integration
    test "kills the specified window" do
      if TmuxAdapter.inside_tmux?() do
        window_name = "test-kill-#{:rand.uniform(10000)}"

        # Create window
        {:ok, _window_id} = TmuxAdapter.create_window(window_name)
        assert TmuxAdapter.window_exists?(window_name)

        # Kill it
        assert :ok = TmuxAdapter.kill_window(window_name)

        # Verify it's gone
        refute TmuxAdapter.window_exists?(window_name)
      else
        :ok
      end
    end

    @tag :tmux_integration
    test "is idempotent (returns :ok if window already gone)" do
      if TmuxAdapter.inside_tmux?() do
        window_name = "test-nonexistent-#{:rand.uniform(10000)}"

        # Kill window that doesn't exist
        assert :ok = TmuxAdapter.kill_window(window_name)

        # Kill it again
        assert :ok = TmuxAdapter.kill_window(window_name)
      else
        :ok
      end
    end
  end

  describe "send_keys/2" do
    @tag :tmux_integration
    test "sends command to window and presses Enter" do
      if TmuxAdapter.inside_tmux?() do
        window_name = "test-send-keys-#{:rand.uniform(10000)}"

        # Create window
        {:ok, _window_id} = TmuxAdapter.create_window(window_name)

        # Send command
        assert :ok = TmuxAdapter.send_keys(window_name, "echo 'test'")

        # Cleanup
        TmuxAdapter.kill_window(window_name)
      else
        :ok
      end
    end

    @tag :tmux_integration
    test "returns error when window doesn't exist" do
      if TmuxAdapter.inside_tmux?() do
        window_name = "test-nonexistent-#{:rand.uniform(10000)}"

        assert {:error, _reason} = TmuxAdapter.send_keys(window_name, "echo 'test'")
      else
        :ok
      end
    end
  end

  describe "window_exists?/1" do
    @tag :tmux_integration
    test "returns true for existing windows" do
      if TmuxAdapter.inside_tmux?() do
        window_name = "test-exists-#{:rand.uniform(10000)}"

        # Create window
        {:ok, _window_id} = TmuxAdapter.create_window(window_name)

        # Check it exists
        assert TmuxAdapter.window_exists?(window_name) == true

        # Cleanup
        TmuxAdapter.kill_window(window_name)
      else
        :ok
      end
    end

    @tag :tmux_integration
    test "returns false for non-existent windows" do
      if TmuxAdapter.inside_tmux?() do
        window_name = "test-doesnt-exist-#{:rand.uniform(10000)}"

        assert TmuxAdapter.window_exists?(window_name) == false
      else
        :ok
      end
    end
  end

  describe "join_pane/break_pane flow" do
    @tag :tmux_integration
    test "can join and break panes between multiple windows" do
      if TmuxAdapter.inside_tmux?() do
        window1 = "test-join-1-#{:rand.uniform(10000)}"
        window2 = "test-join-2-#{:rand.uniform(10000)}"

        # Create 2 windows
        assert {:ok, _window_id1} = TmuxAdapter.create_window(window1)
        assert {:ok, _window_id2} = TmuxAdapter.create_window(window2)

        # Verify both windows exist
        assert TmuxAdapter.window_exists?(window1)
        assert TmuxAdapter.window_exists?(window2)

        # Join window 1 into current pane
        assert {:ok, pane_id1} = TmuxAdapter.join_pane(window1, direction: "-v", size: "50%")
        assert is_binary(pane_id1)

        # Window 1 should no longer exist (it only had one pane, which we joined)
        refute TmuxAdapter.window_exists?(window1),
               "Window 1 should be closed after joining its only pane"

        # Break pane back to its own window
        assert :ok = TmuxAdapter.break_pane(pane_id1, window_name: window1)

        # Window 1 should exist again
        assert TmuxAdapter.window_exists?(window1),
               "Window 1 should exist after breaking pane back"

        # Join window 2 into current pane
        assert {:ok, pane_id2} = TmuxAdapter.join_pane(window2, direction: "-v", size: "50%")
        assert is_binary(pane_id2)

        # Window 2 should no longer exist
        refute TmuxAdapter.window_exists?(window2),
               "Window 2 should be closed after joining its only pane"

        # Break pane back to its own window
        assert :ok = TmuxAdapter.break_pane(pane_id2, window_name: window2)

        # Window 2 should exist again
        assert TmuxAdapter.window_exists?(window2),
               "Window 2 should exist after breaking pane back"

        # Cleanup
        TmuxAdapter.kill_window(window1)
        TmuxAdapter.kill_window(window2)
      else
        :ok
      end
    end

    @tag :tmux_integration
    test "break_pane handles duplicate window names by using different name" do
      if TmuxAdapter.inside_tmux?() do
        window_name = "test-break-dup-#{:rand.uniform(10000)}"

        # Create window
        assert {:ok, _window_id} = TmuxAdapter.create_window(window_name)

        # Join its pane
        assert {:ok, pane_id} = TmuxAdapter.join_pane(window_name, direction: "-v", size: "50%")

        # Window should be gone
        refute TmuxAdapter.window_exists?(window_name)

        # Create a new window with the same name
        assert {:ok, _window_id2} = TmuxAdapter.create_window(window_name)
        assert TmuxAdapter.window_exists?(window_name)

        # Try to break pane back with same name (should fail or use different name)
        result = TmuxAdapter.break_pane(pane_id, window_name: window_name)

        # Either it succeeds and tmux creates a numbered variant, or it fails
        # Let's just verify we can handle this case without crashing
        case result do
          :ok ->
            # Success - cleanup any windows created
            TmuxAdapter.kill_window(window_name)

          {:error, _reason} ->
            # Failed as expected - cleanup
            TmuxAdapter.kill_window(window_name)
            TmuxAdapter.kill_pane(pane_id)
        end
      else
        :ok
      end
    end

    @tag :tmux_integration
    test "can switch between multiple windows in the pane" do
      if TmuxAdapter.inside_tmux?() do
        window1 = "test-switch-1-#{:rand.uniform(10000)}"
        window2 = "test-switch-2-#{:rand.uniform(10000)}"

        # Create 2 windows
        assert {:ok, _window_id1} = TmuxAdapter.create_window(window1)
        assert {:ok, _window_id2} = TmuxAdapter.create_window(window2)

        # Put window 1 in the pane
        assert {:ok, pane_id1} = TmuxAdapter.join_pane(window1, direction: "-v", size: "50%")
        refute TmuxAdapter.window_exists?(window1), "Window 1 should be closed"

        # Break it back so we can join window 2
        assert :ok = TmuxAdapter.break_pane(pane_id1, window_name: window1)
        assert TmuxAdapter.window_exists?(window1), "Window 1 should exist again"

        # Put window 2 in the pane
        assert {:ok, pane_id2} = TmuxAdapter.join_pane(window2, direction: "-v", size: "50%")
        refute TmuxAdapter.window_exists?(window2), "Window 2 should be closed"

        # Break it back so we can join window 1 again
        assert :ok = TmuxAdapter.break_pane(pane_id2, window_name: window2)
        assert TmuxAdapter.window_exists?(window2), "Window 2 should exist again"

        # Put window 1 back in the pane
        assert {:ok, pane_id1_again} =
                 TmuxAdapter.join_pane(window1, direction: "-v", size: "50%")

        assert is_binary(pane_id1_again)
        refute TmuxAdapter.window_exists?(window1), "Window 1 should be closed again"

        # Cleanup - break the pane back and kill both windows
        TmuxAdapter.break_pane(pane_id1_again, window_name: window1)
        TmuxAdapter.kill_window(window1)
        TmuxAdapter.kill_window(window2)
      else
        :ok
      end
    end
  end
end

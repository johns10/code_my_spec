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
    @tag :integration
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
    @tag :integration
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

    @tag :integration
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

    @tag :integration
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
    @tag :integration
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

    @tag :integration
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
    @tag :integration
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

    @tag :integration
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
    @tag :integration
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

    @tag :integration
    test "returns false for non-existent windows" do
      if TmuxAdapter.inside_tmux?() do
        window_name = "test-doesnt-exist-#{:rand.uniform(10000)}"

        assert TmuxAdapter.window_exists?(window_name) == false
      else
        :ok
      end
    end

  end
end

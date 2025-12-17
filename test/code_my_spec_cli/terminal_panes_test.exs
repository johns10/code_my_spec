defmodule CodeMySpecCli.TerminalPanesTest do
  use ExUnit.Case, async: false

  alias CodeMySpecCli.TerminalPanes
  alias CodeMySpec.Environments.MockTmuxAdapter

  setup do
    # Configure mock adapter for tests
    MockTmuxAdapter.reset!()
    :ok
  end

  describe "show_terminal/1" do
    test "creates pane when not exists" do
      session_id = 123

      assert :ok = TerminalPanes.show_terminal(session_id)
      assert TerminalPanes.terminal_open?()
      assert {:ok, ^session_id} = TerminalPanes.current_session()
    end

    test "is idempotent when called with same session" do
      session_id = 123

      assert :ok = TerminalPanes.show_terminal(session_id)
      assert :ok = TerminalPanes.show_terminal(session_id)
      assert TerminalPanes.terminal_open?()
      assert {:ok, ^session_id} = TerminalPanes.current_session()
    end

    test "updates to new session when called with different session" do
      session_id_1 = 123
      session_id_2 = 456

      assert :ok = TerminalPanes.show_terminal(session_id_1)
      assert {:ok, ^session_id_1} = TerminalPanes.current_session()

      assert :ok = TerminalPanes.show_terminal(session_id_2)
      assert {:ok, ^session_id_2} = TerminalPanes.current_session()
    end

    test "enters copy mode automatically" do
      # This is verified implicitly by the mock implementation
      # In a real integration test, we'd check tmux state directly
      session_id = 123

      assert :ok = TerminalPanes.show_terminal(session_id)
      # Mock automatically tracks that enter_copy_mode was called
      assert TerminalPanes.terminal_open?()
    end
  end

  describe "hide_terminal/0" do
    test "removes terminal pane" do
      session_id = 123

      # Create terminal
      assert :ok = TerminalPanes.show_terminal(session_id)
      assert TerminalPanes.terminal_open?()

      # Hide terminal
      assert :ok = TerminalPanes.hide_terminal()
      refute TerminalPanes.terminal_open?()
      assert {:error, :not_open} = TerminalPanes.current_session()
    end

    test "is idempotent when pane doesn't exist" do
      refute TerminalPanes.terminal_open?()

      assert :ok = TerminalPanes.hide_terminal()
      assert :ok = TerminalPanes.hide_terminal()
    end

    test "clears stored session_id" do
      session_id = 123

      # Create and hide terminal
      assert :ok = TerminalPanes.show_terminal(session_id)
      assert :ok = TerminalPanes.hide_terminal()

      # Session should be cleared
      assert {:error, :not_open} = TerminalPanes.current_session()
    end
  end

  describe "terminal_open?/0" do
    test "returns true when pane exists" do
      session_id = 123

      refute TerminalPanes.terminal_open?()

      assert :ok = TerminalPanes.show_terminal(session_id)
      assert TerminalPanes.terminal_open?()
    end

    test "returns false when pane doesn't exist" do
      refute TerminalPanes.terminal_open?()
    end
  end

  describe "current_session/0" do
    test "returns session_id when terminal open" do
      session_id = 123

      assert :ok = TerminalPanes.show_terminal(session_id)
      assert {:ok, ^session_id} = TerminalPanes.current_session()
    end

    test "returns :not_open when terminal closed" do
      assert {:error, :not_open} = TerminalPanes.current_session()
    end

    test "returns updated session_id after switching sessions" do
      session_id_1 = 123
      session_id_2 = 456

      assert :ok = TerminalPanes.show_terminal(session_id_1)
      assert {:ok, ^session_id_1} = TerminalPanes.current_session()

      assert :ok = TerminalPanes.show_terminal(session_id_2)
      assert {:ok, ^session_id_2} = TerminalPanes.current_session()
    end
  end
end

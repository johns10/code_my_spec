defmodule CodeMySpec.ContentSync.FileWatcher.ImplTest do
  use ExUnit.Case, async: true

  alias CodeMySpec.ContentSync.FileWatcher.Impl
  alias CodeMySpec.Users.Scope

  # ============================================================================
  # relevant_event?/1 - Pure Function Tests
  # ============================================================================

  describe "relevant_event?/1" do
    test "returns true for :modified events" do
      assert Impl.relevant_event?([:modified])
    end

    test "returns true for :created events" do
      assert Impl.relevant_event?([:created])
    end

    test "returns true for :removed events" do
      assert Impl.relevant_event?([:removed])
    end

    test "returns true when list contains multiple relevant events" do
      assert Impl.relevant_event?([:modified, :created])
      assert Impl.relevant_event?([:created, :removed])
      assert Impl.relevant_event?([:modified, :created, :removed])
    end

    test "returns true when relevant event is mixed with irrelevant ones" do
      assert Impl.relevant_event?([:other, :modified, :unknown])
    end

    test "returns false for empty list" do
      refute Impl.relevant_event?([])
    end

    test "returns false for irrelevant events" do
      refute Impl.relevant_event?([:other])
      refute Impl.relevant_event?([:unknown, :irrelevant])
    end

    test "returns false for non-list input" do
      refute Impl.relevant_event?(nil)
      refute Impl.relevant_event?("string")
      refute Impl.relevant_event?(%{})
    end
  end

  # ============================================================================
  # validate_directory/1 - Pure Function Tests
  # ============================================================================

  describe "validate_directory/1" do
    test "returns :ok for valid directory" do
      assert :ok = Impl.validate_directory(System.tmp_dir!())
    end

    test "returns error for nonexistent directory" do
      assert {:error, :invalid_directory} = Impl.validate_directory("/nonexistent/path")
    end

    test "returns error for file (not directory)" do
      file_path = Path.join(System.tmp_dir!(), "test_file_#{System.unique_integer([:positive])}")
      File.write!(file_path, "test")

      assert {:error, :invalid_directory} = Impl.validate_directory(file_path)

      File.rm!(file_path)
    end

    test "returns error for empty string" do
      assert {:error, :invalid_directory} = Impl.validate_directory("")
    end
  end

  # ============================================================================
  # build_config/1 - Configuration Building Tests
  # ============================================================================

  describe "build_config/1" do
    test "builds config from options with all fields provided" do
      scope = %Scope{active_account_id: 1, active_project_id: 2}
      sync_fn = fn _scope, _directory -> {:ok, %{}} end

      opts = [
        directory: System.tmp_dir!(),
        scope: scope,
        debounce_ms: 500,
        sync_fn: sync_fn
      ]

      assert {:ok, config} = Impl.build_config(opts)
      assert config.directory == System.tmp_dir!()
      assert config.scope == scope
      assert config.debounce_ms == 500
      assert config.sync_fn == sync_fn
    end

    test "uses default debounce_ms when not provided" do
      scope = %Scope{active_account_id: 1, active_project_id: 2}

      opts = [
        directory: System.tmp_dir!(),
        scope: scope
      ]

      assert {:ok, config} = Impl.build_config(opts)
      assert config.debounce_ms == 1000
    end

    test "uses default sync_fn when not provided" do
      scope = %Scope{active_account_id: 1, active_project_id: 2}

      opts = [
        directory: System.tmp_dir!(),
        scope: scope
      ]

      assert {:ok, config} = Impl.build_config(opts)
      assert is_function(config.sync_fn, 2)
    end

    test "returns error when directory is missing" do
      scope = %Scope{active_account_id: 1, active_project_id: 2}

      opts = [scope: scope]

      assert {:error, :missing_directory_config} = Impl.build_config(opts)
    end

    test "returns error when scope is missing" do
      opts = [directory: System.tmp_dir!()]

      assert {:error, _reason} = Impl.build_config(opts)
    end

    test "returns error when directory is empty string" do
      scope = %Scope{active_account_id: 1, active_project_id: 2}

      opts = [directory: "", scope: scope]

      assert {:error, :missing_directory_config} = Impl.build_config(opts)
    end
  end

  # ============================================================================
  # validate_config/1 - Configuration Validation Tests
  # ============================================================================

  describe "validate_config/1" do
    test "returns :ok for valid config" do
      config = %{directory: System.tmp_dir!()}

      assert :ok = Impl.validate_config(config)
    end

    test "returns error for invalid directory" do
      config = %{directory: "/nonexistent"}

      assert {:error, :invalid_directory} = Impl.validate_config(config)
    end
  end

  # ============================================================================
  # new_state/1 - State Initialization Tests
  # ============================================================================

  describe "new_state/1" do
    test "creates initial state from config" do
      scope = %Scope{active_account_id: 1, active_project_id: 2}
      sync_fn = fn _scope, _directory -> {:ok, %{}} end

      config = %{
        directory: "/tmp/test",
        scope: scope,
        debounce_ms: 500,
        sync_fn: sync_fn
      }

      state = Impl.new_state(config)

      assert state.scope == scope
      assert state.watched_directory == "/tmp/test"
      assert state.debounce_ms == 500
      assert state.sync_fn == sync_fn
      assert state.debounce_timer == nil
    end
  end

  # ============================================================================
  # handle_file_event/3 - State Transformation Tests
  # ============================================================================

  describe "handle_file_event/3" do
    setup do
      scope = %Scope{active_account_id: 1, active_project_id: 2}
      sync_fn = fn _scope, _directory -> {:ok, %{}} end

      state = %Impl{
        scope: scope,
        watched_directory: "/tmp/test",
        debounce_ms: 1000,
        sync_fn: sync_fn,
        debounce_timer: nil
      }

      %{state: state}
    end

    test "returns schedule_sync for relevant events", %{state: state} do
      assert {:schedule_sync, 1000, new_state} =
               Impl.handle_file_event(state, "/tmp/test/file.md", [:modified])

      assert new_state.debounce_timer == nil
    end

    test "returns noreply for irrelevant events", %{state: state} do
      assert {:noreply, ^state} = Impl.handle_file_event(state, "/tmp/test/file.md", [:other])
    end

    test "returns noreply for empty event list", %{state: state} do
      assert {:noreply, ^state} = Impl.handle_file_event(state, "/tmp/test/file.md", [])
    end

    test "works with :created events", %{state: state} do
      assert {:schedule_sync, 1000, _new_state} =
               Impl.handle_file_event(state, "/tmp/test/file.md", [:created])
    end

    test "works with :removed events", %{state: state} do
      assert {:schedule_sync, 1000, _new_state} =
               Impl.handle_file_event(state, "/tmp/test/file.md", [:removed])
    end

    test "returns correct debounce_ms from state", %{state: state} do
      fast_state = %{state | debounce_ms: 50}

      assert {:schedule_sync, 50, _new_state} =
               Impl.handle_file_event(fast_state, "/tmp/test/file.md", [:modified])
    end
  end

  # ============================================================================
  # update_timer/2 - Timer Update Tests
  # ============================================================================

  describe "update_timer/2" do
    test "updates state with timer reference" do
      scope = %Scope{active_account_id: 1, active_project_id: 2}

      state = %Impl{
        scope: scope,
        watched_directory: "/tmp/test",
        debounce_ms: 1000,
        sync_fn: fn _ -> {:ok, %{}} end,
        debounce_timer: nil
      }

      timer_ref = make_ref()
      new_state = Impl.update_timer(state, timer_ref)

      assert new_state.debounce_timer == timer_ref
    end
  end

  # ============================================================================
  # handle_sync_trigger/1 - Sync Trigger Tests
  # ============================================================================

  describe "handle_sync_trigger/1" do
    test "returns scope, sync_fn, and clears timer" do
      scope = %Scope{active_account_id: 1, active_project_id: 2}
      sync_fn = fn _scope, _directory -> {:ok, %{}} end
      timer_ref = make_ref()

      state = %Impl{
        scope: scope,
        watched_directory: "/tmp/test",
        debounce_ms: 1000,
        sync_fn: sync_fn,
        debounce_timer: timer_ref
      }

      {returned_scope, returned_sync_fn, new_state} = Impl.handle_sync_trigger(state)

      assert returned_scope == scope
      assert returned_sync_fn == sync_fn
      assert new_state.debounce_timer == nil
    end
  end

  # ============================================================================
  # clear_timer/1 - Timer Clearing Tests
  # ============================================================================

  describe "clear_timer/1" do
    test "clears timer reference from state" do
      scope = %Scope{active_account_id: 1, active_project_id: 2}
      timer_ref = make_ref()

      state = %Impl{
        scope: scope,
        watched_directory: "/tmp/test",
        debounce_ms: 1000,
        sync_fn: fn _ -> {:ok, %{}} end,
        debounce_timer: timer_ref
      }

      new_state = Impl.clear_timer(state)

      assert new_state.debounce_timer == nil
    end

    test "works when timer is already nil" do
      scope = %Scope{active_account_id: 1, active_project_id: 2}

      state = %Impl{
        scope: scope,
        watched_directory: "/tmp/test",
        debounce_ms: 1000,
        sync_fn: fn _ -> {:ok, %{}} end,
        debounce_timer: nil
      }

      new_state = Impl.clear_timer(state)

      assert new_state.debounce_timer == nil
    end
  end
end

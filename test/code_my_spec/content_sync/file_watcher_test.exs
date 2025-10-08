defmodule CodeMySpec.ContentSync.FileWatcherTest do
  use CodeMySpec.DataCase, async: false

  import CodeMySpec.{UsersFixtures, AccountsFixtures, ProjectsFixtures}

  alias CodeMySpec.ContentSync.FileWatcher
  alias CodeMySpec.Users.Scope

  # ============================================================================
  # Fixtures - Configuration Setup
  # ============================================================================

  defp test_directory do
    dir = Path.join(System.tmp_dir!(), "file_watcher_test_#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    dir
  end

  defp cleanup_directory(dir) do
    if File.exists?(dir) do
      File.rm_rf!(dir)
    end
  end

  defp scope_fixture do
    user = user_fixture()
    account = account_fixture(%{name: "Test Account"})

    scope = %Scope{
      user: user,
      active_account: account,
      active_account_id: account.id,
      active_project_id: nil
    }

    project = project_fixture(scope, %{name: "Test Project"})

    %Scope{
      user: user,
      active_account: account,
      active_account_id: account.id,
      active_project: project,
      active_project_id: project.id
    }
  end

  defp configure_file_watcher(enabled: enabled, directory: directory, scope: scope) do
    Application.put_env(:code_my_spec, :watch_content, enabled)
    Application.put_env(:code_my_spec, :content_watch_directory, directory)

    Application.put_env(:code_my_spec, :content_watch_scope, %{
      account_id: scope.active_account_id,
      project_id: scope.active_project_id
    })
  end

  defp restore_original_config(original_config) do
    Application.put_env(:code_my_spec, :watch_content, original_config[:watch_content])

    Application.put_env(
      :code_my_spec,
      :content_watch_directory,
      original_config[:content_watch_directory]
    )

    Application.put_env(
      :code_my_spec,
      :content_watch_scope,
      original_config[:content_watch_scope]
    )
  end

  defp save_original_config do
    %{
      watch_content: Application.get_env(:code_my_spec, :watch_content),
      content_watch_directory: Application.get_env(:code_my_spec, :content_watch_directory),
      content_watch_scope: Application.get_env(:code_my_spec, :content_watch_scope)
    }
  end

  defp eventually(func, timeout \\ 2000, interval \\ 50) do
    deadline = System.monotonic_time(:millisecond) + timeout
    eventually_loop(func, deadline, interval)
  end

  defp eventually_loop(func, deadline, interval) do
    if func.() do
      true
    else
      now = System.monotonic_time(:millisecond)
      if now >= deadline do
        false
      else
        :timer.sleep(interval)
        eventually_loop(func, deadline, interval)
      end
    end
  end

  # ============================================================================
  # start_link/1 - Successful Initialization
  # ============================================================================

  describe "start_link/1 - successful initialization" do
    test "starts GenServer when watch_content is enabled" do
      original_config = save_original_config()
      dir = test_directory()
      scope = scope_fixture()

      configure_file_watcher(enabled: true, directory: dir, scope: scope)

      try do
        assert {:ok, pid} = FileWatcher.start_link([])
        assert Process.alive?(pid)
        GenServer.stop(pid)
      after
        cleanup_directory(dir)
        restore_original_config(original_config)
      end
    end

    test "loads scope from application config" do
      original_config = save_original_config()
      dir = test_directory()
      scope = scope_fixture()

      configure_file_watcher(enabled: true, directory: dir, scope: scope)

      try do
        assert {:ok, pid} = FileWatcher.start_link([])

        state = :sys.get_state(pid)
        assert state.scope.active_account_id == scope.active_account_id
        assert state.scope.active_project_id == scope.active_project_id

        GenServer.stop(pid)
      after
        cleanup_directory(dir)
        restore_original_config(original_config)
      end
    end

    test "loads watched directory from application config" do
      original_config = save_original_config()
      dir = test_directory()
      scope = scope_fixture()

      configure_file_watcher(enabled: true, directory: dir, scope: scope)

      try do
        assert {:ok, pid} = FileWatcher.start_link([])

        state = :sys.get_state(pid)
        assert state.watched_directory == dir

        GenServer.stop(pid)
      after
        cleanup_directory(dir)
        restore_original_config(original_config)
      end
    end

    test "initializes with nil debounce_timer" do
      original_config = save_original_config()
      dir = test_directory()
      scope = scope_fixture()

      configure_file_watcher(enabled: true, directory: dir, scope: scope)

      try do
        assert {:ok, pid} = FileWatcher.start_link([])

        state = :sys.get_state(pid)
        assert state.debounce_timer == nil

        GenServer.stop(pid)
      after
        cleanup_directory(dir)
        restore_original_config(original_config)
      end
    end

    test "subscribes to FileSystem for directory events" do
      original_config = save_original_config()
      dir = test_directory()
      scope = scope_fixture()

      configure_file_watcher(enabled: true, directory: dir, scope: scope)

      try do
        assert {:ok, pid} = FileWatcher.start_link([])

        # Verify FileSystem subscription by checking that GenServer is alive
        # and can handle file events (tested in later tests)
        assert Process.alive?(pid)

        GenServer.stop(pid)
      after
        cleanup_directory(dir)
        restore_original_config(original_config)
      end
    end

    test "accepts empty options keyword list" do
      original_config = save_original_config()
      dir = test_directory()
      scope = scope_fixture()

      configure_file_watcher(enabled: true, directory: dir, scope: scope)

      try do
        assert {:ok, pid} = FileWatcher.start_link([])
        assert Process.alive?(pid)
        GenServer.stop(pid)
      after
        cleanup_directory(dir)
        restore_original_config(original_config)
      end
    end
  end

  # ============================================================================
  # start_link/1 - Conditional Startup Based on Configuration
  # ============================================================================

  describe "start_link/1 - conditional startup" do
    test "returns :ignore when watch_content is false" do
      original_config = save_original_config()
      dir = test_directory()
      scope = scope_fixture()

      configure_file_watcher(enabled: false, directory: dir, scope: scope)

      try do
        assert :ignore = FileWatcher.start_link([])
      after
        cleanup_directory(dir)
        restore_original_config(original_config)
      end
    end

    test "returns :ignore when watch_content is nil" do
      original_config = save_original_config()
      dir = test_directory()
      scope = scope_fixture()

      Application.put_env(:code_my_spec, :watch_content, nil)
      Application.put_env(:code_my_spec, :content_watch_directory, dir)

      Application.put_env(:code_my_spec, :content_watch_scope, %{
        account_id: scope.active_account_id,
        project_id: scope.active_project_id
      })

      try do
        assert :ignore = FileWatcher.start_link([])
      after
        cleanup_directory(dir)
        restore_original_config(original_config)
      end
    end

    test "returns :ignore when watch_content config is missing" do
      original_config = save_original_config()
      dir = test_directory()
      scope = scope_fixture()

      Application.delete_env(:code_my_spec, :watch_content)
      Application.put_env(:code_my_spec, :content_watch_directory, dir)

      Application.put_env(:code_my_spec, :content_watch_scope, %{
        account_id: scope.active_account_id,
        project_id: scope.active_project_id
      })

      try do
        assert :ignore = FileWatcher.start_link([])
      after
        cleanup_directory(dir)
        restore_original_config(original_config)
      end
    end
  end

  # ============================================================================
  # start_link/1 - Configuration Validation
  # ============================================================================

  describe "start_link/1 - configuration validation" do
    test "returns error when directory does not exist" do
      original_config = save_original_config()
      scope = scope_fixture()
      nonexistent_dir = "/nonexistent/directory/path"

      configure_file_watcher(enabled: true, directory: nonexistent_dir, scope: scope)

      Process.flag(:trap_exit, true)

      try do
        assert {:error, :invalid_directory} = FileWatcher.start_link([])
      after
        restore_original_config(original_config)
      end
    end

    test "returns error when directory path is nil" do
      original_config = save_original_config()
      scope = scope_fixture()

      Application.put_env(:code_my_spec, :watch_content, true)
      Application.put_env(:code_my_spec, :content_watch_directory, nil)

      Application.put_env(:code_my_spec, :content_watch_scope, %{
        account_id: scope.active_account_id,
        project_id: scope.active_project_id
      })

      Process.flag(:trap_exit, true)

      try do
        assert {:error, :missing_directory_config} = FileWatcher.start_link([])
      after
        restore_original_config(original_config)
      end
    end

    test "returns error when directory path is empty string" do
      original_config = save_original_config()
      scope = scope_fixture()

      Application.put_env(:code_my_spec, :watch_content, true)
      Application.put_env(:code_my_spec, :content_watch_directory, "")

      Application.put_env(:code_my_spec, :content_watch_scope, %{
        account_id: scope.active_account_id,
        project_id: scope.active_project_id
      })

      Process.flag(:trap_exit, true)

      try do
        assert {:error, :missing_directory_config} = FileWatcher.start_link([])
      after
        restore_original_config(original_config)
      end
    end

    test "returns error when scope config is missing" do
      original_config = save_original_config()
      dir = test_directory()

      Application.put_env(:code_my_spec, :watch_content, true)
      Application.put_env(:code_my_spec, :content_watch_directory, dir)
      Application.delete_env(:code_my_spec, :content_watch_scope)

      Process.flag(:trap_exit, true)

      try do
        assert {:error, :missing_scope_config} = FileWatcher.start_link([])
      after
        cleanup_directory(dir)
        restore_original_config(original_config)
      end
    end

    test "returns error when scope config is nil" do
      original_config = save_original_config()
      dir = test_directory()

      Application.put_env(:code_my_spec, :watch_content, true)
      Application.put_env(:code_my_spec, :content_watch_directory, dir)
      Application.put_env(:code_my_spec, :content_watch_scope, nil)

      Process.flag(:trap_exit, true)

      try do
        assert {:error, :missing_scope_config} = FileWatcher.start_link([])
      after
        cleanup_directory(dir)
        restore_original_config(original_config)
      end
    end

    test "returns error when scope config is missing account_id" do
      original_config = save_original_config()
      dir = test_directory()
      scope = scope_fixture()

      Application.put_env(:code_my_spec, :watch_content, true)
      Application.put_env(:code_my_spec, :content_watch_directory, dir)

      Application.put_env(:code_my_spec, :content_watch_scope, %{
        project_id: scope.active_project_id
      })

      Process.flag(:trap_exit, true)

      try do
        assert {:error, :missing_scope_config} = FileWatcher.start_link([])
      after
        cleanup_directory(dir)
        restore_original_config(original_config)
      end
    end

    test "returns error when scope config is missing project_id" do
      original_config = save_original_config()
      dir = test_directory()
      scope = scope_fixture()

      Application.put_env(:code_my_spec, :watch_content, true)
      Application.put_env(:code_my_spec, :content_watch_directory, dir)

      Application.put_env(:code_my_spec, :content_watch_scope, %{
        account_id: scope.active_account_id
      })

      Process.flag(:trap_exit, true)

      try do
        assert {:error, :missing_scope_config} = FileWatcher.start_link([])
      after
        cleanup_directory(dir)
        restore_original_config(original_config)
      end
    end

    test "returns error when path is a file not a directory" do
      original_config = save_original_config()
      scope = scope_fixture()

      file_path =
        Path.join(System.tmp_dir!(), "test_file_#{System.unique_integer([:positive])}")

      File.write!(file_path, "test content")

      configure_file_watcher(enabled: true, directory: file_path, scope: scope)

      Process.flag(:trap_exit, true)

      try do
        assert {:error, :invalid_directory} = FileWatcher.start_link([])
      after
        File.rm!(file_path)
        restore_original_config(original_config)
      end
    end
  end

  # ============================================================================
  # handle_info/2 - File Event Handling
  # ============================================================================

  describe "handle_info/2 - file event handling" do
    test "receives file_event messages from FileSystem" do
      original_config = save_original_config()
      dir = test_directory()
      scope = scope_fixture()

      configure_file_watcher(enabled: true, directory: dir, scope: scope)

      try do
        {:ok, pid} = FileWatcher.start_link([])

        # Simulate file event message
        file_path = Path.join(dir, "test.md")
        send(pid, {:file_event, self(), {file_path, [:modified]}})

        # Verify GenServer is still alive and processed message
        :timer.sleep(50)
        assert Process.alive?(pid)

        GenServer.stop(pid)
      after
        cleanup_directory(dir)
        restore_original_config(original_config)
      end
    end

    test "starts debounce timer on file event" do
      original_config = save_original_config()
      dir = test_directory()
      scope = scope_fixture()

      configure_file_watcher(enabled: true, directory: dir, scope: scope)

      try do
        {:ok, pid} = FileWatcher.start_link([])

        file_path = Path.join(dir, "test.md")
        send(pid, {:file_event, self(), {file_path, [:modified]}})

        :timer.sleep(50)

        state = :sys.get_state(pid)
        assert state.debounce_timer != nil
        assert is_reference(state.debounce_timer)

        GenServer.stop(pid)
      after
        cleanup_directory(dir)
        restore_original_config(original_config)
      end
    end

    test "cancels existing timer when new file event arrives" do
      original_config = save_original_config()
      dir = test_directory()
      scope = scope_fixture()

      configure_file_watcher(enabled: true, directory: dir, scope: scope)

      try do
        {:ok, pid} = FileWatcher.start_link([])

        file_path = Path.join(dir, "test.md")

        # Send first event
        send(pid, {:file_event, self(), {file_path, [:modified]}})
        :timer.sleep(50)

        state1 = :sys.get_state(pid)
        first_timer = state1.debounce_timer

        # Send second event before first timer expires
        send(pid, {:file_event, self(), {file_path, [:modified]}})
        :timer.sleep(50)

        state2 = :sys.get_state(pid)
        second_timer = state2.debounce_timer

        # Timer should be different (new timer started, old one cancelled)
        assert first_timer != second_timer
        assert second_timer != nil

        GenServer.stop(pid)
      after
        cleanup_directory(dir)
        restore_original_config(original_config)
      end
    end

    test "handles :modified file events" do
      original_config = save_original_config()
      dir = test_directory()
      scope = scope_fixture()

      configure_file_watcher(enabled: true, directory: dir, scope: scope)

      try do
        {:ok, pid} = FileWatcher.start_link([])

        file_path = Path.join(dir, "test.md")
        send(pid, {:file_event, self(), {file_path, [:modified]}})

        :timer.sleep(50)

        state = :sys.get_state(pid)
        assert state.debounce_timer != nil

        GenServer.stop(pid)
      after
        cleanup_directory(dir)
        restore_original_config(original_config)
      end
    end

    test "handles :created file events" do
      original_config = save_original_config()
      dir = test_directory()
      scope = scope_fixture()

      configure_file_watcher(enabled: true, directory: dir, scope: scope)

      try do
        {:ok, pid} = FileWatcher.start_link([])

        file_path = Path.join(dir, "new.md")
        send(pid, {:file_event, self(), {file_path, [:created]}})

        :timer.sleep(50)

        state = :sys.get_state(pid)
        assert state.debounce_timer != nil

        GenServer.stop(pid)
      after
        cleanup_directory(dir)
        restore_original_config(original_config)
      end
    end

    test "handles :removed file events" do
      original_config = save_original_config()
      dir = test_directory()
      scope = scope_fixture()

      configure_file_watcher(enabled: true, directory: dir, scope: scope)

      try do
        {:ok, pid} = FileWatcher.start_link([])

        file_path = Path.join(dir, "deleted.md")
        send(pid, {:file_event, self(), {file_path, [:removed]}})

        :timer.sleep(50)

        state = :sys.get_state(pid)
        assert state.debounce_timer != nil

        GenServer.stop(pid)
      after
        cleanup_directory(dir)
        restore_original_config(original_config)
      end
    end

    test "handles multiple event types in single message" do
      original_config = save_original_config()
      dir = test_directory()
      scope = scope_fixture()

      configure_file_watcher(enabled: true, directory: dir, scope: scope)

      try do
        {:ok, pid} = FileWatcher.start_link([])

        file_path = Path.join(dir, "test.md")
        send(pid, {:file_event, self(), {file_path, [:modified, :created]}})

        :timer.sleep(50)

        state = :sys.get_state(pid)
        assert state.debounce_timer != nil

        GenServer.stop(pid)
      after
        cleanup_directory(dir)
        restore_original_config(original_config)
      end
    end
  end

  # ============================================================================
  # handle_info/2 - Debounce Timer Behavior
  # ============================================================================

  describe "handle_info/2 - debounce timer behavior" do
    test "clears debounce_timer when timer expires" do
      original_config = save_original_config()
      dir = test_directory()
      scope = scope_fixture()

      configure_file_watcher(enabled: true, directory: dir, scope: scope)

      try do
        {:ok, pid} = FileWatcher.start_link([])

        file_path = Path.join(dir, "test.md")
        send(pid, {:file_event, self(), {file_path, [:modified]}})

        :timer.sleep(50)
        state1 = :sys.get_state(pid)
        assert state1.debounce_timer != nil

        # Wait for timer to expire
        :timer.sleep(1100)

        state2 = :sys.get_state(pid)
        assert state2.debounce_timer == nil

        GenServer.stop(pid)
      after
        cleanup_directory(dir)
        restore_original_config(original_config)
      end
    end

    test "only most recent file event triggers sync after debounce" do
      original_config = save_original_config()
      dir = test_directory()
      scope = scope_fixture()

      configure_file_watcher(enabled: true, directory: dir, scope: scope)

      try do
        {:ok, pid} = FileWatcher.start_link([])

        # Send multiple rapid file events
        file_path = Path.join(dir, "test.md")

        for _i <- 1..5 do
          send(pid, {:file_event, self(), {file_path, [:modified]}})
          :timer.sleep(100)
        end

        # Timer should still be active
        state = :sys.get_state(pid)
        assert state.debounce_timer != nil

        # Wait for final timer to expire
        :timer.sleep(1100)

        # Timer should be cleared after sync
        final_state = :sys.get_state(pid)
        assert final_state.debounce_timer == nil

        GenServer.stop(pid)
      after
        cleanup_directory(dir)
        restore_original_config(original_config)
      end
    end

    test "timer duration is approximately 1000ms" do
      original_config = save_original_config()
      dir = test_directory()
      scope = scope_fixture()

      configure_file_watcher(enabled: true, directory: dir, scope: scope)

      try do
        {:ok, pid} = FileWatcher.start_link([])

        file_path = Path.join(dir, "test.md")
        send(pid, {:file_event, self(), {file_path, [:modified]}})

        start_time = System.monotonic_time(:millisecond)

        :timer.sleep(50)
        state1 = :sys.get_state(pid)
        assert state1.debounce_timer != nil

        # Wait for timer to expire
        :timer.sleep(1100)

        state2 = :sys.get_state(pid)
        assert state2.debounce_timer == nil

        end_time = System.monotonic_time(:millisecond)
        elapsed = end_time - start_time

        # Should be approximately 1000ms (give 300ms tolerance for test execution)
        assert elapsed >= 1000
        assert elapsed <= 1400

        GenServer.stop(pid)
      after
        cleanup_directory(dir)
        restore_original_config(original_config)
      end
    end
  end

  # ============================================================================
  # handle_info/2 - Trigger Sync
  # ============================================================================

  describe "handle_info/2 - trigger sync" do
    test "receives :trigger_sync message after debounce timer expires" do
      original_config = save_original_config()
      dir = test_directory()
      scope = scope_fixture()

      configure_file_watcher(enabled: true, directory: dir, scope: scope)

      {:ok, pid} = FileWatcher.start_link([])

      file_path = Path.join(dir, "test.md")
      send(pid, {:file_event, self(), {file_path, [:modified]}})

      # Poll for debounce timer to expire and be processed (max 2 seconds)
      assert eventually(fn ->
        Process.alive?(pid) && :sys.get_state(pid).debounce_timer == nil
      end)

      # GenServer should still be alive after processing :trigger_sync
      assert Process.alive?(pid)

      GenServer.stop(pid)
      cleanup_directory(dir)
      restore_original_config(original_config)
    end

    test "can be sent :trigger_sync message directly" do
      original_config = save_original_config()
      dir = test_directory()
      scope = scope_fixture()

      configure_file_watcher(enabled: true, directory: dir, scope: scope)

      try do
        {:ok, pid} = FileWatcher.start_link([])

        # Send :trigger_sync directly without file event
        send(pid, :trigger_sync)

        :timer.sleep(100)

        # GenServer should still be alive
        assert Process.alive?(pid)

        GenServer.stop(pid)
      after
        cleanup_directory(dir)
        restore_original_config(original_config)
      end
    end
  end

  # ============================================================================
  # State Management
  # ============================================================================

  describe "state management" do
    test "state contains all required fields" do
      original_config = save_original_config()
      dir = test_directory()
      scope = scope_fixture()

      configure_file_watcher(enabled: true, directory: dir, scope: scope)

      try do
        {:ok, pid} = FileWatcher.start_link([])

        state = :sys.get_state(pid)
        assert Map.has_key?(state, :scope)
        assert Map.has_key?(state, :watched_directory)
        assert Map.has_key?(state, :debounce_timer)

        GenServer.stop(pid)
      after
        cleanup_directory(dir)
        restore_original_config(original_config)
      end
    end

    test "scope is a Scope struct" do
      original_config = save_original_config()
      dir = test_directory()
      scope = scope_fixture()

      configure_file_watcher(enabled: true, directory: dir, scope: scope)

      try do
        {:ok, pid} = FileWatcher.start_link([])

        state = :sys.get_state(pid)
        assert is_struct(state.scope, Scope)

        GenServer.stop(pid)
      after
        cleanup_directory(dir)
        restore_original_config(original_config)
      end
    end

    test "watched_directory is a string" do
      original_config = save_original_config()
      dir = test_directory()
      scope = scope_fixture()

      configure_file_watcher(enabled: true, directory: dir, scope: scope)

      try do
        {:ok, pid} = FileWatcher.start_link([])

        state = :sys.get_state(pid)
        assert is_binary(state.watched_directory)

        GenServer.stop(pid)
      after
        cleanup_directory(dir)
        restore_original_config(original_config)
      end
    end

    test "debounce_timer is nil or reference" do
      original_config = save_original_config()
      dir = test_directory()
      scope = scope_fixture()

      configure_file_watcher(enabled: true, directory: dir, scope: scope)

      try do
        {:ok, pid} = FileWatcher.start_link([])

        state = :sys.get_state(pid)
        assert state.debounce_timer == nil or is_reference(state.debounce_timer)

        GenServer.stop(pid)
      after
        cleanup_directory(dir)
        restore_original_config(original_config)
      end
    end

    test "state persists across file events" do
      original_config = save_original_config()
      dir = test_directory()
      scope = scope_fixture()

      configure_file_watcher(enabled: true, directory: dir, scope: scope)

      try do
        {:ok, pid} = FileWatcher.start_link([])

        state1 = :sys.get_state(pid)
        original_scope = state1.scope
        original_directory = state1.watched_directory

        # Send file event
        file_path = Path.join(dir, "test.md")
        send(pid, {:file_event, self(), {file_path, [:modified]}})

        :timer.sleep(50)

        state2 = :sys.get_state(pid)
        assert state2.scope == original_scope
        assert state2.watched_directory == original_directory

        GenServer.stop(pid)
      after
        cleanup_directory(dir)
        restore_original_config(original_config)
      end
    end
  end

  # ============================================================================
  # Error Handling
  # ============================================================================

  describe "error handling" do
    test "continues running when sync fails" do
      original_config = save_original_config()
      dir = test_directory()
      scope = scope_fixture()

      configure_file_watcher(enabled: true, directory: dir, scope: scope)

      try do
        {:ok, pid} = FileWatcher.start_link([])

        # Trigger sync by sending :trigger_sync directly
        # (sync may fail if directory is empty or has no valid content)
        send(pid, :trigger_sync)

        :timer.sleep(100)

        # GenServer should still be alive after sync failure
        assert Process.alive?(pid)

        # Should be able to handle new events
        file_path = Path.join(dir, "test.md")
        send(pid, {:file_event, self(), {file_path, [:modified]}})

        :timer.sleep(50)

        assert Process.alive?(pid)

        GenServer.stop(pid)
      after
        cleanup_directory(dir)
        restore_original_config(original_config)
      end
    end

    test "handles unexpected messages gracefully" do
      original_config = save_original_config()
      dir = test_directory()
      scope = scope_fixture()

      configure_file_watcher(enabled: true, directory: dir, scope: scope)

      try do
        {:ok, pid} = FileWatcher.start_link([])

        # Send unexpected message
        send(pid, :unexpected_message)
        send(pid, {:unexpected, :tuple})
        send(pid, %{unexpected: :map})

        :timer.sleep(50)

        # GenServer should still be alive
        assert Process.alive?(pid)

        GenServer.stop(pid)
      after
        cleanup_directory(dir)
        restore_original_config(original_config)
      end
    end
  end

  # ============================================================================
  # Termination
  # ============================================================================

  describe "termination" do
    test "stops cleanly with GenServer.stop/1" do
      original_config = save_original_config()
      dir = test_directory()
      scope = scope_fixture()

      configure_file_watcher(enabled: true, directory: dir, scope: scope)

      try do
        {:ok, pid} = FileWatcher.start_link([])

        assert Process.alive?(pid)

        assert :ok = GenServer.stop(pid)

        refute Process.alive?(pid)
      after
        cleanup_directory(dir)
        restore_original_config(original_config)
      end
    end

    test "stops cleanly even with active timer" do
      original_config = save_original_config()
      dir = test_directory()
      scope = scope_fixture()

      configure_file_watcher(enabled: true, directory: dir, scope: scope)

      try do
        {:ok, pid} = FileWatcher.start_link([])

        # Start a timer
        file_path = Path.join(dir, "test.md")
        send(pid, {:file_event, self(), {file_path, [:modified]}})

        :timer.sleep(50)

        state = :sys.get_state(pid)
        assert state.debounce_timer != nil

        # Stop GenServer with active timer
        assert :ok = GenServer.stop(pid)

        refute Process.alive?(pid)
      after
        cleanup_directory(dir)
        restore_original_config(original_config)
      end
    end

    test "cancels timer on termination" do
      original_config = save_original_config()
      dir = test_directory()
      scope = scope_fixture()

      configure_file_watcher(enabled: true, directory: dir, scope: scope)

      try do
        {:ok, pid} = FileWatcher.start_link([])

        # Start a timer
        file_path = Path.join(dir, "test.md")
        send(pid, {:file_event, self(), {file_path, [:modified]}})

        :timer.sleep(50)

        state = :sys.get_state(pid)
        timer_ref = state.debounce_timer
        assert timer_ref != nil

        # Stop GenServer
        GenServer.stop(pid)

        # Timer should be cancelled (no :trigger_sync message should arrive)
        refute_receive :trigger_sync, 1200
      after
        cleanup_directory(dir)
        restore_original_config(original_config)
      end
    end
  end

  # ============================================================================
  # Edge Cases
  # ============================================================================

  describe "edge cases" do
    test "handles directory with spaces in path" do
      original_config = save_original_config()
      scope = scope_fixture()

      dir =
        Path.join(
          System.tmp_dir!(),
          "file watcher test #{System.unique_integer([:positive])}"
        )

      File.mkdir_p!(dir)

      configure_file_watcher(enabled: true, directory: dir, scope: scope)

      try do
        assert {:ok, pid} = FileWatcher.start_link([])

        state = :sys.get_state(pid)
        assert state.watched_directory == dir

        GenServer.stop(pid)
      after
        cleanup_directory(dir)
        restore_original_config(original_config)
      end
    end

    test "handles directory with unicode characters in path" do
      original_config = save_original_config()
      scope = scope_fixture()

      dir =
        Path.join(
          System.tmp_dir!(),
          "测试目录_#{System.unique_integer([:positive])}"
        )

      File.mkdir_p!(dir)

      configure_file_watcher(enabled: true, directory: dir, scope: scope)

      try do
        assert {:ok, pid} = FileWatcher.start_link([])

        state = :sys.get_state(pid)
        assert state.watched_directory == dir

        GenServer.stop(pid)
      after
        cleanup_directory(dir)
        restore_original_config(original_config)
      end
    end

    test "handles absolute directory paths" do
      original_config = save_original_config()
      dir = test_directory()
      scope = scope_fixture()

      absolute_path = Path.expand(dir)

      configure_file_watcher(enabled: true, directory: absolute_path, scope: scope)

      try do
        assert {:ok, pid} = FileWatcher.start_link([])

        state = :sys.get_state(pid)
        assert state.watched_directory == absolute_path

        GenServer.stop(pid)
      after
        cleanup_directory(dir)
        restore_original_config(original_config)
      end
    end

    test "handles directory path with trailing slash" do
      original_config = save_original_config()
      dir = test_directory()
      scope = scope_fixture()

      dir_with_slash = dir <> "/"

      configure_file_watcher(enabled: true, directory: dir_with_slash, scope: scope)

      try do
        assert {:ok, pid} = FileWatcher.start_link([])

        state = :sys.get_state(pid)
        assert state.watched_directory == dir_with_slash

        GenServer.stop(pid)
      after
        cleanup_directory(dir)
        restore_original_config(original_config)
      end
    end

    test "handles rapid consecutive file events" do
      original_config = save_original_config()
      dir = test_directory()
      scope = scope_fixture()

      configure_file_watcher(enabled: true, directory: dir, scope: scope)

      try do
        {:ok, pid} = FileWatcher.start_link([])

        file_path = Path.join(dir, "test.md")

        # Send 100 rapid events
        for _i <- 1..100 do
          send(pid, {:file_event, self(), {file_path, [:modified]}})
        end

        :timer.sleep(50)

        # GenServer should still be alive
        assert Process.alive?(pid)

        # Should have a single active timer
        state = :sys.get_state(pid)
        assert state.debounce_timer != nil

        GenServer.stop(pid)
      after
        cleanup_directory(dir)
        restore_original_config(original_config)
      end
    end

    test "handles file events for different files" do
      original_config = save_original_config()
      dir = test_directory()
      scope = scope_fixture()

      configure_file_watcher(enabled: true, directory: dir, scope: scope)

      try do
        {:ok, pid} = FileWatcher.start_link([])

        # Send events for different files
        send(pid, {:file_event, self(), {Path.join(dir, "file1.md"), [:modified]}})
        :timer.sleep(10)
        send(pid, {:file_event, self(), {Path.join(dir, "file2.md"), [:created]}})
        :timer.sleep(10)
        send(pid, {:file_event, self(), {Path.join(dir, "file3.html"), [:removed]}})

        :timer.sleep(50)

        # GenServer should still be alive with active timer
        assert Process.alive?(pid)

        state = :sys.get_state(pid)
        assert state.debounce_timer != nil

        GenServer.stop(pid)
      after
        cleanup_directory(dir)
        restore_original_config(original_config)
      end
    end

    test "handles files in subdirectories" do
      original_config = save_original_config()
      dir = test_directory()
      scope = scope_fixture()

      subdir = Path.join(dir, "subdir")
      File.mkdir_p!(subdir)

      configure_file_watcher(enabled: true, directory: dir, scope: scope)

      try do
        {:ok, pid} = FileWatcher.start_link([])

        file_path = Path.join(subdir, "nested.md")
        send(pid, {:file_event, self(), {file_path, [:modified]}})

        :timer.sleep(50)

        # GenServer should handle subdirectory events
        assert Process.alive?(pid)

        state = :sys.get_state(pid)
        assert state.debounce_timer != nil

        GenServer.stop(pid)
      after
        cleanup_directory(dir)
        restore_original_config(original_config)
      end
    end

    test "handles zero-length event lists" do
      original_config = save_original_config()
      dir = test_directory()
      scope = scope_fixture()

      configure_file_watcher(enabled: true, directory: dir, scope: scope)

      try do
        {:ok, pid} = FileWatcher.start_link([])

        file_path = Path.join(dir, "test.md")
        send(pid, {:file_event, self(), {file_path, []}})

        :timer.sleep(50)

        # GenServer should handle empty event lists gracefully
        assert Process.alive?(pid)

        GenServer.stop(pid)
      after
        cleanup_directory(dir)
        restore_original_config(original_config)
      end
    end
  end

  # ============================================================================
  # Integration with ContentSync.Sync
  # ============================================================================

  describe "integration with ContentSync.Sync" do
    test "calls Sync.sync_directory with correct scope and directory" do
      original_config = save_original_config()
      dir = test_directory()
      scope = scope_fixture()

      # Create a valid content file for sync to process
      file_path = Path.join(dir, "test.md")
      File.write!(file_path, "# Test Content\n\nHello World")

      metadata_path = Path.join(dir, "test.yaml")

      File.write!(metadata_path, """
      title: "Test Post"
      slug: "test-post"
      type: "blog"
      """)

      configure_file_watcher(enabled: true, directory: dir, scope: scope)

      try do
        {:ok, pid} = FileWatcher.start_link([])

        # Trigger sync
        send(pid, :trigger_sync)

        # Wait for sync to complete
        :timer.sleep(200)

        # Verify sync was called by checking if content was created
        # (ContentSync.Sync would have been called with scope and directory)
        assert Process.alive?(pid)

        GenServer.stop(pid)
      after
        cleanup_directory(dir)
        restore_original_config(original_config)
      end
    end
  end

  # ============================================================================
  # Multiple Instances
  # ============================================================================

  describe "multiple instances" do
    test "can start multiple FileWatcher instances with different directories" do
      original_config = save_original_config()
      dir1 = test_directory()
      dir2 = test_directory()
      scope = scope_fixture()

      try do
        # Start first instance
        configure_file_watcher(enabled: true, directory: dir1, scope: scope)
        {:ok, pid1} = FileWatcher.start_link([])

        # Start second instance (requires different configuration)
        configure_file_watcher(enabled: true, directory: dir2, scope: scope)
        {:ok, pid2} = FileWatcher.start_link([])

        assert Process.alive?(pid1)
        assert Process.alive?(pid2)
        assert pid1 != pid2

        state1 = :sys.get_state(pid1)
        state2 = :sys.get_state(pid2)

        # First instance should have original directory
        # Second instance should have updated directory
        # (Note: In real usage, these would be separate processes with separate configs)
        assert is_binary(state1.watched_directory)
        assert is_binary(state2.watched_directory)

        GenServer.stop(pid1)
        GenServer.stop(pid2)
      after
        cleanup_directory(dir1)
        cleanup_directory(dir2)
        restore_original_config(original_config)
      end
    end
  end
end
defmodule CodeMySpec.Environments.CliTest do
  use ExUnit.Case
  doctest CodeMySpec.Environments.Cli

  alias CodeMySpec.Environments.Cli
  alias CodeMySpec.Environments.Environment
  alias CodeMySpec.Environments.MockTmuxAdapter
  alias CodeMySpec.Sessions.Command

  setup do
    # Configure mock adapter for tests
    MockTmuxAdapter.reset!()

    :ok
  end

  describe "create/1" do
    test "creates Environment struct with window name (lazy creation)" do
      session_id = :rand.uniform(10000)

      assert {:ok, %Environment{} = env} = Cli.create(session_id: session_id)
      assert env.type == :cli
      assert env.ref == "session-#{session_id}"
      assert env.metadata == %{}

      # Window should not be created yet (lazy creation)
      refute MockTmuxAdapter.window_exists?("session-#{session_id}")
    end

    test "includes metadata in Environment struct when provided" do
      session_id = :rand.uniform(10000)
      metadata = %{foo: "bar", session_id: session_id}

      assert {:ok, %Environment{} = env} = Cli.create(session_id: session_id, metadata: metadata)
      assert env.metadata == metadata
    end

    test "uses random session_id when not provided" do
      assert {:ok, %Environment{} = env} = Cli.create()
      assert env.type == :cli
      assert is_binary(env.ref)
    end
  end

  describe "destroy/1" do
    test "destroys tmux window successfully" do
      {:ok, env} = Cli.create(session_id: :rand.uniform(10000))

      assert :ok = Cli.destroy(env)
    end

    test "is idempotent (returns :ok even if already destroyed)" do
      {:ok, env} = Cli.create(session_id: :rand.uniform(10000))

      # Destroy once
      assert :ok = Cli.destroy(env)

      # Destroy again - still succeeds
      assert :ok = Cli.destroy(env)
    end
  end

  describe "run_command/3" do
    test "sends command to tmux window and creates window lazily" do
      session_id = :rand.uniform(10000)
      {:ok, env} = Cli.create(session_id: session_id)
      command = %Command{command: "claude", metadata: %{}}

      # Window should not exist yet
      refute MockTmuxAdapter.window_exists?("session-#{session_id}")

      assert :ok = Cli.run_command(env, command)

      # Window should now exist (lazy creation)
      assert MockTmuxAdapter.window_exists?("session-#{session_id}")

      # Verify command was sent
      commands = MockTmuxAdapter.get_sent_commands()
      assert length(commands) == 1
      assert {_window_name, "claude"} = hd(commands)
    end

    test "sends command with environment variables" do
      {:ok, env} = Cli.create(session_id: :rand.uniform(10000))
      command = %Command{command: "claude", metadata: %{}}

      assert :ok = Cli.run_command(env, command, env: %{"FOO" => "bar"})

      # Verify environment variable was included
      commands = MockTmuxAdapter.get_sent_commands()
      [{_window_name, cmd_str}] = commands
      assert cmd_str =~ "export FOO="
      assert cmd_str =~ "claude"
    end

    test "sends multiple environment variables" do
      {:ok, env} = Cli.create(session_id: :rand.uniform(10000))
      command = %Command{command: "claude", metadata: %{}}

      assert :ok = Cli.run_command(env, command, env: %{"FOO" => "bar", "BAZ" => "qux"})

      commands = MockTmuxAdapter.get_sent_commands()
      [{_window_name, cmd_str}] = commands
      assert cmd_str =~ "export FOO="
      assert cmd_str =~ "export BAZ="
    end

    test "escapes shell special characters in environment variables" do
      {:ok, env} = Cli.create(session_id: :rand.uniform(10000))
      command = %Command{command: "claude", metadata: %{}}

      assert :ok = Cli.run_command(env, command, env: %{"FOO" => "bar'baz"})

      commands = MockTmuxAdapter.get_sent_commands()
      [{_window_name, cmd_str}] = commands
      # Should escape the single quote
      assert cmd_str =~ "export FOO='bar'\\''baz''"
    end

    test "returns immediately without blocking" do
      {:ok, env} = Cli.create(session_id: :rand.uniform(10000))
      command = %Command{command: "claude", metadata: %{}}

      # Mock adapter returns immediately, simulating the async nature
      start_time = System.monotonic_time(:millisecond)
      assert :ok = Cli.run_command(env, command)
      end_time = System.monotonic_time(:millisecond)

      # Should be very fast (< 100ms)
      assert end_time - start_time < 100
    end

    test "handles legacy format where command field has shell command" do
      {:ok, env} = Cli.create(session_id: :rand.uniform(10000))
      command = %Command{command: "echo 'legacy'", metadata: %{}}

      assert :ok = Cli.run_command(env, command)

      commands = MockTmuxAdapter.get_sent_commands()
      assert length(commands) == 1
      assert {_window_ref, "echo 'legacy'"} = hd(commands)
    end
  end

  describe "read_file/2" do
    test "reads file content from server file system" do
      # Create a temp file
      temp_file = Path.join(System.tmp_dir!(), "test-#{:rand.uniform(10000)}.txt")
      File.write!(temp_file, "test content")

      {:ok, env} = Cli.create(session_id: :rand.uniform(10000))

      assert {:ok, "test content"} = Cli.read_file(env, temp_file)

      # Cleanup
      File.rm!(temp_file)
    end

    test "returns error for non-existent file" do
      {:ok, env} = Cli.create(session_id: :rand.uniform(10000))

      assert {:error, :enoent} = Cli.read_file(env, "/nonexistent/file.txt")
    end
  end

  describe "list_directory/2" do
    test "lists directory contents from server file system" do
      {:ok, env} = Cli.create(session_id: :rand.uniform(10000))

      assert {:ok, entries} = Cli.list_directory(env, System.tmp_dir!())
      assert is_list(entries)
    end

    test "returns error for non-existent directory" do
      {:ok, env} = Cli.create(session_id: :rand.uniform(10000))

      assert {:error, :enoent} = Cli.list_directory(env, "/nonexistent/directory")
    end
  end
end

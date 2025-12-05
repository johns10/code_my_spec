defmodule CodeMySpec.Environments.CliTest do
  use ExUnit.Case
  doctest CodeMySpec.Environments.Cli

  alias CodeMySpec.Environments.Cli
  alias CodeMySpec.Environments.Environment
  alias CodeMySpec.Environments.MockTmuxAdapter

  setup do
    # Configure mock adapter for tests
    Application.put_env(:code_my_spec, :tmux_adapter, MockTmuxAdapter)
    MockTmuxAdapter.reset!()

    on_exit(fn ->
      # Restore real adapter after test
      Application.delete_env(:code_my_spec, :tmux_adapter)
    end)

    :ok
  end

  describe "create/1" do
    test "creates Environment struct with tmux window reference" do
      session_id = :rand.uniform(10000)

      assert {:ok, %Environment{} = env} = Cli.create(session_id: session_id)
      assert env.type == :cli
      assert env.ref == "@mock-claude-#{session_id}"
      assert env.metadata == %{}
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

    test "returns error when not inside tmux" do
      Process.put(:mock_inside_tmux, false)

      assert {:error, "Not running inside tmux"} = Cli.create(session_id: 123)
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
    test "sends command to tmux window" do
      {:ok, env} = Cli.create(session_id: :rand.uniform(10000))

      assert :ok = Cli.run_command(env, "echo 'test'")

      # Verify command was sent
      commands = MockTmuxAdapter.get_sent_commands()
      assert length(commands) == 1
      assert {_window_ref, "echo 'test'"} = hd(commands)
    end

    test "sends command with environment variables" do
      {:ok, env} = Cli.create(session_id: :rand.uniform(10000))

      assert :ok = Cli.run_command(env, "echo $FOO", env: %{"FOO" => "bar"})

      # Verify environment variable was included
      commands = MockTmuxAdapter.get_sent_commands()
      [{_window_ref, command}] = commands
      assert command =~ "export FOO="
      assert command =~ "echo $FOO"
    end

    test "sends multiple environment variables" do
      {:ok, env} = Cli.create(session_id: :rand.uniform(10000))

      assert :ok =
               Cli.run_command(env, "echo test", env: %{"FOO" => "bar", "BAZ" => "qux"})

      commands = MockTmuxAdapter.get_sent_commands()
      [{_window_ref, command}] = commands
      assert command =~ "export FOO="
      assert command =~ "export BAZ="
    end

    test "escapes shell special characters in environment variables" do
      {:ok, env} = Cli.create(session_id: :rand.uniform(10000))

      assert :ok = Cli.run_command(env, "echo test", env: %{"FOO" => "bar'baz"})

      commands = MockTmuxAdapter.get_sent_commands()
      [{_window_ref, command}] = commands
      # Should escape the single quote
      assert command =~ "export FOO='bar'\\''baz''"
    end

    test "returns immediately without blocking" do
      {:ok, env} = Cli.create(session_id: :rand.uniform(10000))

      # Mock adapter returns immediately, simulating the async nature
      start_time = System.monotonic_time(:millisecond)
      assert :ok = Cli.run_command(env, "sleep 100")
      end_time = System.monotonic_time(:millisecond)

      # Should be very fast (< 100ms)
      assert end_time - start_time < 100
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

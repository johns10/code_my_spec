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
      command = %Command{command: "claude", metadata: %{"prompt" => "test", "args" => []}}

      # Window should not exist yet
      refute MockTmuxAdapter.window_exists?("session-#{session_id}")

      assert :ok =
               Cli.run_command(env, command,
                 session_id: session_id,
                 interaction_id: Ecto.UUID.generate()
               )

      # Window should now exist (lazy creation)
      assert MockTmuxAdapter.window_exists?("session-#{session_id}")

      # Verify command was sent with read @ syntax
      commands = MockTmuxAdapter.get_sent_commands()
      assert length(commands) == 1
      {_window_name, cmd_str} = hd(commands)
      assert cmd_str =~ ~r/claude\s+"read @.+"/
    end

    test "sets CODE_MY_SPEC environment variables automatically" do
      session_id = :rand.uniform(10000)
      {:ok, env} = Cli.create(session_id: session_id)
      command = %Command{command: "claude", metadata: %{"prompt" => "test", "args" => []}}

      assert :ok =
               Cli.run_command(env, command,
                 session_id: session_id,
                 interaction_id: Ecto.UUID.generate()
               )

      # Verify CODE_MY_SPEC environment variables were included
      commands = MockTmuxAdapter.get_sent_commands()
      [{_window_name, cmd_str}] = commands
      assert cmd_str =~ "export CODE_MY_SPEC_HOOK_URL="
      assert cmd_str =~ "export CODE_MY_SPEC_SESSION_ID="
      assert cmd_str =~ "export CODE_MY_SPEC_INTERACTION_ID="
      assert cmd_str =~ "http://localhost:8314"
      assert cmd_str =~ to_string(session_id)
    end

    test "sets correct session_id in environment" do
      session_id = 12345
      {:ok, env} = Cli.create(session_id: session_id)
      command = %Command{command: "claude", metadata: %{"prompt" => "test", "args" => []}}

      assert :ok =
               Cli.run_command(env, command,
                 session_id: session_id,
                 interaction_id: Ecto.UUID.generate()
               )

      commands = MockTmuxAdapter.get_sent_commands()
      [{_window_name, cmd_str}] = commands
      assert cmd_str =~ "CODE_MY_SPEC_SESSION_ID='12345'"
    end

    test "fails when session_id is missing in opts" do
      {:ok, env} = Cli.create(session_id: :rand.uniform(10000))
      command = %Command{command: "claude", metadata: %{"prompt" => "test", "args" => []}}

      assert {:error, :missing_session_id} = Cli.run_command(env, command)

      # No commands should have been sent
      commands = MockTmuxAdapter.get_sent_commands()
      assert commands == []
    end

    test "returns immediately without blocking" do
      session_id = :rand.uniform(10000)
      {:ok, env} = Cli.create(session_id: session_id)
      command = %Command{command: "claude", metadata: %{"prompt" => "", "args" => []}}

      # Mock adapter returns immediately, simulating the async nature
      start_time = System.monotonic_time(:millisecond)

      assert :ok =
               Cli.run_command(env, command,
                 session_id: session_id,
                 interaction_id: Ecto.UUID.generate()
               )

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

  describe "run_command/3 - claude command with prompt and piping" do
    test "creates temp file and pipes prompt into claude command" do
      session_id = :rand.uniform(10000)
      {:ok, env} = Cli.create(session_id: session_id)
      prompt = "Write a hello world function"
      command = %Command{command: "claude", metadata: %{"prompt" => prompt, "args" => []}}

      assert :ok =
               Cli.run_command(env, command,
                 session_id: session_id,
                 interaction_id: Ecto.UUID.generate()
               )

      commands = MockTmuxAdapter.get_sent_commands()
      assert length(commands) == 1
      {_window_name, cmd_str} = hd(commands)

      # Should contain read @ syntax
      assert cmd_str =~ ~r/claude\s+"read @.+"/
    end

    test "escapes args containing special characters" do
      session_id = :rand.uniform(10000)
      {:ok, env} = Cli.create(session_id: session_id)
      prompt = "Test prompt"
      args = ["--prompt", "Hello 'world'"]
      command = %Command{command: "claude", metadata: %{"prompt" => prompt, "args" => args}}

      assert :ok =
               Cli.run_command(env, command,
                 session_id: session_id,
                 interaction_id: Ecto.UUID.generate()
               )

      commands = MockTmuxAdapter.get_sent_commands()
      [{_window_name, cmd_str}] = commands

      # Should include args before read @ syntax
      assert cmd_str =~ ~r/claude\s+.+"read @.+"/
    end

    test "works with empty args list" do
      session_id = :rand.uniform(10000)
      {:ok, env} = Cli.create(session_id: session_id)
      prompt = "Simple prompt"
      command = %Command{command: "claude", metadata: %{"prompt" => prompt, "args" => []}}

      assert :ok =
               Cli.run_command(env, command,
                 session_id: session_id,
                 interaction_id: Ecto.UUID.generate()
               )

      commands = MockTmuxAdapter.get_sent_commands()
      [{_window_name, cmd_str}] = commands

      # Should just have claude with read @ syntax without extra args
      assert cmd_str =~ ~r/claude\s+"read @.+"/
    end

    test "works with empty prompt" do
      session_id = :rand.uniform(10000)
      {:ok, env} = Cli.create(session_id: session_id)
      command = %Command{command: "claude", metadata: %{"prompt" => "", "args" => []}}

      assert :ok =
               Cli.run_command(env, command,
                 session_id: session_id,
                 interaction_id: Ecto.UUID.generate()
               )

      commands = MockTmuxAdapter.get_sent_commands()
      assert length(commands) == 1
    end

    test "handles missing prompt in metadata" do
      session_id = :rand.uniform(10000)
      {:ok, env} = Cli.create(session_id: session_id)
      command = %Command{command: "claude", metadata: %{"args" => []}}

      assert :ok =
               Cli.run_command(env, command,
                 session_id: session_id,
                 interaction_id: Ecto.UUID.generate()
               )

      commands = MockTmuxAdapter.get_sent_commands()
      [{_window_name, cmd_str}] = commands

      # Should still generate command with empty prompt
      assert cmd_str =~ ~r/claude\s+"read @.+"/
    end

    test "handles missing args in metadata" do
      session_id = :rand.uniform(10000)
      {:ok, env} = Cli.create(session_id: session_id)
      prompt = "Test prompt"
      command = %Command{command: "claude", metadata: %{"prompt" => prompt}}

      assert :ok =
               Cli.run_command(env, command,
                 session_id: session_id,
                 interaction_id: Ecto.UUID.generate()
               )

      commands = MockTmuxAdapter.get_sent_commands()
      [{_window_name, cmd_str}] = commands

      # Should default to empty args
      assert cmd_str =~ ~r/claude\s+"read @.+"/
    end

    test "handles multiline prompts" do
      session_id = :rand.uniform(10000)
      {:ok, env} = Cli.create(session_id: session_id)

      prompt = """
      Write a function that:
      1. Takes a list
      2. Returns the sum
      """

      command = %Command{command: "claude", metadata: %{"prompt" => prompt, "args" => []}}

      assert :ok =
               Cli.run_command(env, command,
                 session_id: session_id,
                 interaction_id: Ecto.UUID.generate()
               )

      commands = MockTmuxAdapter.get_sent_commands()
      assert length(commands) == 1
      {_window_name, cmd_str} = hd(commands)

      # Should use read @ syntax correctly
      assert cmd_str =~ ~r/claude\s+"read @.+"/
    end

    test "handles long prompts" do
      session_id = :rand.uniform(10000)
      {:ok, env} = Cli.create(session_id: session_id)
      # Create a long prompt (10KB)
      prompt = String.duplicate("This is a test prompt. ", 500)
      command = %Command{command: "claude", metadata: %{"prompt" => prompt, "args" => []}}

      assert :ok =
               Cli.run_command(env, command,
                 session_id: session_id,
                 interaction_id: Ecto.UUID.generate()
               )

      commands = MockTmuxAdapter.get_sent_commands()
      assert length(commands) == 1
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

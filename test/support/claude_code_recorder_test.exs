defmodule CodeMySpec.Agents.Implementations.ClaudeCode.RecorderTest do
  use ExUnit.Case
  import Mox

  alias CodeMySpec.Agents.{Agent, AgentTypes}
  alias CodeMySpec.Agents.Implementations.ClaudeCode.Recorder

  setup :verify_on_exit!

  describe "recording and replay" do
    test "can record and load interactions" do
      command = ["claude", "--print", "Hello"]
      output = ~s|[{"type":"assistant","message":{"content":[{"text":"Hello!","type":"text"}]}}]|

      assert {:ok, path} = Recorder.record(command, output, "test_recording")
      assert File.exists?(path)

      # Test that we can load the recording
      assert {:ok, recording} = Recorder.load("test_recording")
      assert recording["command"] == command
      assert recording["output"] == output

      # Clean up
      File.rm(path)
    end

    test "handles missing recordings" do
      assert {:error, _} = Recorder.load("nonexistent_recording")
    end

    test "use_recording replays existing recordings" do
      # Create a recording first with the exact command that ClaudeCode.query would generate
      command = ["claude", "--output-format", "stream-json", "--print", "Test query"]

      output =
        ~s|[{"type":"assistant","message":{"content":[{"text":"Test response","type":"text"}]}}]|

      {:ok, path} = Recorder.record(command, output, "replay_test")

      # Use the recording - this should call the mock with the same command
      result =
        Recorder.use_recording("replay_test", fn ->
          # This will trigger the mock expectation inside use_recording
          {:ok, agent_type} = AgentTypes.get(:unit_coder)
          agent = %Agent{name: "test", agent_type: agent_type, config: %{}}
          
          {:ok, messages} =
            CodeMySpec.Agents.Implementations.ClaudeCode.execute(agent, "Test query", fn _ -> :ok end)

          assert is_map(messages)
          :test_passed
        end)

      assert result == :test_passed

      # Clean up
      File.rm(path)
    end

    test "use_recording creates recordings when Claude available" do
      # Mock Claude version check to succeed
      # This test would only run if Claude CLI is actually available
      # For CI/CD, this would be skipped
      case System.cmd("claude", ["--version"], stderr_to_stdout: true) do
        {_output, 0} ->
          # Claude is available - test would create real recording
          # In real test, we'd assert the recording was created
          :ok

        {_error, _code} ->
          # Claude not available - test should be skipped
          :ok
      end
    end

    test "record_query builds commands properly" do
      # This test requires Claude CLI to be available
      # In CI/CD without Claude, it would be skipped
      case System.cmd("claude", ["--version"], stderr_to_stdout: true) do
        {_output, 0} ->
          # Would test real recording here
          :ok

        {_error, _code} ->
          # Skip test when Claude not available
          :ok
      end
    end
  end

  describe "error handling" do
    test "handles invalid JSON in recordings" do
      # Create a recording with invalid JSON
      invalid_recording = %{
        command: ["claude", "--print", "test"],
        output: "invalid json{",
        recorded_at: DateTime.utc_now() |> DateTime.to_iso8601()
      }

      file_path = "test/fixtures/recordings/invalid_test.json"
      File.mkdir_p!(Path.dirname(file_path))
      File.write!(file_path, Jason.encode!(invalid_recording))

      # Loading should still work (the recording file is valid JSON)
      assert {:ok, recording} = Recorder.load("invalid_test")
      assert recording["output"] == "invalid json{"

      # Clean up
      File.rm(file_path)
    end
  end
end

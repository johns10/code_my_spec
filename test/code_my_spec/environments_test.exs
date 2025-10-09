defmodule CodeMySpec.EnvironmentsTest do
  use ExUnit.Case
  import CodeMySpec.Support.CLIRecorder

  test "cmd with CLI recorder using cassette" do
    use_cassette "test_multiple_commands" do
      # First command executes and records
      assert {output1, 0} = CodeMySpec.Environments.cmd(:local, "echo", ["hello world"], [])
      assert String.trim(output1) == "hello world"

      # Second different command executes and records
      assert {output2, 0} = CodeMySpec.Environments.cmd(:local, "echo", ["goodbye world"], [])
      assert String.trim(output2) == "goodbye world"

      # Third command executes and records
      assert {output3, 0} = CodeMySpec.Environments.cmd(:local, "pwd", [], [])
      assert String.contains?(output3, "/")

      # Replay all commands from the same fixture
      assert {replay1, 0} = CodeMySpec.Environments.cmd(:local, "echo", ["hello world"], [])
      assert String.trim(replay1) == "hello world"

      assert {replay2, 0} = CodeMySpec.Environments.cmd(:local, "echo", ["goodbye world"], [])
      assert String.trim(replay2) == "goodbye world"

      assert {replay3, 0} = CodeMySpec.Environments.cmd(:local, "pwd", [], [])
      assert String.contains?(replay3, "/")
    end
  end
end

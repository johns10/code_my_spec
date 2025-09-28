defmodule CodeMySpec.EnvironmentsTest do
  use ExUnit.Case
  import Mox
  import CodeMySpec.Support.CLIRecorder

  setup do
    # Configure application to use mock for local environment
    Application.put_env(:code_my_spec, :local_environment, CodeMySpec.MockEnvironment)

    # Use stub environment that automatically records
    stub_with(CodeMySpec.MockEnvironment, CodeMySpec.Support.RecordingEnvironment)
    :ok
  end

  test "cmd with CLI recorder using cassette" do
    use_cassette "test_multiple_commands" do
      # First command executes and records
      assert {:ok, output1} = CodeMySpec.Environments.cmd(:local, "echo", ["hello world"], [])
      assert String.trim(output1) == "hello world"

      # Second different command executes and records
      assert {:ok, output2} = CodeMySpec.Environments.cmd(:local, "echo", ["goodbye world"], [])
      assert String.trim(output2) == "goodbye world"

      # Third command executes and records
      assert {:ok, output3} = CodeMySpec.Environments.cmd(:local, "pwd", [], [])
      assert String.contains?(output3, "/")

      # Replay all commands from the same fixture
      assert {:ok, replay1} = CodeMySpec.Environments.cmd(:local, "echo", ["hello world"], [])
      assert String.trim(replay1) == "hello world"

      assert {:ok, replay2} = CodeMySpec.Environments.cmd(:local, "echo", ["goodbye world"], [])
      assert String.trim(replay2) == "goodbye world"

      assert {:ok, replay3} = CodeMySpec.Environments.cmd(:local, "pwd", [], [])
      assert String.contains?(replay3, "/")
    end
  end
end

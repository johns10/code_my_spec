defmodule CodeMySpec.Tests.ProcessExecutorTest do
  use ExUnit.Case
  doctest CodeMySpec.Tests.ProcessExecutor
  alias CodeMySpec.Tests.ProcessExecutor

  @temp_dir System.tmp_dir!()

  describe "execute/3" do
    test "returns success result for successful command" do
      {:ok, result} = ProcessExecutor.execute("echo 'hello world'", @temp_dir)

      assert result.execution_status == :success
      assert result.exit_code == 0
      assert String.contains?(result.output, "hello world")
      assert %NaiveDateTime{} = result.executed_at
    end

    test "returns failure result for failed command" do
      {:ok, result} = ProcessExecutor.execute("exit 1", @temp_dir)

      assert result.execution_status == :failure
      assert result.exit_code == 1
      assert is_binary(result.output)
      assert %NaiveDateTime{} = result.executed_at
    end

    test "captures command output" do
      {:ok, result} = ProcessExecutor.execute("echo 'test output'", @temp_dir)

      assert String.contains?(result.output, "test output")
    end

    test "captures error output when stderr_to_stdout is true" do
      {:ok, result} =
        ProcessExecutor.execute("echo 'error' >&2; exit 1", @temp_dir, stderr_to_stdout: true)

      assert result.execution_status == :failure
      assert result.exit_code == 1
      assert String.contains?(result.output, "error")
    end

    test "handles timeout with short timeout" do
      {:error, result} = ProcessExecutor.execute("sleep 2", @temp_dir, timeout: 100)

      assert result.execution_status == :timeout
      assert result.exit_code == nil
      assert result.output == ""
      assert %NaiveDateTime{} = result.executed_at
    end

    test "uses provided working directory" do
      {:ok, result} = ProcessExecutor.execute("pwd", @temp_dir)

      assert result.execution_status == :success
      # Handle macOS symlinks by comparing actual file stats
      output_dir = String.trim(result.output)
      {:ok, temp_stat} = File.stat(@temp_dir)
      {:ok, output_stat} = File.stat(output_dir)
      assert temp_stat.inode == output_stat.inode
    end

    test "uses environment variables when provided" do
      {:ok, result} =
        ProcessExecutor.execute("echo $TEST_VAR", @temp_dir, env: %{"TEST_VAR" => "test_value"})

      assert result.execution_status == :success
      assert String.contains?(result.output, "test_value")
    end

    test "uses default timeout when not specified" do
      {:ok, result} = ProcessExecutor.execute("echo 'quick'", @temp_dir)

      assert result.execution_status == :success
    end
  end

  describe "execute_async/3" do
    test "returns a Task that can be awaited" do
      task = ProcessExecutor.execute_async("echo 'async test'", @temp_dir)

      assert %Task{} = task
      {:ok, result} = Task.await(task)

      assert result.execution_status == :success
      assert String.contains?(result.output, "async test")
    end

    test "allows multiple concurrent executions" do
      task1 = ProcessExecutor.execute_async("echo 'task1'", @temp_dir)
      task2 = ProcessExecutor.execute_async("echo 'task2'", @temp_dir)

      results = Task.await_many([task1, task2], 5000)

      assert [{:ok, result1}, {:ok, result2}] = results
      assert result1.execution_status == :success
      assert result2.execution_status == :success
    end
  end

  describe "await_execution/2" do
    test "awaits task completion with custom timeout" do
      task = ProcessExecutor.execute_async("echo 'await test'", @temp_dir)

      {:ok, result} = ProcessExecutor.await_execution(task, 5000)

      assert result.execution_status == :success
      assert String.contains?(result.output, "await test")
    end

    test "uses default timeout when not specified" do
      task = ProcessExecutor.execute_async("echo 'default timeout'", @temp_dir)

      {:ok, result} = ProcessExecutor.await_execution(task)

      assert result.execution_status == :success
    end
  end

  describe "result structure" do
    test "always includes required fields" do
      {:ok, result} = ProcessExecutor.execute("echo 'test'", @temp_dir)

      assert Map.has_key?(result, :output)
      assert Map.has_key?(result, :exit_code)
      assert Map.has_key?(result, :execution_status)
      assert Map.has_key?(result, :executed_at)

      assert is_binary(result.output)
      assert is_integer(result.exit_code)
      assert result.execution_status in [:success, :failure, :timeout]
      assert %NaiveDateTime{} = result.executed_at
    end

    test "timeout results have nil exit_code" do
      {:error, result} = ProcessExecutor.execute("sleep 1", @temp_dir, timeout: 10)

      assert result.exit_code == nil
      assert result.execution_status == :timeout
    end
  end
end

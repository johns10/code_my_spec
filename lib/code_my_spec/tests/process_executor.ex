defmodule CodeMySpec.Tests.ProcessExecutor do
  @moduledoc """
  Executes external system commands with timeout handling and comprehensive result capture.
  Designed as a functional core with explicit side effect boundaries.
  """

  @type execution_result :: %{
          output: String.t(),
          exit_code: non_neg_integer() | nil,
          execution_status: :success | :failure | :timeout,
          executed_at: NaiveDateTime.t()
        }

  @type execute_opts :: [
          timeout: pos_integer(),
          env: %{String.t() => String.t()},
          stderr_to_stdout: boolean()
        ]

  @spec execute(String.t(), String.t(), execute_opts()) ::
          {:ok, execution_result()} | {:error, execution_result()}
  def execute(command, working_dir, opts \\ []) do
    executed_at = NaiveDateTime.utc_now()
    timeout = Keyword.get(opts, :timeout, 30_000)
    env = Keyword.get(opts, :env, %{})
    stderr_to_stdout = Keyword.get(opts, :stderr_to_stdout, true)

    port_opts = [:stream, :binary, :exit_status, {:cd, working_dir}]
    port_opts = if stderr_to_stdout, do: [:stderr_to_stdout | port_opts], else: port_opts
    
    # Convert env map to list of tuples for Port
    port_opts = if map_size(env) > 0 do
      env_list = Enum.map(env, fn {k, v} -> {String.to_charlist(k), String.to_charlist(v)} end)
      [{:env, env_list} | port_opts]
    else
      port_opts
    end

    port = Port.open({:spawn, "sh -c '#{escape_command(command)}'"}, port_opts)

    receive_output(port, "", executed_at, timeout)
  end

  @spec execute_async(String.t(), String.t(), execute_opts()) :: Task.t()
  def execute_async(command, working_dir, opts \\ []) do
    Task.async(fn ->
      execute(command, working_dir, opts)
    end)
  end

  @spec await_execution(Task.t(), pos_integer()) ::
          {:ok, execution_result()} | {:error, execution_result()}
  def await_execution(task, timeout \\ 60_000) do
    Task.await(task, timeout)
  end

  defp receive_output(port, output, executed_at, timeout) do
    receive do
      {^port, {:data, data}} ->
        receive_output(port, output <> data, executed_at, timeout)

      {^port, {:exit_status, 0}} ->
        {:ok, build_success_result(output, 0, executed_at)}

      {^port, {:exit_status, exit_code}} ->
        {:ok, build_failure_result(output, exit_code, executed_at)}
    after
      timeout ->
        Port.close(port)
        {:error, build_timeout_result(executed_at)}
    end
  end

  defp escape_command(command) do
    String.replace(command, "'", "'\"'\"'")
  end

  defp build_success_result(output, exit_code, executed_at) do
    %{
      output: output,
      exit_code: exit_code,
      execution_status: :success,
      executed_at: executed_at
    }
  end

  defp build_failure_result(output, exit_code, executed_at) do
    %{
      output: output,
      exit_code: exit_code,
      execution_status: :failure,
      executed_at: executed_at
    }
  end

  defp build_timeout_result(executed_at) do
    %{
      output: "",
      exit_code: nil,
      execution_status: :timeout,
      executed_at: executed_at
    }
  end
end

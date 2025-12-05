defmodule CodeMySpec.Environments do
  @moduledoc """
  Provides execution primitives for running commands and file system operations
  across different execution contexts (server, CLI with tmux, VS Code client).

  This module delegates to specific environment implementations while maintaining
  a consistent interface through the opaque Environment struct.
  """

  alias CodeMySpec.Environments.Environment

  @doc """
  Create a new execution context and return an opaque Environment struct.

  ## Parameters

  - `type` - Environment type (`:cli`, `:server`, `:vscode`)
  - `opts` - Options passed to the implementation's `create/1` function

  ## Returns

  - `{:ok, %Environment{}}` - Environment created successfully
  - `{:error, reason}` - Failed to create environment

  ## Examples

      # Create CLI environment with tmux
      {:ok, env} = Environments.create(:cli, session_id: 123)

      # Create server environment
      {:ok, env} = Environments.create(:server)
  """
  @spec create(type :: atom(), opts :: keyword()) ::
          {:ok, Environment.t()} | {:error, term()}
  def create(type, opts \\ []) do
    with {:ok, impl_module} <- get_impl(type) do
      impl_module.create(opts)
    end
  end

  @doc """
  Destroy an execution context and clean up resources.

  This function is idempotent - it should succeed even if the context
  has already been destroyed.
  """
  @spec destroy(env :: Environment.t()) :: :ok | {:error, term()}
  def destroy(%Environment{type: type} = env) do
    with {:ok, impl_module} <- get_impl(type) do
      impl_module.destroy(env)
    end
  end

  @doc """
  Execute a command in the environment context.

  ## Options

  - `:async` - Run command asynchronously (default: false)
  - `:env` - Map of environment variables to set

  ## Returns

  The return value depends on the environment implementation:
  - CLI: `:ok | {:error, term()}` (no output capture)
  - Server: `{:ok, result :: map()} | {:error, term()}` (with output)
  """
  @spec run_command(env :: Environment.t(), command :: String.t(), opts :: keyword()) ::
          :ok | {:ok, map()} | {:error, term()}
  def run_command(%Environment{type: type} = env, command, opts \\ []) do
    with {:ok, impl_module} <- get_impl(type) do
      impl_module.run_command(env, command, opts)
    end
  end

  @doc """
  Read a file from the execution environment's file system.
  """
  @spec read_file(env :: Environment.t(), path :: String.t()) ::
          {:ok, String.t()} | {:error, term()}
  def read_file(%Environment{type: type} = env, path) do
    with {:ok, impl_module} <- get_impl(type) do
      impl_module.read_file(env, path)
    end
  end

  @doc """
  List contents of a directory in the execution environment.
  """
  @spec list_directory(env :: Environment.t(), path :: String.t()) ::
          {:ok, [String.t()]} | {:error, term()}
  def list_directory(%Environment{type: type} = env, path) do
    with {:ok, impl_module} <- get_impl(type) do
      impl_module.list_directory(env, path)
    end
  end

  # Private functions

  defp get_impl(:cli) do
    {:ok, CodeMySpec.Environments.Cli}
  end

  defp get_impl(:server) do
    # Server implementation not yet created
    {:error, "Server environment not implemented"}
  end

  # defp get_impl(:vscode) do
  #   # VSCode implementation not yet created
  #   {:error, "VSCode environment not implemented"}
  # end

  defp get_impl(:vscode),
    do: Application.get_env(:code_my_spec, :vscode_environment, CodeMySpec.Environments.VSCode)

  defp get_impl(:local),
    do: Application.get_env(:code_my_spec, :local_environment, CodeMySpec.Environments.Local)

  defp get_impl(type) do
    {:error, "Unknown environment type: #{inspect(type)}"}
  end

  def environment_setup_command(environment, attrs) do
    get_impl(environment).environment_setup_command(attrs)
  end

  def docs_environment_teardown_command(environment, attrs) do
    get_impl(environment).docs_environment_teardown_command(attrs)
  end

  def test_environment_teardown_command(environment, attrs) do
    get_impl(environment).test_environment_teardown_command(attrs)
  end

  def code_environment_teardown_command(environment, attrs) do
    get_impl(environment).code_environment_teardown_command(attrs)
  end

  def cmd(environment, command, args, opts \\ []),
    do: get_impl(environment).cmd(command, args, opts)
end

defmodule CodeMySpec.ProjectSync.ChangeHandler do
  @moduledoc """
  Routes file change events to appropriate synchronization operations.

  This is a pure functional module that determines what needs to sync based on
  which file changed, then delegates to `ProjectSync.Sync` for the actual synchronization.
  """

  alias CodeMySpec.Users.Scope
  alias CodeMySpec.ProjectSync.Sync

  @doc """
  Routes a file system change event to the appropriate sync operation.

  ## Parameters
    - `scope` - The user scope
    - `file_path` - The path to the file that changed
    - `events` - List of event types (`:created`, `:modified`, `:removed`, `:renamed`)

  ## Returns
    - `:ok` on success or no-op
    - `{:error, reason}` on failure

  ## Examples

      iex> handle_file_change(scope, "docs/spec/foo.spec.md", [:modified])
      :ok

      iex> handle_file_change(scope, "lib/foo.ex", [:created])
      :ok

      iex> handle_file_change(scope, "README.md", [:modified])
      :ok  # no-op for unrecognized file types
  """
  @spec handle_file_change(Scope.t(), file_path :: String.t(), events :: [atom()]) ::
          :ok | {:error, term()}
  def handle_file_change(scope, file_path, events) when is_list(events) do
    # Ignore :removed events - handled by stale component removal in sync
    if :removed in events do
      :ok
    else
      do_handle_file_change(scope, file_path)
    end
  end

  defp do_handle_file_change(scope, file_path) do
    case determine_file_type(file_path) do
      :spec ->
        Sync.sync_context(scope, file_path)

      :implementation ->
        Sync.sync_context(scope, file_path)

      :other ->
        # No-op for unrecognized file types
        :ok
    end
  rescue
    # Handle malformed paths or other exceptions gracefully
    error ->
      {:error, error}
  end

  @doc """
  Determines the type of file based on path and extension.

  ## Parameters
    - `path` - The file path to classify

  ## Returns
    - `:spec` - Spec file in docs/spec directory
    - `:implementation` - Elixir implementation file in lib directory
    - `:other` - Any other file type

  ## Examples

      iex> determine_file_type("docs/spec/foo.spec.md")
      :spec

      iex> determine_file_type("lib/foo.ex")
      :implementation

      iex> determine_file_type("test/foo_test.exs")
      :other

      iex> determine_file_type("README.md")
      :other
  """
  @spec determine_file_type(String.t()) :: :spec | :implementation | :other
  def determine_file_type(path) when is_binary(path) do
    cond do
      is_spec_file?(path) -> :spec
      is_implementation_file?(path) -> :implementation
      true -> :other
    end
  end

  # Check if path is a spec file in docs/spec directory
  defp is_spec_file?(path) do
    String.ends_with?(path, ".spec.md") and String.contains?(path, "docs/spec/")
  end

  # Check if path is an implementation file in lib directory
  defp is_implementation_file?(path) do
    String.ends_with?(path, ".ex") and String.contains?(path, "/lib/")
  end
end

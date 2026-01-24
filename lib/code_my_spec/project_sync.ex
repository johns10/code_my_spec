defmodule CodeMySpec.ProjectSync do
  @moduledoc """
  Public API for orchestrating synchronization of the entire project from filesystem
  to database.

  This is the public interface module following the Dave Thomas pattern:

  - **ProjectSync** (this module) - Public API
  - **ProjectSync.Sync** - Synchronization implementation (all sync logic)
  - **ProjectSync.ChangeHandler** - Routes file changes to sync operations
  """

  alias CodeMySpec.Users.Scope
  alias CodeMySpec.ProjectSync.Sync

  @type sync_result :: %{
          contexts: [CodeMySpec.Components.Component.t()],
          requirements_updated: integer(),
          errors: [term()]
        }

  @doc """
  Performs a complete project synchronization at startup.

  Delegates to `Sync.sync_all/2`.

  ## Parameters
    - `scope` - The user scope
    - `opts` - Options (optional)
      - `:base_dir` - Base directory to sync from (defaults to current working directory)

  ## Returns
    - `{:ok, sync_result}` on success
    - `{:error, reason}` on failure
  """
  @spec sync_all(Scope.t(), keyword()) :: {:ok, sync_result()} | {:error, term()}
  def sync_all(%Scope{} = scope, opts \\ []) do
    Sync.sync_all(scope, opts)
  end
end

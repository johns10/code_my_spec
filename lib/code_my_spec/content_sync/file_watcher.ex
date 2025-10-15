defmodule CodeMySpec.ContentSync.FileWatcher do
  @moduledoc """
  Public API for file watching during development.

  Monitors local content directories for file changes and triggers ContentAdmin
  sync operations. This provides immediate validation feedback during content
  development without manual sync button clicking.

  ## Purpose

  FileWatcher syncs to **ContentAdmin** (NOT Content):
  - ContentAdmin: Multi-tenant validation layer in SaaS platform
  - Stores parse_status and parse_errors for developer feedback
  - Content: Single-tenant production layer in deployed clients

  Publishing flow: FileWatcher → ContentAdmin → (Publish) → Content
  ContentAdmin is NEVER copied to Content. Publishing always pulls fresh from Git.

  ## Configuration

      # config/dev.exs
      config :code_my_spec,
        watch_content: true,
        content_watch_directory: "/Users/developer/my_project/content",
        content_watch_scope: %{
          account_id: 1,
          project_id: 1
        }

      # config/prod.exs
      config :code_my_spec,
        watch_content: false

  ## Supervision Tree

  Add to application.ex:

      children =
        if Application.get_env(:code_my_spec, :watch_content, false) do
          [CodeMySpec.ContentSync.FileWatcher | children]
        else
          children
        end

  ## Architecture

  This module follows Dave Thomas's pattern of separating execution strategy
  from business logic:

  - `FileWatcher` (this module): Public API
  - `FileWatcher.Server`: GenServer implementation with side effects
  - `FileWatcher.Impl`: Pure business logic (100% unit testable)

  ## Testing

  For production use, call `start_link/0` or `start_link/1` without options.
  Application config will be used.

  For testing, inject dependencies:

      FileWatcher.start_link(
        directory: "/tmp/test",
        scope: test_scope,
        debounce_ms: 10,
        sync_fn: fn scope -> send(test_pid, {:synced, scope}); {:ok, %{}} end
      )
  """

  alias CodeMySpec.ContentSync.FileWatcher.Server

  @doc """
  Returns a child specification for use in a supervision tree.

  This is required for `start_supervised!/1` in tests and supervisor usage.
  """
  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 500
    }
  end

  @doc """
  Starts the FileWatcher GenServer.

  Returns `:ignore` if `:watch_content` config is disabled, otherwise starts
  the GenServer and subscribes to FileSystem events for the configured directory.

  ## Options

  For production use, pass no options or empty list. Configuration will be
  loaded from Application environment.

  For testing, you can inject dependencies:

    - `:directory` - Override watched directory
    - `:scope` - Override scope (provide Scope struct directly)
    - `:debounce_ms` - Override debounce delay (useful for fast tests)
    - `:sync_fn` - Override sync function (useful for mocking)
    - `:enabled` - Override enabled check (for testing conditional startup)

  ## Returns

    - `{:ok, pid}` - Successfully started GenServer
    - `:ignore` - File watching is disabled in configuration
    - `{:error, reason}` - Failed to start due to invalid configuration
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    enabled = opts[:enabled] || Application.get_env(:code_my_spec, :watch_content, false)

    case enabled do
      true ->
        GenServer.start_link(Server, opts)

      _ ->
        :ignore
    end
  end

  # ============================================================================
  # Public Utility Functions
  # ============================================================================

  @doc """
  Validates that a directory exists and is actually a directory.

  Returns :ok if valid, {:error, :invalid_directory} otherwise.

  ## Examples

      iex> FileWatcher.validate_directory("/tmp")
      :ok

      iex> FileWatcher.validate_directory("/nonexistent")
      {:error, :invalid_directory}
  """
  defdelegate validate_directory(directory), to: CodeMySpec.ContentSync.FileWatcher.Impl

  @doc """
  Checks if an event list contains relevant file events.

  Returns true if events contain :modified, :created, or :removed.

  ## Examples

      iex> FileWatcher.relevant_event?([:modified])
      true

      iex> FileWatcher.relevant_event?([])
      false
  """
  defdelegate relevant_event?(events), to: CodeMySpec.ContentSync.FileWatcher.Impl
end

defmodule CodeMySpecCli.Components.FileSyncStatus do
  @moduledoc """
  Component that displays the file sync status by polling FileWatcherServer.
  """

  import Ratatouille.View

  alias CodeMySpec.ProjectSync.FileWatcherServer

  @doc """
  Renders the file sync status indicator.

  Shows:
  - [*] Files syncing... (when FileWatcherServer is running)
  - [ ] Idle (when FileWatcherServer is not running)
  """
  def render do
    running? = FileWatcherServer.running?()

    if running? do
      label do
        text(content: "[*] ", color: :green)
        text(content: "Files syncing...", color: :yellow)
      end
    else
      label do
        text(content: "[ ] ", color: :yellow)
        text(content: "Idle", color: :yellow)
      end
    end
  end
end
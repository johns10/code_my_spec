defmodule CodeMySpec.Environments.Environment do
  @moduledoc """
  Opaque struct representing an execution context.

  This struct encapsulates implementation-specific details for different execution
  environments (CLI with tmux, server-side, VS Code client). Callers should treat
  this as opaque and never access its fields directly.

  ## Fields

  - `type` - Environment type identifier (`:cli`, `:server`, `:vscode`)
  - `ref` - Implementation-specific reference (window_ref, process_id, connection_id)
  - `cwd` - Current working directory for the environment
  - `metadata` - Optional context information

  ## Examples

      # CLI environment with tmux window reference
      %Environment{
        type: :cli,
        ref: "@12",
        cwd: "/path/to/project",
        metadata: %{session_id: 123}
      }

      # Server environment (no ref needed)
      %Environment{
        type: :server,
        ref: nil,
        cwd: "/path/to/project",
        metadata: %{}
      }

      # VSCode environment with connection ID
      %Environment{
        type: :vscode,
        ref: "conn-abc123",
        cwd: "/path/to/workspace",
        metadata: %{workspace: "/path/to/workspace"}
      }
  """

  @type t :: %__MODULE__{
          type: atom(),
          ref: term(),
          cwd: String.t() | nil,
          metadata: map()
        }

  defstruct [:type, :ref, :cwd, metadata: %{}]
end

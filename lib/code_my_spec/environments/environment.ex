defmodule CodeMySpec.Environments.Environment do
  @moduledoc """
  Opaque struct representing an execution context.

  This struct encapsulates implementation-specific details for different execution
  environments (CLI with tmux, server-side, VS Code client). Callers should treat
  this as opaque and never access its fields directly.

  ## Fields

  - `type` - Environment type identifier (`:cli`, `:server`, `:vscode`)
  - `ref` - Implementation-specific reference (window_ref, process_id, connection_id)
  - `metadata` - Optional context information

  ## Examples

      # CLI environment with tmux window reference
      %Environment{
        type: :cli,
        ref: "@12",
        metadata: %{session_id: 123}
      }

      # Server environment (no ref needed)
      %Environment{
        type: :server,
        ref: nil,
        metadata: %{}
      }

      # VSCode environment with connection ID
      %Environment{
        type: :vscode,
        ref: "conn-abc123",
        metadata: %{workspace: "/path/to/project"}
      }
  """

  @type t :: %__MODULE__{
          type: atom(),
          ref: term(),
          metadata: map()
        }

  defstruct [:type, :ref, metadata: %{}]
end

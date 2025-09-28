defmodule CodeMySpec.Sessions.Command do
  @moduledoc """
  Embedded schema representing a command to be executed during a session.
  """

  use Ecto.Schema
  import Ecto.Changeset
  alias CodeMySpec.Sessions.CommandModuleType

  @type t :: %__MODULE__{
          id: binary() | nil,
          module: String.t() | nil,
          command: String.t() | nil,
          pipe: String.t() | nil,
          timestamp: DateTime.t() | nil
        }

  @primary_key {:id, :binary_id, autogenerate: true}
  embedded_schema do
    field :module, CommandModuleType
    field :command, :string
    field :pipe, :string
    field :timestamp, :utc_datetime_usec
  end

  def changeset(command \\ %__MODULE__{}, attrs) do
    command
    |> cast(attrs, [:module, :command, :pipe])
    |> validate_required([:module, :command, :pipe])
    |> put_timestamp()
  end

  defp put_timestamp(changeset) do
    case get_field(changeset, :timestamp) do
      nil -> put_change(changeset, :timestamp, DateTime.utc_now())
      _ -> changeset
    end
  end

  def new(module, command \\ %{}, pipe \\ nil) do
    %__MODULE__{
      module: module,
      command: command,
      pipe: pipe,
      timestamp: DateTime.utc_now()
    }
  end
end

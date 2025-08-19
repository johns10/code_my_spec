defmodule CodeMySpec.Sessions.Command do
  @moduledoc """
  Embedded schema representing a command to be executed during a session.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: binary() | nil,
          module: String.t() | nil,
          command: String.t() | nil,
          timestamp: DateTime.t() | nil
        }

  @primary_key {:id, :binary_id, autogenerate: true}
  embedded_schema do
    field :module, :string
    field :command, :string
    field :timestamp, :utc_datetime
  end

  def changeset(command \\ %__MODULE__{}, attrs) do
    command
    |> cast(attrs, [:module, :command])
    |> validate_required([:module, :command])
    |> put_timestamp()
  end

  defp put_timestamp(changeset) do
    case get_field(changeset, :timestamp) do
      nil -> put_change(changeset, :timestamp, DateTime.utc_now())
      _ -> changeset
    end
  end

  def new(module, command \\ %{}) do
    %__MODULE__{
      module: module,
      command: command,
      timestamp: DateTime.utc_now()
    }
  end
end

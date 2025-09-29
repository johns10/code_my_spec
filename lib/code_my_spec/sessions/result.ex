defmodule CodeMySpec.Sessions.Result do
  @moduledoc """
  Embedded schema representing the result of executing a command during a session.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: binary() | nil,
          status: :ok | :pending | :error | :warning | nil,
          data: map(),
          code: integer() | nil,
          error_message: String.t() | nil,
          stdout: String.t() | nil,
          stderr: String.t() | nil,
          duration_ms: integer() | nil,
          timestamp: DateTime.t() | nil
        }

  @primary_key {:id, :binary_id, autogenerate: true}
  embedded_schema do
    field :status, Ecto.Enum, values: [:ok, :error, :warning]
    field :data, :map, default: %{}
    field :code, :integer
    field :error_message, :string
    field :stdout, :string
    field :stderr, :string
    field :duration_ms, :integer
    field :timestamp, :utc_datetime
  end

  def changeset(result \\ %__MODULE__{}, attrs) do
    result
    |> cast(attrs, [
      :status,
      :data,
      :code,
      :error_message,
      :stdout,
      :stderr,
      :duration_ms,
      :timestamp
    ])
    |> validate_required([:status])
    |> put_timestamp()
  end

  defp put_timestamp(changeset) do
    case get_field(changeset, :timestamp) do
      nil -> put_change(changeset, :timestamp, DateTime.utc_now())
      _ -> changeset
    end
  end

  def pending(data \\ %{}, opts \\ []) do
    %__MODULE__{
      status: :pending,
      data: data,
      stdout: opts[:stdout],
      code: opts[:code] || 0,
      duration_ms: opts[:duration_ms],
      timestamp: DateTime.utc_now()
    }
  end

  def success(data \\ %{}, opts \\ []) do
    %__MODULE__{
      status: :ok,
      data: data,
      stdout: opts[:stdout],
      code: opts[:code] || 0,
      duration_ms: opts[:duration_ms],
      timestamp: DateTime.utc_now()
    }
  end

  def error(error_message, opts \\ []) do
    %__MODULE__{
      status: :error,
      error_message: error_message,
      data: opts[:data] || %{},
      stderr: opts[:stderr],
      code: opts[:code],
      duration_ms: opts[:duration_ms],
      timestamp: DateTime.utc_now()
    }
  end

  def warning(message, data \\ %{}, opts \\ []) do
    %__MODULE__{
      status: :warning,
      error_message: message,
      data: data,
      stdout: opts[:stdout],
      stderr: opts[:stderr],
      code: opts[:code],
      duration_ms: opts[:duration_ms],
      timestamp: DateTime.utc_now()
    }
  end
end

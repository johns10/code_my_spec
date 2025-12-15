defmodule CodeMySpec.Sessions.Interaction do
  @moduledoc """
  Schema representing an interaction within a session.
  Contains a command and its result (result is nil until command is executed).
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias CodeMySpec.Sessions.{Command, Result, Session}

  @derive Jason.Encoder

  @type t :: %__MODULE__{
          id: binary() | nil,
          session_id: integer() | nil,
          session: Session.t() | Ecto.Association.NotLoaded.t(),
          step_name: String.t() | nil,
          command: Command.t() | nil,
          result: Result.t() | nil,
          completed_at: DateTime.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "interactions" do
    belongs_to :session, Session
    field :step_name, :string
    embeds_one :command, Command
    embeds_one :result, Result, on_replace: :update
    field :completed_at, :utc_datetime_usec

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(interaction \\ %__MODULE__{}, attrs) do
    interaction
    |> cast(attrs, [:session_id, :step_name, :completed_at])
    |> cast_embed(:command, required: true)
    |> cast_embed(:result)
    |> validate_required([:session_id])
    |> foreign_key_constraint(:session_id)
    |> put_completed_at()
  end

  defp put_completed_at(changeset) do
    case get_field(changeset, :result) do
      nil ->
        changeset

      _result ->
        if get_field(changeset, :completed_at) == nil do
          put_change(changeset, :completed_at, DateTime.utc_now())
        else
          changeset
        end
    end
  end

  def new_with_command(command) do
    %__MODULE__{
      id: Ecto.UUID.generate(),
      command: command,
      result: nil,
      completed_at: nil
    }
  end

  def pending?(interaction) do
    is_nil(interaction.result)
  end

  def completed?(interaction) do
    not is_nil(interaction.result)
  end

  def successful?(interaction) do
    completed?(interaction) and interaction.result.status == :ok
  end

  def failed?(interaction) do
    completed?(interaction) and interaction.result.status == :error
  end
end

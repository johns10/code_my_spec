defmodule CodeMySpec.Sessions.Interaction do
  @moduledoc """
  Embedded schema representing an interaction within a session.
  Contains a command and its result (result is nil until command is executed).
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias CodeMySpec.Sessions.{Command, Result}

  @type t :: %__MODULE__{
          id: binary() | nil,
          command: Command.t() | nil,
          result: Result.t() | nil,
          completed_at: DateTime.t() | nil
        }

  @primary_key {:id, :binary_id, autogenerate: true}
  embedded_schema do
    field :step_name, :string
    embeds_one :command, Command
    embeds_one :result, Result, on_replace: :update
    field :completed_at, :utc_datetime
  end

  def changeset(interaction \\ %__MODULE__{}, attrs) do
    interaction
    |> cast(attrs, [])
    |> cast_embed(:command, required: true)
    |> cast_embed(:result)
    |> put_completed_at()
  end

  def add_result_to_interaction_changeset(interaction, result) do
    interaction
    |> change()
    |> put_embed(:result, result)
  end

  defp put_completed_at(changeset) do
    case get_field(changeset, :created_at) do
      nil -> put_change(changeset, :completed_at, DateTime.utc_now())
      _ -> changeset
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

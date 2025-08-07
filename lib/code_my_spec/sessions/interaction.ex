defmodule CodeMySpec.Sessions.Interaction do
  @moduledoc """
  Embedded schema representing an interaction within a session.
  Contains a command and its result (result is nil until command is executed).
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias CodeMySpec.Sessions.{Command, Result}

  @primary_key {:id, :binary_id, autogenerate: true}
  embedded_schema do
    embeds_one :command, Command
    embeds_one :result, Result
    field :completed_at, :utc_datetime
  end

  def changeset(interaction \\ %__MODULE__{}, attrs) do
    interaction
    |> cast_embed(:command, required: true)
    |> cast_embed(:result)
    |> put_completed_at()
  end

  defp put_completed_at(changeset) do
    case get_field(changeset, :created_at) do
      nil -> put_change(changeset, :completed_at, DateTime.utc_now())
      _ -> changeset
    end
  end

  def new_with_command(command) do
    %__MODULE__{
      command: command,
      result: nil,
      completed_at: nil
    }
  end

  def complete_with_result(interaction, result) do
    %{interaction | result: result, completed_at: DateTime.utc_now()}
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

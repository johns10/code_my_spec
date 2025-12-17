defmodule CodeMySpec.Sessions.RuntimeInteraction do
  @moduledoc """
  Ephemeral runtime state for interactions executing asynchronously.

  This struct holds non-durable status updates from agent hook callbacks
  that provide real-time visibility into interaction execution. It is NOT
  persisted to the database - it only lives in the InteractionRegistry.

  Uses Ecto embedded schema with changesets for clean partial updates.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @derive Jason.Encoder

  @primary_key false
  embedded_schema do
    field :interaction_id, :binary_id
    field :agent_state, :string
    field :last_notification, :map
    field :last_activity, :map
    field :last_stopped, :map
    field :conversation_id, :string
    field :timestamp, :utc_datetime_usec
  end

  @type t :: %__MODULE__{
          interaction_id: binary(),
          agent_state: String.t() | nil,
          last_notification: map() | nil,
          last_activity: map() | nil,
          last_stopped: map() | nil,
          conversation_id: String.t() | nil,
          timestamp: DateTime.t()
        }

  @doc """
  Creates a changeset for a RuntimeInteraction.
  Only includes fields present in attrs - enables natural partial updates.
  """
  def changeset(runtime \\ %__MODULE__{}, attrs) do
    runtime
    |> cast(attrs, [
      :interaction_id,
      :agent_state,
      :last_notification,
      :last_activity,
      :last_stopped,
      :conversation_id,
      :timestamp
    ])
    |> validate_required([:interaction_id])
    |> put_timestamp()
  end

  defp put_timestamp(changeset) do
    # Always update timestamp unless explicitly provided
    if get_change(changeset, :timestamp) do
      changeset
    else
      put_change(changeset, :timestamp, DateTime.utc_now())
    end
  end

  @doc """
  Creates a new RuntimeInteraction from attrs.

  ## Examples

      iex> new("interaction-123", %{agent_state: "running"})
      %RuntimeInteraction{
        interaction_id: "interaction-123",
        agent_state: "running",
        timestamp: ~U[2025-01-01 00:00:00Z]
      }
  """
  def new(interaction_id, attrs \\ %{}) do
    attrs
    |> Map.put(:interaction_id, interaction_id)
    |> then(&changeset(%__MODULE__{}, &1))
    |> apply_changes()
  end

  @doc """
  Updates a RuntimeInteraction with new attributes.
  Only updates fields present in attrs - other fields are preserved.

  ## Examples

      iex> runtime = new("interaction-123", %{agent_state: "running", last_notification: %{}})
      iex> update(runtime, %{agent_state: "complete"})
      %RuntimeInteraction{
        interaction_id: "interaction-123",
        agent_state: "complete",
        last_notification: %{},  # Preserved
        timestamp: ~U[2025-01-01 00:00:01Z]
      }

      iex> update(runtime, %{last_notification: nil})  # Explicit clear
      %RuntimeInteraction{last_notification: nil}
  """
  def update(%__MODULE__{} = runtime, attrs) do
    runtime
    |> changeset(attrs)
    |> apply_changes()
  end

  @doc """
  Convert RuntimeInteraction to a plain map.
  """
  def to_map(%__MODULE__{} = runtime) do
    Map.from_struct(runtime)
  end
end

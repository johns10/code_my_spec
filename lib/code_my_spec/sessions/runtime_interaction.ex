defmodule CodeMySpec.Sessions.RuntimeInteraction do
  @moduledoc """
  Ephemeral runtime state for interactions executing asynchronously.

  This struct holds non-durable status updates from agent hook callbacks
  that provide real-time visibility into interaction execution. It is NOT
  persisted to the database - it only lives in the InteractionRegistry.
  """

  @derive Jason.Encoder

  @type t :: %__MODULE__{
          interaction_id: binary(),
          agent_state: String.t() | nil,
          last_notification: map() | nil,
          last_activity: map() | nil,
          conversation_id: String.t() | nil,
          timestamp: DateTime.t()
        }

  @enforce_keys [:interaction_id, :timestamp]
  defstruct [
    :interaction_id,
    :agent_state,
    :last_notification,
    :last_activity,
    :conversation_id,
    :timestamp
  ]

  @doc """
  Create a new RuntimeInteraction from an interaction_id and status map.

  ## Examples

      iex> new("interaction-123", %{agent_state: "running"})
      %RuntimeInteraction{
        interaction_id: "interaction-123",
        agent_state: "running",
        timestamp: ~U[2025-01-01 00:00:00Z]
      }
  """
  def new(interaction_id, attrs \\ %{}) do
    %__MODULE__{
      interaction_id: interaction_id,
      agent_state: Map.get(attrs, :agent_state),
      last_notification: Map.get(attrs, :last_notification),
      last_activity: Map.get(attrs, :last_activity),
      conversation_id: Map.get(attrs, :conversation_id),
      timestamp: Map.get(attrs, :timestamp, DateTime.utc_now())
    }
  end

  @doc """
  Update a RuntimeInteraction with new attributes.

  ## Examples

      iex> runtime = new("interaction-123", %{agent_state: "running"})
      iex> update(runtime, %{agent_state: "complete"})
      %RuntimeInteraction{
        interaction_id: "interaction-123",
        agent_state: "complete",
        timestamp: ~U[2025-01-01 00:00:01Z]
      }
  """
  def update(%__MODULE__{} = runtime, attrs) do
    %{
      runtime
      | agent_state: Map.get(attrs, :agent_state, runtime.agent_state),
        last_notification: Map.get(attrs, :last_notification, runtime.last_notification),
        last_activity: Map.get(attrs, :last_activity, runtime.last_activity),
        conversation_id: Map.get(attrs, :conversation_id, runtime.conversation_id),
        timestamp: Map.get(attrs, :timestamp, DateTime.utc_now())
    }
  end

  @doc """
  Convert RuntimeInteraction to a plain map.

  ## Examples

      iex> runtime = new("interaction-123", %{agent_state: "running"})
      iex> to_map(runtime)
      %{
        interaction_id: "interaction-123",
        agent_state: "running",
        last_notification: nil,
        last_activity: nil,
        conversation_id: nil,
        timestamp: ~U[2025-01-01 00:00:00Z]
      }
  """
  def to_map(%__MODULE__{} = runtime) do
    Map.from_struct(runtime)
  end
end

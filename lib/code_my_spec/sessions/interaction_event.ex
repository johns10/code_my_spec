defmodule CodeMySpec.Sessions.InteractionEvent do
  @moduledoc """
  Ecto schema for InteractionEvent representing a single event capturing real-time
  activity during a specific interaction execution. Events are stored in an append-only
  log, providing visibility into agent operations between command issuance and result submission.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias CodeMySpec.Sessions.Interaction

  @type event_type ::
          :proxy_request
          | :proxy_response
          | :session_start
          | :notification_hook
          | :session_stop_hook
          | :post_tool_use
          | :user_prompt_submit
          | :stop

  @type t :: %__MODULE__{
          id: integer() | nil,
          interaction_id: binary() | nil,
          event_type: event_type() | nil,
          data: map() | nil,
          metadata: map() | nil,
          sent_at: DateTime.t() | nil,
          interaction: Interaction.t() | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "interaction_events" do
    field :event_type, CodeMySpec.Sessions.EventType

    field :data, :map
    field :metadata, :map
    field :sent_at, :utc_datetime_usec

    belongs_to :interaction, Interaction, type: :binary_id

    timestamps(type: :utc_datetime_usec)
  end

  @doc """
  Creates a changeset for InteractionEvent. This changeset is used for creating new events.

  ## Parameters
  - event: InteractionEvent struct (new or existing)
  - attrs: Map of attributes containing interaction_id, event_type, sent_at, data, and optionally metadata

  ## Validations
  - Requires: interaction_id, event_type, sent_at, data
  - Validates event_type is in the allowed enum values
  - Foreign key constraint on interaction_id

  ## Usage Notes
  - Events are append-only and should not be updated after insertion
  - The `data` field accepts any map structure without validation
  - The `sent_at` timestamp is client-provided, not server-generated
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(event, attrs) do
    event
    |> cast(attrs, [:interaction_id, :event_type, :sent_at, :data, :metadata])
    |> validate_required([:interaction_id, :event_type, :sent_at, :data])
    |> foreign_key_constraint(:interaction_id)
  end
end

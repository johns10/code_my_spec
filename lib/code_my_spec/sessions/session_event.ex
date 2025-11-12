defmodule CodeMySpec.Sessions.SessionEvent do
  @moduledoc """
  Ecto schema for SessionEvent representing a single event capturing real-time
  activity during Claude Code session execution. Events are stored in an append-only
  log, providing visibility into agent operations between command issuance and result submission.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias CodeMySpec.Sessions.Session

  @type event_type ::
          :conversation_started
          | :conversation_message_sent
          | :conversation_message_received
          | :conversation_ended
          | :tool_called
          | :tool_result
          | :file_created
          | :file_modified
          | :file_deleted
          | :command_started
          | :command_output
          | :command_completed
          | :hook_triggered
          | :hook_completed
          | :session_status_changed
          | :session_paused
          | :session_resumed
          | :error_occurred

  @type t :: %__MODULE__{
          id: integer() | nil,
          session_id: integer() | nil,
          event_type: event_type() | nil,
          data: map() | nil,
          metadata: map() | nil,
          sent_at: DateTime.t() | nil,
          session: Session.t() | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "session_events" do
    field :event_type, Ecto.Enum,
      values: [
        # Conversation Events
        :conversation_started,
        :conversation_message_sent,
        :conversation_message_received,
        :conversation_ended,
        # Tool Events
        :tool_called,
        :tool_result,
        # File Events
        :file_created,
        :file_modified,
        :file_deleted,
        # Command Events
        :command_started,
        :command_output,
        :command_completed,
        # Hook Events
        :hook_triggered,
        :hook_completed,
        # State Events
        :session_status_changed,
        :session_paused,
        :session_resumed,
        # Error Events
        :error_occurred
      ]

    field :data, :map
    field :metadata, :map
    field :sent_at, :utc_datetime

    belongs_to :session, Session

    timestamps(type: :utc_datetime)
  end

  @doc """
  Creates a changeset for SessionEvent. This changeset is used for creating new events.

  ## Parameters
  - event: SessionEvent struct (new or existing)
  - attrs: Map of attributes containing session_id, event_type, sent_at, data, and optionally metadata

  ## Validations
  - Requires: session_id, event_type, sent_at, data
  - Validates event_type is in the allowed enum values
  - Foreign key constraint on session_id

  ## Usage Notes
  - Events are append-only and should not be updated after insertion
  - The `data` field accepts any map structure without validation
  - The `sent_at` timestamp is client-provided, not server-generated
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(event, attrs) do
    event
    |> cast(attrs, [:session_id, :event_type, :sent_at, :data, :metadata])
    |> validate_required([:session_id, :event_type, :sent_at, :data])
    |> foreign_key_constraint(:session_id)
  end
end

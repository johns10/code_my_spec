defmodule CodeMySpec.Sessions.OrchestratorBehaviour do
  @moduledoc """
  Behaviour for session type orchestrators.

  Orchestrators are responsible for:
  - Determining the next interaction step based on session state
  - Determining if a session is complete based on its current state

  They do NOT handle state transitions - that's the responsibility of
  the SessionsRepository and ResultHandler.
  """

  alias CodeMySpec.Sessions.{Session, Interaction}

  @doc """
  Returns the list of step modules in order for this orchestrator.
  """
  @callback steps() :: [module()]

  @doc """
  Determines the next interaction module for the given session.

  Returns:
  - `{:ok, module}` - The next step module to execute
  - `{:error, :session_complete}` - No more steps, session is complete
  - `{:error, reason}` - Invalid state or other error
  """
  @callback get_next_interaction(session :: Session.t()) ::
              {:ok, module()} | {:error, :session_complete | atom()}

  @doc """
  Checks if the session is complete based on its current state.

  This is called after handling a result to determine if the session
  should be marked as complete.

  Can accept either a Session or an Interaction. When given a Session,
  it typically checks the last interaction. When given an Interaction,
  it checks if that specific interaction indicates completion.

  Returns true if the session has reached its final state.
  """
  @callback complete?(session_or_interaction :: Session.t() | Interaction.t()) :: boolean()
end

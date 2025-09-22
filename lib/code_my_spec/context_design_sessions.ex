defmodule CodeMySpec.ContextDesignSessions do
  @moduledoc """
  Manages the multi-step workflow for creating new application contexts through
  AI-assisted documentation generation, validation, and component scaffolding.

  Provides a stateless interface for context design session orchestration,
  with all workflow state persisted in the database through the Sessions context.
  """

  alias CodeMySpec.ContextDesignSessions.Orchestrator

  @type session_id :: String.t()

  defdelegate get_next_interaction(step_module_atom), to: Orchestrator
  defdelegate steps(), to: Orchestrator
end

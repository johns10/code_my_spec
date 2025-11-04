defmodule CodeMySpec.ContextComponentsDesignSessions do
  @moduledoc """
  Context Components Design Sessions context for orchestrating AI-driven workflows that generate
  design documentation for all components within a Phoenix context.

  This module provides the main interface for managing context-wide component design sessions that
  follow a structured workflow of spawning child design sessions, coordinating review sessions, and
  creating pull requests with generated documentation.

  ## Workflow Steps

  The context components design session follows these orchestrated steps:

  1. **Initialize** - Creates git branch and loads context components list
  2. **SpawnComponentDesignSessions** - Creates child ComponentDesignSession records in agentic mode
     for each component, returns command with child_session_ids for parallel execution
  3. **SpawnReviewSession** - Creates ComponentDesignReviewSession in agentic mode to validate
     consistency across all component designs, returns command with review_session_id
  4. **Finalize** - Creates pull request with all generated design documentation and marks session complete

  ## Validation and Retry Logic

  Steps that spawn child sessions (SpawnComponentDesignSessions, SpawnReviewSession) include
  validation in their handle_result implementation:
  - Verify all child sessions reached terminal state (:complete, :failed, :cancelled)
  - Verify expected design files exist on filesystem
  - Return :error status if validation fails, triggering retry loop in orchestrator
  - Return :ok status when validation passes, allowing workflow to proceed

  ## Usage

  Context components design sessions are executed through the general Sessions context,
  which handles the orchestration and state management. The workflow coordinates multiple
  child sessions running in parallel, with the client monitoring their progress and calling
  handle_result on the parent session when all children complete.
  """

  alias CodeMySpec.ContextComponentsDesignSessions.Orchestrator

  defdelegate get_next_interaction(step_module_atom), to: Orchestrator
  defdelegate steps(), to: Orchestrator
end
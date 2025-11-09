defmodule CodeMySpec.ContextCodingSessions do
  @moduledoc """
  Context Coding Sessions context for orchestrating the implementation of all components
  within a Phoenix context.

  This module coordinates parallel ComponentCodingSession workflows for each component
  within a target context, ensuring all implementations are complete and validated before
  finalizing the context implementation.

  ## Workflow Steps

  The context coding session follows these orchestrated steps:

  1. **Initialize** - Creates git branch and sets up workspace for context implementation
  2. **Spawn Component Coding Sessions** - Creates child ComponentCodingSession records for
     each component in the context, returns command with child_session_ids for parallel execution
  3. **Validate Component Implementations** - Performed in SpawnComponentCodingSessions.handle_result/4,
     verifies all child sessions completed successfully
  4. **Finalize** - Commits all implementation code, pushes to remote, and marks session complete

  ## Usage

  Context coding sessions are executed through the general Sessions context,
  which handles the orchestration and state management.
  """

  alias CodeMySpec.ContextCodingSessions.Orchestrator

  defdelegate get_next_interaction(step_module_atom), to: Orchestrator
  defdelegate steps(), to: Orchestrator
end

defmodule CodeMySpec.ContextTestingSessions do
  @moduledoc """
  Context Testing Sessions context for orchestrating the testing of all components
  within a Phoenix context.

  This module coordinates parallel ComponentTestingSession workflows for each component
  within a target context, ensuring all tests are created and passing before
  finalizing the context testing session.

  ## Workflow Steps

  The context testing session follows these orchestrated steps:

  1. **Initialize** - Creates git branch and sets up workspace for context testing
  2. **Spawn Component Testing Sessions** - Creates child ComponentTestingSession records for
     each component in the context, returns command with child_session_ids for parallel execution
  3. **Validate Component Tests** - Performed in SpawnComponentTestingSessions.handle_result/4,
     verifies all child sessions completed successfully
  4. **Finalize** - Commits all test files, pushes to remote, and marks session complete

  ## Usage

  Context testing sessions are executed through the general Sessions context,
  which handles the orchestration and state management.
  """

  alias CodeMySpec.ContextTestingSessions.Orchestrator

  defdelegate get_next_interaction(step_module_atom), to: Orchestrator
  defdelegate steps(), to: Orchestrator
end

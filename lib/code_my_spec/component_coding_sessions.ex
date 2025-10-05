defmodule CodeMySpec.ComponentCodingSessions do
  @moduledoc """
  Component Coding Sessions context for orchestrating AI-driven component implementation workflows.

  This module provides the main interface for managing component coding sessions that follow
  a structured workflow with AI agents for implementing component code and fixing test failures.

  ## Workflow Steps

  The component coding session follows these orchestrated steps:

  1. **Initialize** - Sets up workspace and repository state for component implementation
  2. **Generate Implementation** - Creates component implementation code using AI agents
  3. **Run Tests** - Executes ExUnit test suite and analyzes results
  4. **Fix Test Failures** - Addresses test failures through iterative AI conversation (if needed)
  5. **Finalize** - Commits implementation and completes session

  ## Usage

  Component coding sessions are executed through the general Sessions context,
  which handles the orchestration and state management.
  """

  alias CodeMySpec.ComponentCodingSessions.Orchestrator

  defdelegate get_next_interaction(step_module_atom), to: Orchestrator
  defdelegate steps(), to: Orchestrator
end

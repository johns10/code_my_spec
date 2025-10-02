defmodule CodeMySpec.ComponentCodingSessions do
  @moduledoc """
  Component Coding Sessions context for orchestrating AI-driven component implementation workflows.

  This module provides the main interface for managing component coding sessions that follow
  a test-driven development workflow with AI agents, including fixture generation, test writing,
  implementation, and iterative test failure resolution.

  ## Workflow Steps

  The component coding session follows these orchestrated steps:

  1. **Initialize** - Sets up workspace and repository state for component implementation
  2. **Read Component Design** - Loads component design documentation into session state
  3. **Analyze and Generate Fixtures** - Examines existing fixtures and generates reusable test fixtures
  4. **Generate Tests** - Creates comprehensive test files following TDD principles
  5. **Generate Implementation** - Creates component implementation code to satisfy the tests
  6. **Run Tests and Analyze** - Executes ExUnit test suite and analyzes results
  7. **Fix Test Failures** - Addresses test failures through iterative AI conversation (if needed)
  8. **Finalize** - Updates component status and completes session

  ## Usage

  Component coding sessions are executed through the general Sessions context,
  which handles the orchestration and state management.
  """

  alias CodeMySpec.ComponentCodingSessions.Orchestrator

  defdelegate get_next_interaction(step_module_atom), to: Orchestrator
  defdelegate steps(), to: Orchestrator
end
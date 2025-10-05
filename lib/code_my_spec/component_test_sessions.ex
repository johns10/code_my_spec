defmodule CodeMySpec.ComponentTestSessions do
  @moduledoc """
  Component Test Sessions context for orchestrating AI-driven test and fixture generation workflows.

  This module provides the main interface for managing component test sessions that follow
  a structured workflow of test generation using AI agents.

  ## Workflow Steps

  The component test session follows these orchestrated steps:

  1. **Initialize** - Sets up workspace and repository state for test generation
  2. **Generate Tests and Fixtures** - Creates test and fixture files using AI agents
  3. **Finalize** - Commits tests and fixtures to repository

  ## Usage

  Component test sessions are executed through the general Sessions context,
  which handles the orchestration and state management.
  """

  alias CodeMySpec.ComponentTestSessions.Orchestrator

  defdelegate get_next_interaction(step_module_atom), to: Orchestrator
  defdelegate steps(), to: Orchestrator
end

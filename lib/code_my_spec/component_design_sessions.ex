defmodule CodeMySpec.ComponentDesignSessions do
  @moduledoc """
  Component Design Sessions context for orchestrating AI-driven component design workflows.

  This module provides the main interface for managing component design sessions that follow
  a structured workflow of design generation, validation, and iterative revision using AI agents.

  ## Workflow Steps

  The component design session follows these orchestrated steps:

  1. **Initialize** - Sets up session state and validates requirements
  2. **Read Context Design** - Loads existing context design for reference
  3. **Generate Component Design** - Creates initial component design using AI agents
  4. **Read Component Design** - Loads the generated design into session state
  5. **Validate Design** - Checks design against requirements and standards
  6. **Revise Design** - Iteratively improves design based on validation feedback

  ## Usage

  Component design sessions are executed through the general Sessions context,
  which handles the orchestration and state management.
  """

  alias CodeMySpec.ComponentDesignSessions.Orchestrator

  defdelegate get_next_interaction(step_module_atom), to: Orchestrator
  defdelegate steps(), to: Orchestrator
end

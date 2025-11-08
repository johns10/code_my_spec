defmodule CodeMySpec.ContextDesignReviewSessions do
  @moduledoc """
  Context Design Review Sessions orchestrate comprehensive architectural reviews
  of Phoenix contexts and their child components.

  This session type coordinates AI-driven holistic analysis of context designs,
  validating architectural consistency, checking integration points, verifying
  alignment with user stories, and producing review documentation.

  ## Workflow Steps

  1. **ExecuteReview** - Instructs Claude to review context and child component designs
  2. **Finalize** - Completes the session and performs cleanup

  ## Usage

  Context design review sessions are executed through the general Sessions context,
  which handles orchestration and state management.
  """

  alias CodeMySpec.ContextDesignReviewSessions.Orchestrator

  defdelegate get_next_interaction(step_module_atom), to: Orchestrator
  defdelegate steps(), to: Orchestrator
end

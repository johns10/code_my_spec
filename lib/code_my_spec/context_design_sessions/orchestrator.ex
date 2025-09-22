defmodule CodeMySpec.ContextDesignSessions.Orchestrator do
  @moduledoc """
  Stateless orchestrator for context design session workflows.
  All state lives in the Session record and its embedded Interactions.
  """

  alias CodeMySpec.Sessions.{Interaction, Command}

  @step_modules [
    CodeMySpec.ContextDesignSessions.Steps.Initialize,
    CodeMySpec.ContextDesignSessions.Steps.GenerateContextDesign,
    CodeMySpec.ContextDesignSessions.Steps.ValidateDesign,
    CodeMySpec.ContextDesignSessions.Steps.Finalize
  ]

  def steps(), do: @step_modules

  def get_next_interaction(nil), do: {:ok, hd(@step_modules)}

  def get_next_interaction(%Interaction{command: %Command{module: last_interaction_module}}) do
    if last_interaction_module in @step_modules do
      get_next_interaction(last_interaction_module, @step_modules)
    else
      {:error, :invalid_interaction}
    end
  end

  def get_next_interaction(this, [that, next | _tail]) when this == that do
    {:ok, next}
  end

  def get_next_interaction(this, [that, next]) when this == that do
    {:ok, next}
  end

  def get_next_interaction(last, [last]) do
    {:error, :session_complete}
  end

  def get_next_interaction(last, [_ | tail]) do
    get_next_interaction(last, tail)
  end
end

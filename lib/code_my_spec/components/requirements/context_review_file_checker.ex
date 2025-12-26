defmodule CodeMySpec.Components.Requirements.ContextReviewFileChecker do
  @moduledoc """
  Checker for context-level design review file existence.

  This checker verifies that a context has an associated design review file,
  which documents the architectural analysis and validation of the context
  and its child components.
  """

  @behaviour CodeMySpec.Components.Requirements.CheckerBehaviour
  alias CodeMySpec.Components.Component

  def check(%{name: name} = requirement_spec, %Component{component_status: component_status}, _opts \\ []) do
    {satisfied, details} =
      case {name, component_status} do
        {:review_file, %{review_exists: true}} ->
          {true, %{status: "Context design review file exists"}}

        {:review_file, %{review_exists: false}} ->
          {false, %{reason: "Context design review file missing"}}

        # Handle case where component_status is nil (shouldn't happen but defensive)
        {_, nil} ->
          {false, %{reason: "Component status not available"}}

        # Handle case where component_status doesn't have review_exists field
        {:review_file, _} ->
          {false, %{reason: "Review status not tracked for this component"}}

        # Handle unexpected requirement names
        {_, _} ->
          {false, %{reason: "Invalid requirement name for context review checker"}}
      end

    %{
      name: Atom.to_string(requirement_spec.name),
      type: :context_review,
      description: generate_description(requirement_spec.name),
      checker_module: Atom.to_string(requirement_spec.checker),
      satisfied_by: requirement_spec.satisfied_by,
      satisfied: satisfied,
      checked_at: DateTime.utc_now(),
      details: details
    }
  end

  defp generate_description(:review_file),
    do: "Context design review documentation exists"

  defp generate_description(name),
    do: "Context review requirement #{name} is satisfied"
end

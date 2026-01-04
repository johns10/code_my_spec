defmodule CodeMySpec.Requirements.TestStatusChecker do
  @behaviour CodeMySpec.Requirements.CheckerBehaviour

  alias CodeMySpec.Components.Component
  alias CodeMySpec.Requirements.RequirementDefinition
  alias CodeMySpec.Users.Scope

  def check(
        %Scope{},
        %RequirementDefinition{
          name: name,
          artifact_type: artifact_type,
          description: description,
          checker: checker,
          satisfied_by: satisfied_by
        } = _requirement_definition,
        %Component{component_status: component_status},
        _opts \\ []
      ) do
    {satisfied, details} =
      case {String.to_existing_atom(name), component_status} do
        {:tests_passing, %{test_exists: false}} ->
          {false, %{reason: "No test file exists"}}

        {:tests_passing, %{test_status: :passing}} ->
          {true, %{status: "Tests are passing"}}

        {:tests_passing, %{test_status: :failing}} ->
          {false, %{reason: "Tests are failing"}}

        {:tests_passing, %{test_status: :not_run}} ->
          {false, %{reason: "Tests have not been run"}}

        # Handle case where component_status is nil (shouldn't happen but defensive)
        {_, nil} ->
          {false, %{reason: "Component status not available"}}

        # Handle case where component_status doesn't match expected structure
        {_, _} ->
          {false, %{reason: "Invalid component status structure"}}
      end

    %{
      name: name,
      artifact_type: artifact_type,
      description: description,
      checker_module: checker,
      satisfied_by: satisfied_by,
      satisfied: satisfied,
      score: if(satisfied, do: 1.0, else: 0.0),
      checked_at: DateTime.utc_now(),
      details: details
    }
  end
end

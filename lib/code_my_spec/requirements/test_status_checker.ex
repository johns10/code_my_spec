defmodule CodeMySpec.Requirements.TestStatusChecker do
  @behaviour CodeMySpec.Requirements.CheckerBehaviour
  alias CodeMySpec.Components.Component

  def check(
        %{name: name} = requirement_spec,
        %Component{component_status: component_status},
        _opts \\ []
      ) do
    {satisfied, details} =
      case {name, component_status} do
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
      name: Atom.to_string(requirement_spec.name),
      type: :test_status,
      description: generate_description(requirement_spec.name),
      checker_module: Atom.to_string(requirement_spec.checker),
      satisfied_by: requirement_spec.satisfied_by,
      satisfied: satisfied,
      checked_at: DateTime.utc_now(),
      details: details
    }
  end

  defp generate_description(:tests_passing), do: "Component tests are passing"
  defp generate_description(name), do: "Test requirement #{name} is satisfied"
end

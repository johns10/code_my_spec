defmodule CodeMySpec.Requirements.FileExistenceChecker do
  @behaviour CodeMySpec.Requirements.CheckerBehaviour
  alias CodeMySpec.Components.Component

  def check(
        %{name: name} = requirement_spec,
        %Component{component_status: component_status},
        _opts \\ []
      ) do
    {satisfied, details} =
      case {name, component_status} do
        {:spec_file, %{spec_exists: true}} ->
          {true, %{status: "Design file exists"}}

        {:spec_file, %{spec_exists: false}} ->
          {false, %{reason: "Design file missing"}}

        {:design_file, %{design_exists: true}} ->
          {true, %{status: "Design file exists"}}

        {:design_file, %{design_exists: false}} ->
          {false, %{reason: "Design file missing"}}

        {:implementation_file, %{code_exists: true}} ->
          {true, %{status: "Implementation file exists"}}

        {:implementation_file, %{code_exists: false}} ->
          {false, %{reason: "Implementation file missing"}}

        {:test_file, %{test_exists: true}} ->
          {true, %{status: "Test file exists"}}

        {:test_file, %{test_exists: false}} ->
          {false, %{reason: "Test file missing"}}

        # Handle case where component_status is nil (shouldn't happen but defensive)
        {_, nil} ->
          {false, %{reason: "Component status not available"}}

        # Handle case where component_status doesn't match expected structure
        {_, _} ->
          {false, %{reason: "Invalid component status structure"}}
      end

    %{
      name: Atom.to_string(requirement_spec.name),
      type: :file_existence,
      description: generate_description(requirement_spec.name),
      checker_module: Atom.to_string(requirement_spec.checker),
      satisfied_by: requirement_spec.satisfied_by,
      satisfied: satisfied,
      checked_at: DateTime.utc_now(),
      details: details
    }
  end

  defp generate_description(:design_file), do: "Component design documentation exists"
  defp generate_description(:implementation_file), do: "Component implementation file exists"
  defp generate_description(:test_file), do: "Component test file exists"
  defp generate_description(name), do: "File requirement #{name} is satisfied"
end

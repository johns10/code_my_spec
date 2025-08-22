defmodule CodeMySpec.Components.Requirements.FileExistenceChecker do
  @behaviour CodeMySpec.Components.Requirements.CheckerBehaviour
  alias CodeMySpec.Components.Requirements.Requirement

  def check(%Requirement{} = requirement, component_status) do
    case {Requirement.name_atom(requirement), component_status} do
      {:design_file, %{design_exists: true}} ->
        {:satisfied, %{status: "Design file exists"}}
      
      {:design_file, %{design_exists: false}} ->
        {:not_satisfied, %{status: "Design file missing"}}
      
      {:implementation_file, %{code_exists: true}} ->
        {:satisfied, %{status: "Implementation file exists"}}
      
      {:implementation_file, %{code_exists: false}} ->
        {:not_satisfied, %{status: "Implementation file missing"}}
      
      {:test_file, %{test_exists: true}} ->
        {:satisfied, %{status: "Test file exists"}}
      
      {:test_file, %{test_exists: false}} ->
        {:not_satisfied, %{status: "Test file missing"}}
    end
  end
end

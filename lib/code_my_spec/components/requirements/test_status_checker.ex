defmodule CodeMySpec.Components.Requirements.TestStatusChecker do
  @behaviour CodeMySpec.Components.Requirements.CheckerBehaviour
  alias CodeMySpec.Components.Requirements.Requirement

  def check(%Requirement{} = requirement, component_status) do
    case {Requirement.name_atom(requirement), component_status} do
      {:tests_passing, %{test_exists: false}} ->
        {:not_satisfied, %{reason: "No test file exists"}}

      {:tests_passing, %{test_status: :passing}} ->
        {:satisfied, %{status: "Tests are passing"}}

      {:tests_passing, %{test_status: :failing}} ->
        {:not_satisfied, %{reason: "Tests are failing"}}

      {:tests_passing, %{test_status: :not_run}} ->
        {:not_satisfied, %{reason: "Tests have not been run"}}
    end
  end
end

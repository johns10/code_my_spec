defmodule CodeMySpec.Components.Requirements.FileExistenceChecker do
  @behaviour CodeMySpec.Components.Requirements.CheckerBehaviour

  def check(%{name: :design_file}, %{design_exists: true}),
    do: {:satisfied, %{status: "Design file exists"}}

  def check(%{name: :design_file}, %{design_exists: false}),
    do: {:not_satisfied, %{status: "Design file missing"}}

  def check(%{name: :implementation_file}, %{code_exists: true}),
    do: {:satisfied, %{status: "Implementation file exists"}}

  def check(%{name: :implementation_file}, %{code_exists: false}),
    do: {:not_satisfied, %{status: "Implementation file missing"}}

  def check(%{name: :test_file}, %{test_exists: true}),
    do: {:satisfied, %{status: "Test file exists"}}

  def check(%{name: :test_file}, %{test_exists: false}),
    do: {:not_satisfied, %{status: "Test file missing"}}
end

defmodule CodeMySpec.Components.Requirements.TestStatusChecker do
  @behaviour CodeMySpec.Components.Requirements.CheckerBehaviour

  def check(%{name: :tests_passing}, %{test_exists: false}) do
    {:not_satisfied, %{reason: "No test file exists"}}
  end

  def check(%{name: :tests_passing}, %{test_status: :passing}) do
    {:satisfied, %{status: "Tests are passing"}}
  end

  def check(%{name: :tests_passing}, %{test_status: :failing}) do
    {:not_satisfied, %{reason: "Tests are failing"}}
  end

  def check(%{name: :tests_passing}, %{test_status: :not_run}) do
    {:not_satisfied, %{reason: "Tests have not been run"}}
  end
end

defmodule CodeMySpec.Quality do
  @moduledoc """
  Quality checks for validating implementation against design specifications.
  """

  defdelegate spec_test_alignment(component, project, opts \\ []),
    to: CodeMySpec.Quality.SpecTestAlignment

  defdelegate check_tdd_state(result, opts \\ []), to: CodeMySpec.Quality.Tdd

  defdelegate check_compilation(result), to: CodeMySpec.Quality.Compile
end

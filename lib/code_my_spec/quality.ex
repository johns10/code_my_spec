defmodule CodeMySpec.Quality do
  @moduledoc """
  Quality checks for validating implementation against design specifications.
  """

  defdelegate spec_test_alignment(component, project, opts \\ []),
    to: CodeMySpec.Quality.SpecTestAlignment
end

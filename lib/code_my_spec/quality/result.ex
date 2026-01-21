defmodule CodeMySpec.Quality.Result do
  @moduledoc """
  Embedded schema representing quality check results.

  Supports both pass/fail and incremental quality scoring (0.0 to 1.0).
  """
  use Ecto.Schema

  @primary_key false
  embedded_schema do
    field :score, :float
    field :errors, {:array, :string}, default: []
  end

  @doc """
  Creates a passing result with perfect score.
  """
  def ok do
    %__MODULE__{score: 1.0, errors: []}
  end

  @doc """
  Creates a failing result with the given errors.
  Score is 0.0 when there are errors.
  """
  def error(errors) when is_list(errors) do
    %__MODULE__{score: 0.0, errors: errors}
  end

  @doc """
  Creates a result with a custom score and errors.
  Useful for partial/incremental failure scenarios.
  """
  def partial(score, errors) when is_float(score) and score >= 0.0 and score <= 1.0 do
    %__MODULE__{score: score, errors: errors}
  end
end

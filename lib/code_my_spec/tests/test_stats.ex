defmodule CodeMySpec.Tests.TestStats do
  use Ecto.Schema

  @type t :: %__MODULE__{
          duration_ms: non_neg_integer(),
          load_time_ms: non_neg_integer() | nil,
          passes: non_neg_integer(),
          failures: non_neg_integer(),
          pending: non_neg_integer(),
          invalid: non_neg_integer(),
          tests: non_neg_integer(),
          suites: non_neg_integer(),
          started_at: NaiveDateTime.t(),
          finished_at: NaiveDateTime.t()
        }

  @primary_key false
  embedded_schema do
    field :duration_ms, :integer
    field :load_time_ms, :integer
    field :passes, :integer, default: 0
    field :failures, :integer, default: 0
    field :pending, :integer, default: 0
    field :invalid, :integer, default: 0
    field :tests, :integer, default: 0
    field :suites, :integer, default: 0
    field :started_at, :naive_datetime
    field :finished_at, :naive_datetime
  end
end

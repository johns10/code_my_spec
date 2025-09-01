defmodule CodeMySpec.Tests.TestRun do
  alias CodeMySpec.Tests.TestStats
  alias CodeMySpec.Tests.TestResult
  use Ecto.Schema

  @type execution_status :: :success | :failure | :timeout | :error
  @type t :: %__MODULE__{
          project_path: String.t(),
          command: String.t(),
          exit_code: non_neg_integer() | nil,
          execution_status: execution_status(),
          seed: non_neg_integer() | nil,
          including: [String.t()],
          excluding: [String.t()],
          stats: TestStats.t() | nil,
          raw_output: String.t(),
          executed_at: NaiveDateTime.t()
        }

  @primary_key false
  embedded_schema do
    field :project_path, :string
    field :command, :string
    field :exit_code, :integer
    field :execution_status, Ecto.Enum, values: [:success, :failure, :timeout, :error]
    field :seed, :integer
    field :including, {:array, :string}, default: []
    field :excluding, {:array, :string}, default: []
    field :raw_output, :string
    field :executed_at, :naive_datetime
    embeds_one :stats, TestStats
    embeds_many :tests, TestResult
    embeds_many :failures, TestResult
    embeds_many :pending, TestResult
  end

  def changeset(test_run \\ %__MODULE__{}, attrs) do
    test_run
    |> Ecto.Changeset.cast(attrs, [
      :project_path,
      :command,
      :exit_code,
      :execution_status,
      :seed,
      :including,
      :excluding,
      :raw_output,
      :executed_at
    ])
    |> Ecto.Changeset.cast_embed(:stats)
    |> Ecto.Changeset.cast_embed(:tests, with: &TestResult.changeset/2)
    |> Ecto.Changeset.cast_embed(:failures, with: &TestResult.changeset/2)
    |> Ecto.Changeset.cast_embed(:pending, with: &TestResult.changeset/2)
  end
end

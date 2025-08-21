defmodule CodeMySpec.Tests.TestResult do
  alias CodeMySpec.Tests.TestError
  use Ecto.Schema

  @type result_status :: :passed | :failed
  @type t :: %__MODULE__{
          title: String.t(),
          full_title: String.t(),
          status: result_status(),
          error: TestError.t() | nil
        }

  @primary_key false
  embedded_schema do
    field :title, :string
    field :full_title, :string
    field :status, Ecto.Enum, values: [:passed, :failed]
    embeds_one :error, TestError
  end
end

defmodule CodeMySpec.Tests.TestError do
  use Ecto.Schema

  @type t :: %__MODULE__{
          file: String.t() | nil,
          line: non_neg_integer() | nil,
          message: String.t()
        }

  @primary_key false
  embedded_schema do
    field :file, :string
    field :line, :integer
    field :message, :string
  end
end

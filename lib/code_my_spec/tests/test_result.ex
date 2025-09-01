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

  def changeset(test_result \\ %__MODULE__{}, attrs) do
    test_result
    |> Ecto.Changeset.cast(attrs, [:title, :full_title, :status])
    |> Ecto.Changeset.cast_embed(:error, with: &TestError.changeset/2)
    |> map_json_fields(attrs)
  end

  defp map_json_fields(changeset, attrs) do
    changeset
    |> maybe_put_field(:title, attrs["title"])
    |> maybe_put_field(:full_title, attrs["fullTitle"]) 
    |> maybe_put_status(attrs["status"])
  end

  defp maybe_put_field(changeset, field, nil), do: changeset
  defp maybe_put_field(changeset, field, value) do
    Ecto.Changeset.put_change(changeset, field, value)
  end

  defp maybe_put_status(changeset, nil), do: changeset
  defp maybe_put_status(changeset, status) when status in ["passed", "failed"] do
    Ecto.Changeset.put_change(changeset, :status, String.to_atom(status))
  end
  defp maybe_put_status(changeset, _), do: changeset
end

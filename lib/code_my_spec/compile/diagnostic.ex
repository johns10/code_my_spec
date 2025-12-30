defmodule CodeMySpec.Compile.Diagnostic do
  @moduledoc """
  Embedded schema for compiler diagnostic messages.

  Matches the structure returned by mix compile in raw format.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :file, :string
    field :source, :string
    field :severity, Ecto.Enum, values: [:error, :warning, :information, :hint]
    field :message, :string
    field :position, :map
    field :compiler_name, :string
    field :span, :map
    field :details, :string
    field :stacktrace, {:array, :map}
  end

  @doc """
  Creates a changeset for a diagnostic from raw compiler output.

  ## Examples

      iex> changeset(%{
      ...>   "file" => "lib/foo.ex",
      ...>   "severity" => "error",
      ...>   "message" => "undefined function"
      ...> })
      %Ecto.Changeset{valid?: true}
  """
  def changeset(diagnostic \\ %__MODULE__{}, attrs) do
    diagnostic
    |> cast(attrs, [
      :file,
      :source,
      :severity,
      :message,
      :position,
      :compiler_name,
      :span,
      :details,
      :stacktrace
    ])
    |> validate_required([:severity, :message])
  end

  @doc """
  Parses a list of diagnostic maps into structs.

  Returns {:ok, diagnostics} if all are valid, {:error, reason} otherwise.
  """
  def parse_list(diagnostics) when is_list(diagnostics) do
    results =
      Enum.map(diagnostics, fn diagnostic_attrs ->
        changeset(%__MODULE__{}, diagnostic_attrs)
        |> apply_action(:insert)
      end)

    case Enum.find(results, fn result -> match?({:error, _}, result) end) do
      nil ->
        {:ok, Enum.map(results, fn {:ok, diag} -> diag end)}

      {:error, changeset} ->
        {:error, "Invalid diagnostic: #{inspect(changeset.errors)}"}
    end
  end

  def parse_list(_), do: {:error, "Diagnostics must be a list"}

  @doc """
  Parses JSON compiler output into diagnostic structs.
  """
  def parse_json(json) when is_binary(json) do
    case Jason.decode(json) do
      {:ok, diagnostics} when is_list(diagnostics) ->
        parse_list(diagnostics)

      {:ok, _} ->
        {:error, "JSON must contain an array of diagnostics"}

      {:error, error} ->
        {:error, "Failed to parse JSON: #{inspect(error)}"}
    end
  end

  @doc """
  Checks if a diagnostic is an error.
  """
  def error?(%__MODULE__{severity: :error}), do: true
  def error?(_), do: false

  @doc """
  Checks if a diagnostic is a warning.
  """
  def warning?(%__MODULE__{severity: :warning}), do: true
  def warning?(_), do: false

  @doc """
  Filters diagnostics by severity.
  """
  def filter_by_severity(diagnostics, severity) do
    Enum.filter(diagnostics, fn diag -> diag.severity == severity end)
  end

  @doc """
  Formats a single diagnostic as a human-readable string.

  ## Examples

      iex> diagnostic = %Diagnostic{
      ...>   file: "lib/foo.ex",
      ...>   severity: :error,
      ...>   message: "undefined function",
      ...>   position: %{line: 42}
      ...> }
      iex> format(diagnostic)
      "lib/foo.ex:42: undefined function"
  """
  def format(%__MODULE__{} = diagnostic) do
    file = diagnostic.file || "unknown"

    line =
      case diagnostic.position do
        %{line: l} when is_integer(l) -> l
        %{"line" => l} when is_integer(l) -> l
        l when is_integer(l) -> l
        _ -> "?"
      end

    message = diagnostic.message || "unknown error"

    "#{file}:#{line}: #{message}"
  end

  @doc """
  Formats a list of diagnostics with a prefix.

  ## Examples

      iex> diagnostics = [
      ...>   %Diagnostic{file: "lib/foo.ex", severity: :error, message: "error 1", position: 1},
      ...>   %Diagnostic{file: "lib/bar.ex", severity: :error, message: "error 2", position: 2}
      ...> ]
      iex> format_list("Compilation Error", diagnostics)
      [
        "Compilation Error (lib/foo.ex:1): error 1",
        "Compilation Error (lib/bar.ex:2): error 2"
      ]
  """
  def format_list(prefix, diagnostics) when is_list(diagnostics) do
    Enum.map(diagnostics, fn diagnostic ->
      formatted = format(diagnostic)
      "#{prefix} (#{formatted})"
    end)
  end
end

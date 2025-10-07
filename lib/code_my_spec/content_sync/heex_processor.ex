defmodule CodeMySpec.ContentSync.HeexProcessor do
  @moduledoc """
  Validates HEEx (HTML+EEx) template syntax without rendering.

  Uses `EEx.compile_string/1` with `Phoenix.LiveView.HTMLEngine` to validate
  HEEx templates. Stores raw templates in `raw_content` and leaves
  `processed_content` as `nil` since HEEx templates are rendered at request
  time with assigns, not during sync.

  ## Usage

      iex> HeexProcessor.process("<div><%= @name %></div>")
      {:ok, %ProcessorResult{
        raw_content: "<div><%= @name %></div>",
        processed_content: nil,
        parse_status: :success,
        parse_errors: nil
      }}

      iex> HeexProcessor.process("<div><%= @name</div>")
      {:ok, %ProcessorResult{
        raw_content: "<div><%= @name</div>",
        processed_content: nil,
        parse_status: :error,
        parse_errors: %{
          error_type: "EEx.SyntaxError",
          message: "...",
          line: 1,
          column: nil
        }
      }}

  ## Important Notes

  - HEEx templates are validated but never rendered
  - `processed_content` is always `nil`
  - All errors are captured in the result, not returned as error tuples
  - Missing assigns are not errors (rendering happens later with actual assigns)
  """

  alias CodeMySpec.ContentSync.ProcessorResult

  @type result :: ProcessorResult.t()

  @doc """
  Validates HEEx template syntax without rendering.

  Attempts to compile the HEEx template using Phoenix.LiveView.HTMLEngine.
  If compilation succeeds, returns success result with raw content.
  If compilation fails, returns success tuple with error details embedded.

  ## Parameters

    - `raw_heex` - The HEEx template string to validate

  ## Returns

    Always returns `{:ok, ProcessorResult.t()}` where:
    - `parse_status` is `:success` or `:error`
    - `raw_content` contains the original template
    - `processed_content` is always `nil`
    - `parse_errors` contains error details if validation failed

  ## Examples

      # Valid template
      iex> HeexProcessor.process("<div>Hello</div>")
      {:ok, %ProcessorResult{parse_status: :success, ...}}

      # Invalid template
      iex> HeexProcessor.process("<div>")
      {:ok, %ProcessorResult{parse_status: :error, ...}}
  """
  @spec process(raw_heex :: String.t()) :: {:ok, result()}
  def process(raw_heex) do
    result =
      try do
        EEx.compile_string(raw_heex,
          engine: Phoenix.LiveView.TagEngine,
          tag_handler: Phoenix.LiveView.HTMLEngine,
          file: "nofile",
          line: 1,
          caller: __ENV__,
          source: raw_heex,
          trim: false
        )

        ProcessorResult.success(raw_heex, nil)
      rescue
        e in EEx.SyntaxError ->
          ProcessorResult.error(raw_heex, %{
            error_type: "EEx.SyntaxError",
            message: Exception.message(e),
            line: Map.get(e, :line),
            column: Map.get(e, :column)
          })

        e in Phoenix.LiveView.Tokenizer.ParseError ->
          ProcessorResult.error(raw_heex, %{
            error_type: "Phoenix.LiveView.Tokenizer.ParseError",
            message: Exception.message(e),
            line: Map.get(e, :line),
            column: Map.get(e, :column)
          })

        e ->
          ProcessorResult.error(raw_heex, %{
            error_type: e.__struct__ |> to_string() |> String.trim_leading("Elixir."),
            message: Exception.message(e),
            line: Map.get(e, :line),
            column: Map.get(e, :column)
          })
      end

    {:ok, result}
  end
end
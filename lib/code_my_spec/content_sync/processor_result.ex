defmodule CodeMySpec.ContentSync.ProcessorResult do
  @moduledoc """
  Shared result structure for all content processors.

  Contains raw and processed content along with parsing status and error details.
  Used by MarkdownProcessor and HtmlProcessor to return consistent results to the sync pipeline.

  ## Fields

    - `raw_content` - The original unprocessed content string
    - `processed_content` - The processed content (HTML for markdown/html)
    - `parse_status` - Either `:success` or `:error`
    - `parse_errors` - Map containing error details when parse_status is `:error`, nil otherwise

  ## Examples

      iex> %ProcessorResult{
      ...>   raw_content: "# Hello",
      ...>   processed_content: "<h1>Hello</h1>",
      ...>   parse_status: :success,
      ...>   parse_errors: nil
      ...> }

      iex> %ProcessorResult{
      ...>   raw_content: "<script>alert('xss')</script>",
      ...>   processed_content: nil,
      ...>   parse_status: :error,
      ...>   parse_errors: %{
      ...>     error_type: "DisallowedContent",
      ...>     message: "HTML contains disallowed JavaScript content",
      ...>     violations: [...]
      ...>   }
      ...> }
  """

  @type parse_status :: :success | :error

  @type parse_errors :: %{
          optional(:violations) => [violation()],
          optional(:line) => integer(),
          optional(:context) => any(),
          error_type: String.t(),
          message: String.t(),
          details: any()
        }

  @type violation :: %{
          optional(:attribute) => String.t(),
          optional(:line) => integer(),
          type: String.t(),
          element: String.t()
        }

  @type t :: %__MODULE__{
          raw_content: String.t(),
          processed_content: String.t() | nil,
          parse_status: parse_status(),
          parse_errors: parse_errors() | nil
        }

  @enforce_keys [:raw_content, :parse_status]
  defstruct [
    :raw_content,
    :processed_content,
    :parse_status,
    :parse_errors
  ]

  @doc """
  Creates a new ProcessorResult for successful processing.

  ## Parameters

    - `raw_content` - The original content string
    - `processed_content` - The processed content

  ## Returns

    A ProcessorResult struct with parse_status: :success

  ## Examples

      iex> ProcessorResult.success("# Hello", "<h1>Hello</h1>")
      %ProcessorResult{
        raw_content: "# Hello",
        processed_content: "<h1>Hello</h1>",
        parse_status: :success,
        parse_errors: nil
      }
  """
  def success(raw_content, processed_content) do
    %__MODULE__{
      raw_content: raw_content,
      processed_content: processed_content,
      parse_status: :success,
      parse_errors: nil
    }
  end

  @doc """
  Creates a new ProcessorResult for failed processing.

  ## Parameters

    - `raw_content` - The original content string
    - `parse_errors` - Map containing error details

  ## Returns

    A ProcessorResult struct with parse_status: :error and processed_content: nil

  ## Examples

      iex> ProcessorResult.error("bad markdown", %{
      ...>   error_type: "ParseError",
      ...>   message: "Invalid syntax"
      ...> })
      %ProcessorResult{
        raw_content: "bad markdown",
        processed_content: nil,
        parse_status: :error,
        parse_errors: %{error_type: "ParseError", message: "Invalid syntax"}
      }
  """
  def error(raw_content, parse_errors) do
    %__MODULE__{
      raw_content: raw_content,
      processed_content: nil,
      parse_status: :error,
      parse_errors: parse_errors
    }
  end
end

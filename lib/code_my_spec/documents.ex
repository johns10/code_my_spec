defmodule CodeMySpec.Documents do
  @moduledoc """
  Context for managing document creation from markdown content.
  """

  alias CodeMySpec.Documents.{ContextDesign, ContextDesignParser, MarkdownParser}

  @doc """
  Creates a context design document with full Ecto validation.

  ## Parameters
  - `markdown_content` - The markdown string to parse
  - `scope` - Scope for validating component references

  Returns `{:ok, %ContextDesign{}}` on success or `{:error, changeset}` on failure.
  """
  def create_context_document(markdown_content) do
    with {:ok, attrs} <- ContextDesignParser.from_markdown(markdown_content),
         changeset <- ContextDesign.changeset(%ContextDesign{}, attrs),
         {:ok, document} <- apply_changeset(changeset) do
      {:ok, document}
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        {:error, changeset}

      {:error, reason, _warnings} ->
        {:error, create_error_changeset(reason)}
    end
  end

  @doc """
  Creates a document by validating sections against provided requirements.

  ## Parameters
  - `markdown_content` - The markdown string to parse
  - `required_sections` - List of required section names (e.g., ["purpose", "fields"])
  - `opts` - Optional keyword list
    - `:type` - Component type atom to include in result (default: nil)

  Returns `{:ok, document}` with sections map or `{:error, reason}` on failure.
  """
  def create_dynamic_document(markdown_content, required_sections, opts \\ []) do
    with {:ok, sections} <- MarkdownParser.parse(markdown_content),
         :ok <- validate_required_sections(sections, required_sections) do
      document = %{sections: sections}

      document =
        case Keyword.get(opts, :type) do
          nil -> document
          type -> Map.put(document, :type, type)
        end

      {:ok, document}
    end
  end

  defp validate_required_sections(sections, required_sections) do
    missing =
      required_sections
      |> Enum.reject(fn section -> Map.has_key?(sections, section) end)

    if Enum.empty?(missing) do
      :ok
    else
      {:error, "Missing required sections: #{Enum.join(missing, ", ")}"}
    end
  end

  defp apply_changeset(%Ecto.Changeset{valid?: true} = changeset) do
    data = Ecto.Changeset.apply_changes(changeset)
    {:ok, data}
  end

  defp apply_changeset(%Ecto.Changeset{valid?: false} = changeset) do
    {:error, changeset}
  end

  defp create_error_changeset(message) do
    %Ecto.Changeset{
      data: %{},
      errors: [document: {message, []}],
      valid?: false
    }
  end
end

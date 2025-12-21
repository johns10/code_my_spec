defmodule CodeMySpec.Documents do
  @moduledoc """
  Context for managing document creation from markdown content.
  """

  alias CodeMySpec.Documents.{ContextDesign, ContextDesignParser, MarkdownParser}

  @doc """
  Creates a document by validating sections against document type definition.

  ## Parameters
  - `markdown_content` - The markdown string to parse
  - `document_type` - Document type atom (e.g., :context, :schema, :spec) to look up definition

  Returns `{:ok, document}` with sections map and type or `{:error, reason}` on failure.
  """
  def create_dynamic_document(markdown_content, document_type) do
    doc_def = CodeMySpec.Documents.Registry.get_definition(document_type)

    with {:ok, sections} <- MarkdownParser.parse(markdown_content),
         :ok <- validate_required_sections(sections, doc_def.required_sections),
         :ok <-
           validate_additional_sections(
             sections,
             doc_def.required_sections,
             doc_def.optional_sections,
             doc_def.allowed_additional_sections
           ) do
      {:ok, %{sections: sections, type: document_type}}
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

  defp validate_additional_sections(_sections, _required, _optional, "*"), do: :ok

  defp validate_additional_sections(
         sections,
         required_sections,
         optional_sections,
         allowed_additional
       ) do
    allowed_sections = MapSet.new(required_sections ++ optional_sections ++ allowed_additional)
    actual_sections = MapSet.new(Map.keys(sections))
    disallowed = MapSet.difference(actual_sections, allowed_sections)

    if MapSet.size(disallowed) == 0 do
      :ok
    else
      disallowed_list = MapSet.to_list(disallowed) |> Enum.sort()
      {:error, "Disallowed sections found: #{Enum.join(disallowed_list, ", ")}"}
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

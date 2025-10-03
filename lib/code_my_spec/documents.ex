defmodule CodeMySpec.Documents do
  @moduledoc """
  Context for managing document creation from markdown content.
  """

  alias CodeMySpec.Documents.{ComponentDesign, ContextDesign, SchemaComponentDesign}

  # Central mapping from component type to document module
  @component_type_to_document %{
    context: ContextDesign,
    coordination_context: ContextDesign,
    schema: SchemaComponentDesign
  }

  @default_document_module ComponentDesign

  @doc """
  Creates a document from markdown content based on the component type.

  ## Parameters
  - `markdown_content` - The markdown string to parse
  - `component_type` - Component type atom (`:context`, `:schema`, etc)
  - `scope` - Optional scope for validation (default: nil)

  Returns `{:ok, document}` on success or `{:error, changeset}` on failure.
  """
  def create_component_document(markdown_content, component_type, scope \\ nil) do
    document_module = get_document_module_for_component_type(component_type)

    with {:ok, parser_module} <- get_parser_for_type(document_module),
         {:ok, attrs} <- parser_module.from_markdown(markdown_content),
         empty_document <- create_empty_document(document_module),
         changeset <- document_module.changeset(empty_document, attrs, scope),
         {:ok, document} <- apply_changeset(changeset) do
      {:ok, document}
    else
      {:error, reason} when is_binary(reason) ->
        {:error, create_error_changeset(reason)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Determines the appropriate document module for a component type.
  This is the central source of truth for component type → document type mapping.
  """
  def get_document_module_for_component_type(component_type) when is_atom(component_type) do
    Map.get(@component_type_to_document, component_type, @default_document_module)
  end

  defp get_parser_for_type(document_module) do
    # Convention: parser module is document module name + "Parser"
    # e.g., CodeMySpec.Documents.ContextDesign -> CodeMySpec.Documents.ContextDesignParser
    module_parts = Module.split(document_module)
    [last_part | reversed_parent_parts] = Enum.reverse(module_parts)
    parent_parts = Enum.reverse(reversed_parent_parts)
    parser_module_name = Module.concat(parent_parts ++ [last_part <> "Parser"])

    if Code.ensure_loaded?(parser_module_name) do
      {:ok, parser_module_name}
    else
      {:error, "No parser available for document type: #{inspect(document_module)}"}
    end
  end

  defp create_empty_document(document_module) do
    struct(document_module)
  end

  defp apply_changeset(%Ecto.Changeset{valid?: true} = changeset) do
    # For embedded schemas, we just return the changes as a struct
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

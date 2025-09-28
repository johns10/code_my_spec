defmodule CodeMySpec.Documents do
  @moduledoc """
  Context for managing document creation from markdown content.
  """

  alias CodeMySpec.Documents.{ComponentDesign, ContextDesign}
  alias CodeMySpec.Documents.{ComponentDesignParser, ContextDesignParser}

  @doc """
  Creates a document from markdown content based on the document type.

  ## Parameters
  - `markdown_content` - The markdown string to parse
  - `type` - Document type atom (`:context_design`) or module name
  - `scope` - Optional scope for validation (default: nil)

  Returns `{:ok, document}` on success or `{:error, changeset}` on failure.
  """
  def create_document(markdown_content, type, scope \\ nil) do
    with {:ok, document_module} <- resolve_document_type(type),
         {:ok, parser_module} <- get_parser_for_type(document_module),
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
  Lists all supported document types.
  """
  def supported_types do
    [
      :context_design,
      :component_design
    ]
  end

  @doc """
  Gets the document module for a given type.
  """
  def get_document_module(:context_design), do: {:ok, ContextDesign}
  def get_document_module(:repository), do: {:ok, ComponentDesign}
  def get_document_module(:component_design), do: {:ok, ComponentDesign}

  def get_document_module(module) when is_atom(module) do
    if Code.ensure_loaded?(module) do
      {:ok, module}
    else
      {:error, "Unknown document module: #{inspect(module)}"}
    end
  end

  def get_document_module(type), do: {:error, "Invalid document type: #{inspect(type)}"}

  defp resolve_document_type(type) when is_atom(type) do
    case type do
      :context_design ->
        {:ok, ContextDesign}

      :component_design ->
        {:ok, ComponentDesign}

      module when is_atom(module) ->
        if Code.ensure_loaded?(module) do
          {:ok, module}
        else
          {:error, "Unknown document module: #{inspect(module)}"}
        end
    end
  end

  defp get_parser_for_type(ContextDesign), do: {:ok, ContextDesignParser}
  defp get_parser_for_type(ComponentDesign), do: {:ok, ComponentDesignParser}

  defp get_parser_for_type(module),
    do: {:error, "No parser available for document type: #{inspect(module)}"}

  defp create_empty_document(ContextDesign), do: %ContextDesign{}
  defp create_empty_document(ComponentDesign), do: %ComponentDesign{}

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

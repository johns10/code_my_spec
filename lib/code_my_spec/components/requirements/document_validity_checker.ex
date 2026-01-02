defmodule CodeMySpec.Components.Requirements.DocumentValidityChecker do
  @moduledoc """
  Validates that a document file contains valid content according to its document type definition.
  Uses CodeMySpec.Documents.create_dynamic_document/2 to validate the document structure.
  """

  @behaviour CodeMySpec.Components.Requirements.CheckerBehaviour
  alias CodeMySpec.Components.Component
  alias CodeMySpec.Documents
  alias CodeMySpec.Utils

  @doc """
  Checks if a document file exists and contains valid content.

  The requirement_spec must include a `document_type` field specifying which
  document type to validate against (e.g., "context", "context_spec", "schema", "spec").

  ## Examples

      requirement_spec = %{
        name: :spec_valid,
        checker: DocumentValidityChecker,
        satisfied_by: "ContextSpecSessions",
        document_type: "context_spec"
      }
  """
  def check(requirement_spec, component, opts \\ [])

  def check(
        %{name: name, document_type: document_type} = requirement_spec,
        %Component{} = component,
        opts
      ) do
    {satisfied, details} = validate_document(component, document_type, opts)

    %{
      name: Atom.to_string(name),
      type: :document_validity,
      description: generate_description(document_type),
      checker_module: Atom.to_string(requirement_spec.checker),
      satisfied_by: requirement_spec.satisfied_by,
      satisfied: satisfied,
      checked_at: DateTime.utc_now(),
      details: details
    }
  end

  # Handle case where document_type is not specified in requirement_spec
  def check(%{name: name} = requirement_spec, %Component{}, _opts) do
    %{
      name: Atom.to_string(name),
      type: :document_validity,
      description: "Document validity check (document_type not specified)",
      checker_module: Atom.to_string(requirement_spec.checker),
      satisfied_by: requirement_spec.satisfied_by,
      satisfied: false,
      checked_at: DateTime.utc_now(),
      details: %{reason: "document_type not specified in requirement"}
    }
  end

  defp validate_document(%Component{module_name: module_name} = _component, document_type, opts) do
    files = Utils.component_files(module_name)
    spec_path = Map.get(files, :spec_file)

    # If cwd is provided, prepend it to the spec_path
    full_spec_path =
      case Keyword.get(opts, :cwd) do
        nil -> spec_path
        cwd -> Path.join(cwd, spec_path)
      end

    case File.read(full_spec_path) do
      {:ok, content} ->
        case Documents.create_dynamic_document(content, document_type) do
          {:ok, _document} ->
            {true, %{status: "Document is valid", document_type: document_type}}

          {:error, error_message} ->
            {false,
             %{
               reason: "Document validation failed",
               error: error_message,
               document_type: document_type
             }}
        end

      {:error, reason} ->
        {false, %{reason: "Failed to read spec file: #{inspect(reason)}"}}
    end
  end

  defp generate_description(document_type) do
    "Document is valid #{document_type} specification"
  end
end

defmodule CodeMySpec.Documents.DocumentSpecProjector do
  @moduledoc """
  Projects document behaviour implementations into markdown specifications.
  """

  @doc """
  Generates a markdown specification for a document module.
  """
  def project_spec(document_module) do
    module_name = module_name(document_module)
    overview = document_module.overview()
    required_fields = document_module.required_fields()
    field_descriptions = document_module.field_descriptions()

    all_fields = Map.keys(field_descriptions)
    optional_fields = all_fields -- required_fields

    """
    # #{module_name}

    #{overview}

    ## Required Sections

    #{format_fields(required_fields, field_descriptions)}

    ## Optional Sections

    #{format_optional_sections(optional_fields, field_descriptions)}
    """
  end

  defp module_name(module) do
    module
    |> Module.split()
    |> List.last()
    |> Macro.underscore()
    |> String.split("_")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  defp format_fields(fields, descriptions) do
    fields
    |> Enum.map(fn field ->
      description = Map.get(descriptions, field, "No description available")
      "### #{format_field_name(field)}\n\n#{description}"
    end)
    |> Enum.join("\n\n")
  end

  defp format_optional_sections([], _descriptions) do
    "None"
  end

  defp format_optional_sections(fields, descriptions) do
    format_fields(fields, descriptions)
  end

  defp format_field_name(field) do
    field
    |> Atom.to_string()
    |> String.split("_")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end
end
defmodule CodeMySpec.Documents.ContextDesignParser do
  @moduledoc """
  Parses markdown content into ContextDesign changeset attributes.
  Uses Earmark to parse markdown structure and yaml_elixir for YAML blocks.
  """

  @known_sections [
    "purpose",
    "entity ownership", 
    "scope integration",
    "public api",
    "state management strategy",
    "components",
    "dependencies", 
    "execution flow"
  ]

  def from_markdown(markdown_content) do
    with sections <- extract_sections_from_markdown(markdown_content),
         sections <- parse_known_sections(sections),
         {:ok, sections} <- parse_yaml_sections(sections) do
      {:ok, build_changeset_attrs(sections)}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp extract_sections_from_markdown(content) do
    # Split by ## headers to get all sections including Purpose
    parts = String.split(content, ~r/\n## /)
    
    case parts do
      [first_part | section_parts] ->
        # Parse all sections from the split parts
        all_sections = section_parts
        |> Enum.map(&parse_section/1)
        |> Map.new()
        
        # If there's no explicit Purpose section, extract from first part
        if Map.has_key?(all_sections, "purpose") do
          all_sections
        else
          purpose = extract_purpose_from_first_part(first_part)
          Map.put(all_sections, "purpose", purpose)
        end
      
      [] -> %{}
    end
  end

  defp extract_purpose_from_first_part(first_part) do
    # Skip the title line and get remaining content as purpose
    lines = String.split(first_part, "\n")
    case lines do
      [_title | purpose_lines] ->
        purpose_lines
        |> Enum.join("\n")
        |> String.trim()
      [] -> ""
    end
  end

  defp parse_section(section_text) do
    case String.split(section_text, "\n", parts: 2) do
      [header, content] ->
        key = String.downcase(String.trim(header))
        {key, String.trim(content)}
      [header] ->
        key = String.downcase(String.trim(header))
        {key, ""}
    end
  end

  defp parse_known_sections(sections) do
    known = Map.take(sections, @known_sections)
    unknown = Map.drop(sections, @known_sections)
    
    Map.put(known, :other_sections, unknown)
  end

  defp parse_yaml_sections(sections) do
    with {:ok, components} <- parse_components_yaml(Map.get(sections, "components", "")),
         {:ok, dependencies} <- parse_dependencies_yaml(Map.get(sections, "dependencies", "")) do
      {:ok, sections
      |> Map.put(:parsed_components, components)
      |> Map.put(:parsed_dependencies, dependencies)}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp parse_components_yaml(text) do
    case parse_yaml_section(text) do
      {:ok, result} -> {:ok, result}
      {:error, reason} -> {:error, "Components section error: #{reason}"}
    end
  end

  defp parse_dependencies_yaml(text) do
    case parse_yaml_section(text) do
      {:ok, result} -> {:ok, result}
      {:error, reason} -> {:error, "Dependencies section error: #{reason}"}
    end
  end

  defp parse_yaml_section(""), do: {:ok, []}
  defp parse_yaml_section(text) do
    case YamlElixir.read_from_string(text) do
      {:ok, yaml_data} -> normalize_yaml_items(yaml_data)
      {:error, reason} -> {:error, "YAML parsing failed: #{inspect(reason)}"}
    end
  end

  defp normalize_yaml_items(yaml_list) when is_list(yaml_list) do
    results = Enum.map(yaml_list, &normalize_yaml_item/1)
    
    case Enum.find(results, &match?({:error, _}, &1)) do
      {:error, reason} -> {:error, reason}
      nil -> 
        valid_items = Enum.map(results, fn {:ok, item} -> item end)
        {:ok, valid_items}
    end
  end
  defp normalize_yaml_items(_), do: {:error, "Expected a YAML list"}

  defp normalize_yaml_item(item) when is_map(item) do
    # YAML structure: %{"RuleSchema" => %{"module_name" => "...", "description" => "..."}}
    case Map.to_list(item) do
      [{name, properties}] when is_map(properties) ->
        # Extract properties from nested map
        module_name = Map.get(properties, "module_name", name)
        description = Map.get(properties, "description")
        
        cond do
          is_nil(description) or String.trim(description) == "" ->
            {:error, "description is required for item: #{name}"}
          String.trim(module_name) == "" ->
            {:error, "module_name is required for item: #{name}"}
          true ->
            result = %{module_name: module_name, description: description}
            
            # Add extra fields as atoms (excluding module_name, description)
            extra_fields = properties
            |> Map.drop(["module_name", "description"])
            |> Enum.into(%{}, fn {k, v} -> {String.to_atom(k), v} end)
            
            {:ok, Map.merge(result, extra_fields)}
        end
        
      _ ->
        {:error, "Expected YAML item to have format 'Name: {properties}', got: #{inspect(item)}"}
    end
  end
  defp normalize_yaml_item(item), do: {:error, "Expected YAML item to be a map, got: #{inspect(item)}"}

  defp build_changeset_attrs(sections) do
    %{
      purpose: Map.get(sections, "purpose", ""),
      entity_ownership: Map.get(sections, "entity ownership", ""),
      scope_integration: Map.get(sections, "scope integration", ""),
      public_api: Map.get(sections, "public api", ""),
      state_management_strategy: Map.get(sections, "state management strategy", ""),
      execution_flow: Map.get(sections, "execution flow", ""),
      components: Map.get(sections, :parsed_components, []),
      dependencies: Map.get(sections, :parsed_dependencies, []),
      other_sections: Map.get(sections, :other_sections, %{})
    }
  end
end
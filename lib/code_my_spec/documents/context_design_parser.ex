defmodule CodeMySpec.Documents.ContextDesignParser do
  @moduledoc """
  Parses markdown content into ContextDesign changeset attributes using Earmark.
  """

  def from_markdown(markdown_content) do
    case Earmark.Parser.as_ast(markdown_content) do
      {:ok, ast, _} ->
        sections = parse_ast(ast)
        {:ok, build_changeset_attrs(sections)}

      {:error, _, _} = error ->
        error
    end
  end

  defp parse_ast(ast) do
    sections = group_sections(ast)

    %{
      purpose: extract_text(sections["purpose"] || []),
      entity_ownership: extract_text(sections["entity ownership"] || []),
      scope_integration: extract_text(sections["scope integration"] || []),
      public_api: extract_text(sections["public api"] || []),
      state_management_strategy: extract_text(sections["state management strategy"] || []),
      execution_flow: extract_text(sections["execution flow"] || []),
      components: parse_components(sections["components"] || []),
      dependencies: parse_dependencies(sections["dependencies"] || []),
      other_sections: build_other_sections(sections)
    }
  end

  defp group_sections(ast) do
    {sections, current} =
      ast
      |> Enum.reduce({%{}, nil}, fn
        {"h1", [], [_title], %{}}, {sections, current} ->
          # Skip H1, finalize previous section if any
          updated_sections = if current, do: finalize_section(sections, current), else: sections
          {updated_sections, nil}

        {"h2", [], [title], %{}}, {sections, current} ->
          key = String.downcase(String.trim(title))
          updated_sections = if current, do: finalize_section(sections, current), else: sections
          {updated_sections, {key, []}}

        _element, {sections, nil} ->
          {sections, nil}

        element, {sections, {key, content}} ->
          {sections, {key, [element | content]}}
      end)

    # Finalize the last section
    if current, do: finalize_section(sections, current), else: sections
  end

  defp finalize_section(sections, {key, content}) do
    Map.put(sections, key, Enum.reverse(content))
  end

  defp parse_components(ast) do
    ast
    |> group_by_h3()
    |> Enum.map(fn {module_name, content} ->
      {table, description} = extract_table_and_text(content)
      %{module_name: module_name, table: table, description: description}
    end)
  end

  defp parse_dependencies(ast) do
    extract_list_items(ast)
  end

  defp group_by_h3(ast) do
    ast
    |> Enum.reduce({[], nil}, fn
      {"h3", [], [title], %{}}, {components, current} ->
        module_name = String.trim(title)
        new_components = if current, do: [current | components], else: components
        {new_components, {module_name, []}}

      _element, {components, nil} ->
        {components, nil}

      element, {components, {name, content}} ->
        {components, {name, [element | content]}}
    end)
    |> case do
      {components, nil} -> Enum.reverse(components)
      {components, current} -> Enum.reverse([current | components])
    end
    |> Enum.map(fn {name, content} -> {name, Enum.reverse(content)} end)
  end

  defp extract_table_and_text(ast) do
    table = Enum.find(ast, &match?({"table", _, _, _}, &1))
    text_elements = Enum.reject(ast, &match?({"table", _, _, _}, &1))

    table_data = if table, do: parse_table_to_map(table), else: nil
    description = extract_text(text_elements)

    {table_data, description}
  end

  defp parse_table_to_map({"table", [], table_parts, %{}}) do
    # Extract thead and tbody from table structure
    headers = extract_headers(table_parts)
    data_rows = extract_data_rows(table_parts)

    case data_rows do
      [single_row] ->
        # Single data row - return as map
        Enum.zip(headers, single_row) |> Map.new()

      multiple_rows when length(multiple_rows) > 1 ->
        # Multiple data rows - return as list of maps
        multiple_rows
        |> Enum.map(fn row ->
          Enum.zip(headers, row) |> Map.new()
        end)

      [] ->
        %{}
    end
  end

  defp extract_headers(table_parts) do
    case Enum.find(table_parts, &match?({"thead", _, _, _}, &1)) do
      {"thead", [], [{"tr", [], cells, %{}}], %{}} ->
        Enum.map(cells, fn
          {"th", _attrs, content, %{}} -> extract_text(content) |> String.trim()
        end)

      _ ->
        []
    end
  end

  defp extract_data_rows(table_parts) do
    case Enum.find(table_parts, &match?({"tbody", _, _, _}, &1)) do
      {"tbody", [], rows, %{}} ->
        Enum.map(rows, fn {"tr", [], cells, %{}} ->
          Enum.map(cells, fn
            {"td", _attrs, content, %{}} -> extract_text(content) |> String.trim()
          end)
        end)

      _ ->
        []
    end
  end

  defp extract_list_items(ast) do
    ast
    |> Enum.flat_map(fn
      {"ul", [], items, %{}} -> extract_li_content(items)
      {"ol", [], items, %{}} -> extract_li_content(items)
      _ -> []
    end)
  end

  defp extract_li_content(items) do
    Enum.map(items, fn
      {"li", [], content, %{}} -> extract_text(content)
      _ -> ""
    end)
    |> Enum.reject(&(&1 == ""))
  end

  defp extract_text(ast) when is_list(ast) do
    ast
    |> Enum.map_join(" ", &extract_text/1)
    |> String.trim()
  end

  defp extract_text(text) when is_binary(text), do: text
  defp extract_text({"ol", [], items, %{}}), do: format_ordered_list(items)
  defp extract_text({"ul", [], items, %{}}), do: format_unordered_list(items)
  defp extract_text({_tag, _attrs, content, %{}}), do: extract_text(content)
  defp extract_text(_), do: ""

  defp format_ordered_list(items) do
    items
    |> Enum.with_index(1)
    |> Enum.map_join("\n", fn {{"li", [], content, %{}}, index} ->
      "#{index}. #{extract_text(content)}"
    end)
  end

  defp format_unordered_list(items) do
    items
    |> Enum.map_join("\n", fn {"li", [], content, %{}} ->
      "- #{extract_text(content)}"
    end)
  end

  defp build_other_sections(sections) do
    known_keys = [
      "purpose",
      "entity ownership",
      "scope integration",
      "public api",
      "state management strategy",
      "execution flow",
      "components",
      "dependencies"
    ]

    sections
    |> Map.drop(known_keys)
    |> Enum.map(fn {key, content} -> {key, extract_text(content)} end)
    |> Map.new()
  end

  defp build_changeset_attrs(sections) do
    %{
      purpose: sections.purpose,
      entity_ownership: sections.entity_ownership,
      scope_integration: sections.scope_integration,
      public_api: sections.public_api,
      state_management_strategy: sections.state_management_strategy,
      execution_flow: sections.execution_flow,
      components: sections.components,
      dependencies: sections.dependencies,
      other_sections: sections.other_sections
    }
  end
end

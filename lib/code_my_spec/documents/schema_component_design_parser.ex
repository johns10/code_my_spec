defmodule CodeMySpec.Documents.SchemaComponentDesignParser do
  @moduledoc """
  Parses markdown content into SchemaComponentDesign changeset attributes using Earmark.
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
      fields: extract_text(sections["field documentation"] || sections["fields"] || []),
      associations: extract_text(sections["associations"] || []),
      validation_rules: extract_text(sections["validation rules"] || []),
      database_constraints: extract_text(sections["database constraints"] || []),
      other_sections: build_other_sections(sections)
    }
  end

  defp group_sections(ast) do
    {sections, current} =
      ast
      |> Enum.reduce({%{}, nil}, fn
        {"h1", [], [_title], %{}}, {sections, current} ->
          # H1 is document title, finalize previous section but don't start new one
          updated_sections = if current, do: finalize_section(sections, current), else: sections
          {updated_sections, nil}

        {"h2", [], [title], %{}}, {sections, current} ->
          # H2 defines sections
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

  defp extract_text(ast) when is_list(ast) do
    ast
    |> Enum.map_join(" ", &extract_text/1)
    |> String.trim()
  end

  defp extract_text(text) when is_binary(text), do: text
  defp extract_text({"ol", [], items, %{}}), do: format_ordered_list(items)
  defp extract_text({"ul", [], items, %{}}), do: format_unordered_list(items)
  defp extract_text({"table", [], content, %{}}), do: format_table(content)
  defp extract_text({_tag, _attrs, content, %{}}), do: extract_text(content)
  defp extract_text(_), do: ""

  defp format_ordered_list(items) do
    items
    |> Enum.with_index(1)
    |> Enum.map_join("\n", fn {item, index} ->
      case item do
        {"li", [], content, %{}} -> "#{index}. #{extract_text(content)}"
        {"p", [], content, %{}} -> "#{index}. #{extract_text(content)}"
        _ -> ""
      end
    end)
  end

  defp format_unordered_list(items) do
    items
    |> Enum.map_join("\n", fn item ->
      case item do
        {"li", [], content, %{}} -> "- #{extract_text(content)}"
        {"p", [], content, %{}} -> "- #{extract_text(content)}"
        _ -> ""
      end
    end)
  end

  defp format_table(content) do
    # Extract rows from table
    rows =
      content
      |> Enum.filter(fn
        {"tbody", _, _, %{}} -> true
        {"thead", _, _, %{}} -> true
        _ -> false
      end)
      |> Enum.flat_map(fn {_tag, _attrs, rows, %{}} -> rows end)

    rows
    |> Enum.map_join("\n", fn {"tr", _tr_attrs, cells, %{}} ->
      cells
      |> Enum.map_join(" | ", fn
        {"th", _th_attrs, cell_content, %{}} -> extract_text(cell_content)
        {"td", _td_attrs, cell_content, %{}} -> extract_text(cell_content)
      end)
    end)
  end

  defp build_other_sections(sections) do
    known_keys = [
      "purpose",
      "field documentation",
      "fields",
      "associations",
      "validation rules",
      "database constraints"
    ]

    sections
    |> Map.drop(known_keys)
    |> Enum.map(fn {key, content} -> {key, extract_text(content)} end)
    |> Map.new()
  end

  defp build_changeset_attrs(sections) do
    %{
      purpose: sections.purpose,
      fields: sections.fields,
      associations: sections.associations,
      validation_rules: sections.validation_rules,
      database_constraints: sections.database_constraints,
      other_sections: sections.other_sections
    }
  end
end

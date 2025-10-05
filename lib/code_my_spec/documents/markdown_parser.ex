defmodule CodeMySpec.Documents.MarkdownParser do
  @moduledoc """
  Generic markdown parser that extracts H2 sections into a map.
  """

  @doc """
  Parses markdown content into a map of section names to content.

  H2 headings become section keys (lowercased), and all content between
  H2 headings becomes the section value.

  ## Examples

      iex> markdown = \"\"\"
      ...> # Title
      ...> ## Purpose
      ...> This is the purpose.
      ...> ## Fields
      ...> Field list here.
      ...> \"\"\"
      iex> MarkdownParser.parse(markdown)
      {:ok, %{"purpose" => "This is the purpose.", "fields" => "Field list here."}}
  """
  def parse(markdown_content) do
    case Earmark.Parser.as_ast(markdown_content) do
      {:ok, ast, _} ->
        sections = extract_sections(ast)
        {:ok, sections}

      {:error, _, errors} ->
        {:error, "Failed to parse markdown: #{inspect(errors)}"}
    end
  end

  defp extract_sections(ast) do
    {sections, current} =
      ast
      |> Enum.reduce({%{}, nil}, fn
        {"h1", [], [_title], %{}}, {sections, current} ->
          # Skip H1, finalize previous section if any
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
    text = extract_text(Enum.reverse(content))
    Map.put(sections, key, text)
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
end

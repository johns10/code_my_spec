defmodule CodeMySpec.Documents.ComponentDesignParser do
  @moduledoc """
  Parses markdown content into ComponentDesign changeset attributes using Earmark.
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
      public_api: extract_text(sections["public api"] || []),
      execution_flow: extract_text(sections["execution flow"] || []),
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
    known_keys = ["purpose", "public api", "execution flow"]

    sections
    |> Map.drop(known_keys)
    |> Enum.map(fn {key, content} -> {key, extract_text(content)} end)
    |> Map.new()
  end

  defp build_changeset_attrs(sections) do
    %{
      purpose: sections.purpose,
      public_api: sections.public_api,
      execution_flow: sections.execution_flow,
      other_sections: sections.other_sections
    }
  end
end
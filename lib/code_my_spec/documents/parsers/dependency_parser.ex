defmodule CodeMySpec.Documents.Parsers.DependencyParser do
  @moduledoc """
  Parse Dependencies section AST into a list of module name strings.
  """

  @spec from_ast(list()) :: [String.t()]
  def from_ast(ast) do
    extract_list_items(ast)
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

  defp extract_text(content) when is_list(content) do
    content
    |> Enum.map_join(" ", &extract_text/1)
    |> String.trim()
  end

  defp extract_text(text) when is_binary(text), do: text
  defp extract_text({"strong", [], content, %{}}), do: extract_text(content)
  defp extract_text({"em", [], content, %{}}), do: extract_text(content)
  defp extract_text({"code", [], content, %{}}), do: extract_text(content)
  defp extract_text({_tag, _attrs, content, %{}}), do: extract_text(content)
  defp extract_text(_), do: ""
end

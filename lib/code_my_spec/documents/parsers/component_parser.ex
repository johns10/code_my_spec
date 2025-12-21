defmodule CodeMySpec.Documents.Parsers.ComponentParser do
  @moduledoc """
  Parse Components section AST into SpecComponent structs.
  Extracts module names (from H3 headings) and descriptions.
  """

  alias CodeMySpec.Documents.SpecComponent

  @spec from_ast(list()) :: [SpecComponent.t()]
  def from_ast(ast) do
    ast
    |> group_by_h3()
    |> Enum.map(&parse_component/1)
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

      element, {components, {module_name, content}} ->
        {components, {module_name, [element | content]}}
    end)
    |> case do
      {components, nil} -> Enum.reverse(components)
      {components, current} -> Enum.reverse([current | components])
    end
    |> Enum.map(fn {module_name, content} -> {module_name, Enum.reverse(content)} end)
  end

  defp parse_component({module_name, content}) do
    %{
      module_name: module_name,
      description: extract_description(content)
    }
    |> then(&Ecto.embedded_load(SpecComponent, &1, :json))
  end

  defp extract_description(content) do
    # Find first paragraph
    content
    |> Enum.find_value(fn
      {"p", [], text_content, %{}} ->
        extract_text(text_content)

      _ ->
        nil
    end) || ""
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
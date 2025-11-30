defmodule CodeMySpec.Specs.SpecParser do
  @moduledoc """
  Parse markdown AST into Spec embedded schema structs.
  """

  alias CodeMySpec.Specs.Spec
  alias CodeMySpec.Specs.FunctionParser
  alias CodeMySpec.Specs.FieldParser

  @spec parse(String.t()) :: {:ok, Spec.t()} | {:error, term()}
  def parse(file_path) when is_binary(file_path) do
    with {:ok, content} <- File.read(file_path),
         {:ok, ast, _} <- Earmark.Parser.as_ast(content),
         {:ok, module_name} <- extract_module_name(ast),
         sections <- group_sections(ast),
         type <- extract_type(ast),
         description <- extract_description(ast),
         delegates <- parse_delegates(sections["delegates"] || []),
         dependencies <- parse_dependencies(sections["dependencies"] || []),
         functions <- FunctionParser.from_ast(sections["functions"] || []),
         fields <- FieldParser.from_ast(sections["fields"] || []) do
      attrs = %{
        module_name: module_name,
        type: type,
        description: description,
        delegates: delegates,
        dependencies: dependencies,
        functions: functions,
        fields: fields
      }

      {:ok, Ecto.embedded_load(Spec, attrs, :json)}
    end
  end

  @spec from_markdown(String.t()) :: {:ok, Spec.t()} | {:error, String.t(), list()}
  def from_markdown(markdown_content) when is_binary(markdown_content) do
    case Earmark.Parser.as_ast(markdown_content) do
      {:ok, ast, _} when is_list(ast) -> from_ast(ast)
      {:error, msg, errors} -> {:error, msg, errors}
    end
  end

  @spec from_ast(list()) :: {:ok, Spec.t()} | {:error, term()}
  def from_ast(ast) when is_list(ast) do
    with {:ok, module_name} <- extract_module_name(ast),
         sections <- group_sections(ast),
         type <- extract_type(ast),
         description <- extract_description(ast),
         delegates <- parse_delegates(sections["delegates"] || []),
         dependencies <- parse_dependencies(sections["dependencies"] || []),
         functions <- FunctionParser.from_ast(sections["functions"] || []),
         fields <- FieldParser.from_ast(sections["fields"] || []) do
      attrs = %{
        module_name: module_name,
        type: type,
        description: description,
        delegates: delegates,
        dependencies: dependencies,
        functions: functions,
        fields: fields
      }

      {:ok, Ecto.embedded_load(Spec, attrs, :json)}
    end
  end

  defp extract_module_name(ast) do
    case Enum.find(ast, &match?({"h1", _, _, _}, &1)) do
      {"h1", [], [title], %{}} -> {:ok, String.trim(title)}
      _ -> {:error, :missing_h1_header}
    end
  end

  defp extract_type(ast) do
    # Find paragraph with **Type**: pattern after H1
    Enum.find_value(ast, fn
      {"p", [], content, %{}} ->
        extract_type_from_paragraph(content)

      _ ->
        nil
    end)
  end

  defp extract_type_from_paragraph(content) do
    content
    |> extract_text()
    |> then(fn text ->
      case Regex.run(~r/\*\*Type\*\*:\s*(.+)/, text) do
        [_, type] -> String.trim(type)
        _ -> nil
      end
    end)
  end

  defp extract_description(ast) do
    # Find content between H1 and first H2
    {description_parts, _} =
      ast
      |> Enum.reduce_while({[], :before_h1}, fn
        {"h1", _, _, _}, {_parts, :before_h1} ->
          {:cont, {[], :after_h1}}

        {"h2", _, _, _}, {parts, :after_h1} ->
          {:halt, {parts, :done}}

        {"p", [], content, %{}}, {parts, :after_h1} ->
          text = extract_text(content)

          # Skip the **Type**: line
          if String.contains?(text, "**Type**:") do
            {:cont, {parts, :after_h1}}
          else
            {:cont, {[text | parts], :after_h1}}
          end

        _element, acc ->
          {:cont, acc}
      end)

    description_parts
    |> Enum.reverse()
    |> Enum.join(" ")
    |> String.trim()
    |> case do
      "" -> nil
      text -> text
    end
  end

  defp group_sections(ast) do
    {sections, current} =
      ast
      |> Enum.reduce({%{}, nil}, fn
        {"h1", _, _, _}, {sections, current} ->
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

    if current, do: finalize_section(sections, current), else: sections
  end

  defp finalize_section(sections, {key, content}) do
    Map.put(sections, key, Enum.reverse(content))
  end

  defp parse_delegates(ast) do
    extract_list_items(ast)
  end

  defp parse_dependencies(ast) do
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
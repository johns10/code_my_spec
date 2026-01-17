defmodule CodeMySpec.Documents.Parsers.FunctionParser do
  @moduledoc """
  Parse Functions section AST into Function embedded schema structs.
  """

  alias CodeMySpec.Documents.Function

  @spec from_ast(list()) :: [Function.t()]
  def from_ast(ast) do
    ast
    |> group_by_h3()
    |> Enum.map(&parse_function/1)
  end

  defp group_by_h3(ast) do
    ast
    |> Enum.reduce({[], nil}, fn
      {"h3", [], [title], %{}}, {functions, current} ->
        name = String.trim(title)
        new_functions = if current, do: [current | functions], else: functions
        {new_functions, {name, []}}

      _element, {functions, nil} ->
        {functions, nil}

      element, {functions, {name, content}} ->
        {functions, {name, [element | content]}}
    end)
    |> case do
      {functions, nil} -> Enum.reverse(functions)
      {functions, current} -> Enum.reverse([current | functions])
    end
    |> Enum.map(fn {name, content} -> {name, Enum.reverse(content)} end)
  end

  defp parse_function({name, content}) do
    %{
      name: name,
      description: extract_description(content),
      spec: extract_spec(content),
      process: extract_process(content),
      test_assertions: extract_test_assertions(content)
    }
    |> then(&Ecto.embedded_load(Function, &1, :json))
  end

  defp extract_description(content) do
    # First paragraph before any code block or **bold** sections
    content
    |> Enum.find_value(fn
      {"p", [], text_content, %{}} ->
        text = extract_text(text_content)

        # Skip if it's a bold heading paragraph
        if String.starts_with?(text, "**") do
          nil
        else
          text
        end

      _ ->
        nil
    end)
  end

  defp extract_spec(content) do
    # Find elixir code block
    content
    |> Enum.find_value(fn
      {"pre", [], [{"code", [{"class", "elixir"}], [code], %{}}], %{}} ->
        String.trim(code)

      _ ->
        nil
    end)
  end

  defp extract_process(content) do
    # Find content after **Process**: until next **bold** section
    {process_content, _} =
      content
      |> Enum.reduce_while({[], :searching}, fn
        {"p", [], text_content, %{}}, {_parts, :searching} ->
          text = extract_text(text_content)

          if String.contains?(text, "**Process**:") do
            {:cont, {[], :capturing}}
          else
            {:cont, {[], :searching}}
          end

        {"p", [], text_content, %{}}, {parts, :capturing} ->
          text = extract_text(text_content)

          # Stop if we hit another bold section (but not Process itself)
          if String.starts_with?(text, "**") do
            {:halt, {parts, :done}}
          else
            {:cont, {[text | parts], :capturing}}
          end

        {"ol", [], items, %{}}, {parts, :capturing} ->
          list_text = format_ordered_list(items)
          {:cont, {[list_text | parts], :capturing}}

        {"ul", [], items, %{}}, {parts, :capturing} ->
          list_text = format_unordered_list(items)
          {:cont, {[list_text | parts], :capturing}}

        _element, acc ->
          {:cont, acc}
      end)

    process_content
    |> Enum.reverse()
    |> Enum.join("\n")
    |> String.trim()
    |> case do
      "" -> nil
      text -> text
    end
  end

  defp extract_test_assertions(content) do
    # Find list items after **Test Assertions**:
    {assertions, _} =
      content
      |> Enum.reduce_while({[], :searching}, fn
        {"p", [], text_content, %{}}, {assertions, :searching} ->
          text = extract_text(text_content)

          # extract_text removes markdown formatting, so check for plain text
          if String.contains?(text, "Test Assertions") do
            {:cont, {assertions, :capturing}}
          else
            {:cont, {assertions, :searching}}
          end

        {"ul", [], items, %{}}, {_assertions, :capturing} ->
          list_items = extract_li_content(items)
          {:halt, {list_items, :done}}

        {"ol", [], items, %{}}, {_assertions, :capturing} ->
          list_items = extract_li_content(items)
          {:halt, {list_items, :done}}

        _element, acc ->
          {:cont, acc}
      end)

    assertions
  end

  defp format_ordered_list(items) do
    items
    |> Enum.with_index(1)
    |> Enum.map_join("\n", fn {{("li"), [], content, %{}}, index} ->
      "#{index}. #{extract_text(content)}"
    end)
  end

  defp format_unordered_list(items) do
    items
    |> Enum.map_join("\n", fn {"li", [], content, %{}} ->
      "- #{extract_text(content)}"
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
defmodule CodeMySpec.Rules.RulesSeeder do
  alias CodeMySpec.Rules.RulesRepository
  alias CodeMySpec.Users.Scope

  @type rule_data :: %{
    name: String.t(),
    content: String.t(),
    component_type: String.t(),
    session_type: String.t()
  }

  @rules_directory "lib/code_my_spec/rules/content"

  def seed_account_rules(%Scope{} = scope) do
    with {:ok, rule_data_list} <- load_rules_from_directory(@rules_directory) do
      results =
        rule_data_list
        |> Enum.map(&create_rule_for_account(scope, &1))

      {:ok, Enum.map(results, fn {:ok, rule} -> rule end)}
    end
  end

  def load_rules_from_directory(path) do
    case File.exists?(path) do
      true ->
        path
        |> File.ls!()
        |> Enum.filter(&String.ends_with?(&1, ".md"))
        |> Enum.map(&Path.join(path, &1))
        |> Enum.map(&parse_rule_file/1)
        |> Enum.filter(&match?({:ok, _}, &1))
        |> Enum.map(fn {:ok, rule_data} -> rule_data end)
        |> then(&{:ok, &1})

      false ->
        {:error, :rules_directory_not_found}
    end
  end

  def parse_rule_file(file_path) do
    with {:ok, content} <- File.read(file_path),
         {:ok, frontmatter, markdown} <- parse_frontmatter(content) do
      rule_name = Path.basename(file_path, ".md")

      rule_data = %{
        name: rule_name,
        content: String.trim(markdown),
        component_type: Map.get(frontmatter, "component_type", "*"),
        session_type: Map.get(frontmatter, "session_type", "*")
      }

      {:ok, rule_data}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp create_rule_for_account(scope, rule_data) do
    RulesRepository.create_rule(scope, rule_data)
  end

  defp parse_frontmatter(content) do
    case String.split(content, "---", parts: 3) do
      ["", yaml_content, markdown_content] ->
        case YamlElixir.read_from_string(yaml_content) do
          {:ok, frontmatter} ->
            {:ok, frontmatter, markdown_content}

          {:error, _} ->
            {:ok, %{}, content}
        end

      [markdown_content] ->
        {:ok, %{}, markdown_content}

      _ ->
        {:ok, %{}, content}
    end
  end
end
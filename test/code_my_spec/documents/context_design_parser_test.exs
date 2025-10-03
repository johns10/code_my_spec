defmodule CodeMySpec.Documents.ContextDesignParserTest do
  use ExUnit.Case, async: true

  alias CodeMySpec.Documents.ContextDesignParser

  @fixture_path "test/support/fixtures/documents_fixtures/context_design_fixture.md"

  describe "from_markdown/1" do
    test "parses context design markdown correctly" do
      markdown_content = File.read!(@fixture_path)

      {:ok, result} = ContextDesignParser.from_markdown(markdown_content)

      assert result.purpose =~ "Manages dynamic rule composition"
      assert result.entity_ownership =~ "Rule entities with content"
      assert result.access_patterns =~ "Primary Scope"
      assert result.public_api =~ "@spec list_rules"
      assert result.state_management_strategy =~ "Rules stored in database"
      assert result.execution_flow =~ "Scope Validation"

      assert is_list(result.components)
      assert length(result.components) > 0

      # Check components are parsed as structured objects
      component_names = Enum.map(result.components, & &1.module_name)
      assert "CodeMySpec.Rules.Rule" in component_names
      assert "CodeMySpec.Rules.RuleRepository" in component_names

      assert is_list(result.dependencies)
      assert length(result.dependencies) > 0

      # Check dependencies are simple module names
      assert "CodeMySpec.Users.Scope" in result.dependencies
      assert "Ecto" in result.dependencies
      assert "Phoenix.PubSub" in result.dependencies

      # Check other sections are captured
      assert is_map(result.other_sections)
      assert Map.has_key?(result.other_sections, "implementation commands")
    end

    test "handles empty sections gracefully" do
      markdown = """
      # Test Context

      ## Purpose
      Test purpose.

      ## Entity Ownership

      ## Components

      ## Dependencies
      """

      {:ok, result} = ContextDesignParser.from_markdown(markdown)

      assert result.purpose == "Test purpose."
      assert result.entity_ownership == ""
      assert result.components == []
      assert result.dependencies == []
    end

    test "parses components with H3 sections" do
      markdown = """
      # Test Context

      ## Components

      ### CodeMySpec.Rules.Rule

      | field | value  |
      | ----- | ------ |
      | type  | schema |

      Database schema for rules

      ### RuleRepository

      Standard CRUD operations

      ### SimpleComponent

      Simple component with minimal setup
      """

      {:ok, result} = ContextDesignParser.from_markdown(markdown)

      assert length(result.components) == 3

      [rule_schema, rule_repo, simple_component] = result.components

      assert rule_schema.module_name == "CodeMySpec.Rules.Rule"
      assert rule_schema.table == %{"field" => "type", "value" => "schema"}
      assert rule_schema.description == "Database schema for rules"

      assert rule_repo.module_name == "RuleRepository"
      assert rule_repo.description == "Standard CRUD operations"

      assert simple_component.module_name == "SimpleComponent"
      assert simple_component.description == "Simple component with minimal setup"
    end

    test "parses dependencies as simple module names" do
      markdown = """
      # Test Context

      ## Dependencies
      - CodeMySpec.Users.Scope
      - CodeMySpec.Projects
      - Phoenix.PubSub
      - Ecto
      """

      {:ok, result} = ContextDesignParser.from_markdown(markdown)

      assert length(result.dependencies) == 4
      assert "CodeMySpec.Users.Scope" in result.dependencies
      assert "CodeMySpec.Projects" in result.dependencies
      assert "Phoenix.PubSub" in result.dependencies
      assert "Ecto" in result.dependencies
    end

    test "captures unknown sections in other_sections" do
      markdown = """
      # Test Context

      ## Purpose
      Test purpose.

      ## Custom Section
      This is a custom section that should be preserved.

      ## Another Unknown Section
      More custom content here.
      """

      {:ok, result} = ContextDesignParser.from_markdown(markdown)

      assert result.purpose == "Test purpose."
      assert Map.has_key?(result.other_sections, "custom section")
      assert Map.has_key?(result.other_sections, "another unknown section")
      assert result.other_sections["custom section"] =~ "custom section"
      assert result.other_sections["another unknown section"] =~ "custom content"
    end

    test "parses components without tables" do
      markdown = """
      # Test Context

      ## Components

      ### SimpleComponent

      Just a description

      ### AnotherComponent

      Another simple component
      """

      {:ok, result} = ContextDesignParser.from_markdown(markdown)

      assert length(result.components) == 2

      [simple, another] = result.components

      assert simple.module_name == "SimpleComponent"
      assert simple.description == "Just a description"
      assert simple.table == nil

      assert another.module_name == "AnotherComponent"
      assert another.description == "Another simple component"
      assert another.table == nil
    end

    test "parses simple dependencies" do
      markdown = """
      # Test Context

      ## Dependencies
      - SomeDep
      - AnotherDep
      """

      {:ok, result} = ContextDesignParser.from_markdown(markdown)

      assert length(result.dependencies) == 2
      assert "SomeDep" in result.dependencies
      assert "AnotherDep" in result.dependencies
    end
  end
end

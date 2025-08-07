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
      assert result.scope_integration =~ "Primary Scope"
      assert result.public_api =~ "@spec list_rules"
      assert result.state_management_strategy =~ "Rules stored in database"
      assert result.execution_flow =~ "Scope Validation"

      assert is_list(result.components)
      assert length(result.components) > 0

      # Check first component
      first_component = List.first(result.components)
      assert first_component.module_name =~ "Rule"
      assert first_component.description != ""

      assert is_list(result.dependencies)
      assert length(result.dependencies) > 0

      # Check dependencies include expected modules
      dependency_modules = Enum.map(result.dependencies, & &1.module_name)
      assert "CodeMySpec.Users.Scope" in dependency_modules
      assert "Ecto" in dependency_modules
      assert "Phoenix.PubSub" in dependency_modules

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

    test "parses components with YAML format" do
      markdown = """
      # Test Context

      ## Components
      - RuleSchema:
          module_name: CodeMySpec.Rules.Rule
          description: Database schema for rules
          type: schema
      - RuleRepository:
          description: Standard CRUD operations
      - SimpleComponent:
          description: Simple component with minimal setup
      """

      {:ok, result} = ContextDesignParser.from_markdown(markdown)

      assert length(result.components) == 3

      [yaml_component, desc_only_component, simple_component] = result.components

      assert yaml_component.module_name == "CodeMySpec.Rules.Rule"
      assert yaml_component.description == "Database schema for rules"
      assert Map.get(yaml_component, :type) == "schema"

      assert desc_only_component.module_name == "RuleRepository"
      assert desc_only_component.description == "Standard CRUD operations"

      assert simple_component.module_name == "SimpleComponent"
      assert simple_component.description == "Simple component with minimal setup"
    end

    test "parses dependencies with YAML format" do
      markdown = """
      # Test Context

      ## Dependencies
      - Scope:
          module_name: CodeMySpec.Users.Scope
          description: Account-level scoping and access control
          version: "~> 1.0"
      - Ecto:
          description: Database persistence
      - Phoenix.PubSub:
          description: Message broadcasting for real-time updates
      """

      {:ok, result} = ContextDesignParser.from_markdown(markdown)

      assert length(result.dependencies) == 3

      [yaml_dep, desc_only_dep, simple_dep] = result.dependencies

      assert yaml_dep.module_name == "CodeMySpec.Users.Scope"
      assert yaml_dep.description == "Account-level scoping and access control"
      assert Map.get(yaml_dep, :version) == "~> 1.0"

      assert desc_only_dep.module_name == "Ecto"
      assert desc_only_dep.description == "Database persistence"

      assert simple_dep.module_name == "Phoenix.PubSub"
      assert simple_dep.description == "Message broadcasting for real-time updates"
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

    test "returns error when components lack required description" do
      markdown = """
      # Test Context

      ## Components
      - BadComponent: {}
      - GoodComponent:
          description: This one has a description
      """

      {:error, reason} = ContextDesignParser.from_markdown(markdown)

      assert reason =~ "Components section error"
      assert reason =~ "description is required for item: BadComponent"
    end

    test "returns error when dependencies lack required description" do
      markdown = """
      # Test Context

      ## Dependencies
      - BadDep: {}
      - GoodDep:
          description: This dependency is properly described
      """

      {:error, reason} = ContextDesignParser.from_markdown(markdown)

      assert reason =~ "Dependencies section error"
      assert reason =~ "description is required for item: BadDep"
    end
  end
end

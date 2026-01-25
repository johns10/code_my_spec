defmodule CodeMySpec.Architecture.MermaidProjectorTest do
  use ExUnit.Case, async: true

  alias CodeMySpec.Architecture.MermaidProjector

  describe "project/1" do
    test "generates flowchart TD header" do
      result = MermaidProjector.project([])

      assert String.starts_with?(result, "flowchart TD")
    end

    test "filters to only include context types" do
      components = [
        build_component("MyApp.Accounts", "context"),
        build_component("MyApp.User", "schema"),
        build_component("MyApp.UserRepository", "repository"),
        build_component("MyApp.Stories", "context")
      ]

      result = MermaidProjector.project(components)

      # Should only include the two context components
      assert result =~ "myapp_accounts[MyApp.Accounts]"
      assert result =~ "myapp_stories[MyApp.Stories]"
      refute result =~ "myapp_user"
      refute result =~ "myapp_userrepository"
    end

    test "generates node for each context" do
      components = [
        build_component("MyApp.Accounts", "context"),
        build_component("MyApp.Stories", "context"),
        build_component("MyApp.Components", "context")
      ]

      result = MermaidProjector.project(components)

      assert result =~ "myapp_accounts[MyApp.Accounts]"
      assert result =~ "myapp_stories[MyApp.Stories]"
      assert result =~ "myapp_components[MyApp.Components]"
    end

    test "uses sanitized module name as node ID" do
      components = [
        build_component("MyApp.Accounts.UserManager", "context")
      ]

      result = MermaidProjector.project(components)

      # Dots replaced by underscores, lowercased
      assert result =~ "myapp_accounts_usermanager[MyApp.Accounts.UserManager]"
    end

    test "uses full module name as node label" do
      components = [
        build_component("MyApp.Accounts", "context")
      ]

      result = MermaidProjector.project(components)

      # Full module name appears in brackets
      assert result =~ "[MyApp.Accounts]"
    end

    test "generates edges for dependencies" do
      accounts_component = build_component("MyApp.Accounts", "context")

      # Stories depends on Accounts
      components = [
        accounts_component,
        build_component_with_dependencies("MyApp.Stories", "context", [accounts_component])
      ]

      result = MermaidProjector.project(components)

      # Should have edge from Stories to Accounts
      assert result =~ "myapp_stories --> myapp_accounts"
    end

    test "handles empty component list" do
      result = MermaidProjector.project([])

      # Should just have the header
      assert result == "flowchart TD"
    end

    test "handles contexts with no dependencies" do
      components = [
        build_component("MyApp.Accounts", "context"),
        build_component("MyApp.Stories", "context")
      ]

      result = MermaidProjector.project(components)

      # Should have nodes but no edges
      assert result =~ "myapp_accounts[MyApp.Accounts]"
      assert result =~ "myapp_stories[MyApp.Stories]"
      refute result =~ "-->"
    end
  end

  # Fixture functions

  defp build_component(module_name, type) do
    %{
      id: Ecto.UUID.generate(),
      module_name: module_name,
      type: type,
      name: extract_name(module_name),
      outgoing_dependencies: []
    }
  end

  defp build_component_with_dependencies(module_name, type, target_components) do
    outgoing_dependencies =
      Enum.map(target_components, fn target ->
        %{target_component: target}
      end)

    %{
      id: Ecto.UUID.generate(),
      module_name: module_name,
      type: type,
      name: extract_name(module_name),
      outgoing_dependencies: outgoing_dependencies
    }
  end

  defp extract_name(module_name) do
    module_name
    |> String.split(".")
    |> List.last()
  end
end

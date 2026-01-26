defmodule CodeMySpec.MCPServers.Architecture.Tools.ListSpecsTest do
  use ExUnit.Case, async: true

  alias CodeMySpec.MCPServers.Architecture.Tools.ListSpecs
  alias CodeMySpec.Components
  alias Hermes.Server.Frame
  import CodeMySpec.UsersFixtures

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(CodeMySpec.Repo)
  end

  describe "ListSpecs tool" do
    test "lists all specs in project" do
      scope = full_scope_fixture()

      # Create multiple components
      Components.upsert_component(scope, %{
        module_name: "TestApp.Component1",
        type: "context",
        name: "Component1",
        description: "First component"
      })

      Components.upsert_component(scope, %{
        module_name: "TestApp.Component2",
        type: "module",
        name: "Component2",
        description: "Second component"
      })

      Components.upsert_component(scope, %{
        module_name: "TestApp.Component3",
        type: "schema",
        name: "Component3",
        description: "Third component"
      })

      params = %{}
      frame = %Frame{assigns: %{current_scope: scope}}

      assert {:reply, response, ^frame} = ListSpecs.execute(params, frame)
      assert response.type == :tool
      assert response.isError == false

      # Parse response
      assert [%{"type" => "text", "text" => json_text}] = response.content
      data = Jason.decode!(json_text)

      # Verify all components are returned
      assert length(data["specs"]) == 3
      module_names = Enum.map(data["specs"], & &1["module_name"])
      assert "TestApp.Component1" in module_names
      assert "TestApp.Component2" in module_names
      assert "TestApp.Component3" in module_names

      # Verify spec paths are included
      spec = Enum.find(data["specs"], &(&1["module_name"] == "TestApp.Component1"))
      assert spec["spec_path"] == "docs/spec/test_app/component1.spec.md"
    end

    test "filters specs by type" do
      scope = full_scope_fixture()

      # Create components of different types
      Components.upsert_component(scope, %{
        module_name: "TestApp.Context1",
        type: "context",
        name: "Context1"
      })

      Components.upsert_component(scope, %{
        module_name: "TestApp.Context2",
        type: "context",
        name: "Context2"
      })

      Components.upsert_component(scope, %{
        module_name: "TestApp.Module1",
        type: "module",
        name: "Module1"
      })

      params = %{type: "context"}
      frame = %Frame{assigns: %{current_scope: scope}}

      assert {:reply, response, ^frame} = ListSpecs.execute(params, frame)
      assert response.isError == false

      # Parse response
      assert [%{"type" => "text", "text" => json_text}] = response.content
      data = Jason.decode!(json_text)

      # Verify only context components are returned
      assert length(data["specs"]) == 2
      types = Enum.map(data["specs"], & &1["type"])
      assert Enum.all?(types, &(&1 == "context"))

      module_names = Enum.map(data["specs"], & &1["module_name"])
      assert "TestApp.Context1" in module_names
      assert "TestApp.Context2" in module_names
      refute "TestApp.Module1" in module_names
    end

    test "returns empty list when no components exist" do
      scope = full_scope_fixture()

      params = %{}
      frame = %Frame{assigns: %{current_scope: scope}}

      assert {:reply, response, ^frame} = ListSpecs.execute(params, frame)
      assert response.isError == false

      # Parse response
      assert [%{"type" => "text", "text" => json_text}] = response.content
      data = Jason.decode!(json_text)

      assert data["specs"] == []
    end

    test "returns empty list when filtering by type with no matches" do
      scope = full_scope_fixture()

      # Create components of one type
      Components.upsert_component(scope, %{
        module_name: "TestApp.Module1",
        type: "module",
        name: "Module1"
      })

      # Filter by different type
      params = %{type: "context"}
      frame = %Frame{assigns: %{current_scope: scope}}

      assert {:reply, response, ^frame} = ListSpecs.execute(params, frame)
      assert response.isError == false

      # Parse response
      assert [%{"type" => "text", "text" => json_text}] = response.content
      data = Jason.decode!(json_text)

      assert data["specs"] == []
    end

    test "includes component metadata in response" do
      scope = full_scope_fixture()

      Components.upsert_component(scope, %{
        module_name: "TestApp.WithMetadata",
        type: "context",
        name: "WithMetadata",
        description: "Component with metadata"
      })

      params = %{}
      frame = %Frame{assigns: %{current_scope: scope}}

      assert {:reply, response, ^frame} = ListSpecs.execute(params, frame)
      assert response.isError == false

      # Parse response
      assert [%{"type" => "text", "text" => json_text}] = response.content
      data = Jason.decode!(json_text)

      spec = List.first(data["specs"])
      assert spec["module_name"] == "TestApp.WithMetadata"
      assert spec["type"] == "context"
      assert spec["name"] == "WithMetadata"
      assert spec["description"] == "Component with metadata"
      assert spec["spec_path"] == "docs/spec/test_app/with_metadata.spec.md"
    end

    test "returns error when scope is invalid" do
      params = %{}
      frame = %Frame{assigns: %{}}

      assert {:reply, response, ^frame} = ListSpecs.execute(params, frame)
      assert response.type == :tool
      assert response.isError == true
    end

    test "handles various component types" do
      scope = full_scope_fixture()

      types = ["context", "module", "schema", "repository", "liveview", "coordinator"]

      for type <- types do
        Components.upsert_component(scope, %{
          module_name: "TestApp.#{String.capitalize(type)}",
          type: type,
          name: String.capitalize(type)
        })
      end

      params = %{}
      frame = %Frame{assigns: %{current_scope: scope}}

      assert {:reply, response, ^frame} = ListSpecs.execute(params, frame)
      assert response.isError == false

      # Parse response
      assert [%{"type" => "text", "text" => json_text}] = response.content
      data = Jason.decode!(json_text)

      assert length(data["specs"]) == length(types)
      returned_types = Enum.map(data["specs"], & &1["type"]) |> Enum.sort()
      assert returned_types == Enum.sort(types)
    end
  end
end

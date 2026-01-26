defmodule CodeMySpec.MCPServers.Architecture.Tools.DeleteSpecTest do
  use ExUnit.Case, async: false

  alias CodeMySpec.MCPServers.Architecture.Tools.DeleteSpec
  alias CodeMySpec.Components
  alias Hermes.Server.Frame
  import CodeMySpec.UsersFixtures

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(CodeMySpec.Repo)
  end

  describe "DeleteSpec tool" do
    test "deletes spec file and removes from database" do
      scope = full_scope_fixture()

      # Create spec file
      spec_path = "docs/spec/test_app/deletable.spec.md"
      File.mkdir_p!(Path.dirname(spec_path))

      spec_content = """
      # TestApp.Deletable

      This will be deleted.

      ## Dependencies

      - None
      """

      File.write!(spec_path, spec_content)

      # Create component in DB
      Components.upsert_component(scope, %{
        module_name: "TestApp.Deletable",
        type: "module",
        name: "Deletable",
        description: "This will be deleted."
      })

      # Verify it exists
      assert File.exists?(spec_path)
      assert Components.get_component_by_module_name(scope, "TestApp.Deletable") != nil

      params = %{module_name: "TestApp.Deletable"}
      frame = %Frame{assigns: %{current_scope: scope}}

      assert {:reply, response, ^frame} = DeleteSpec.execute(params, frame)
      assert response.type == :tool
      assert response.isError == false

      # Parse response
      assert [%{"type" => "text", "text" => json_text}] = response.content
      data = Jason.decode!(json_text)

      assert data["success"] == true
      assert data["message"] == "Spec deleted successfully"
      assert data["module_name"] == "TestApp.Deletable"
      assert data["spec_path"] == spec_path

      # Verify spec file was deleted
      refute File.exists?(spec_path)

      # Verify component was deleted from DB
      assert Components.get_component_by_module_name(scope, "TestApp.Deletable") == nil

      # Cleanup
      File.rm_rf!("docs/spec/test_app")
    end

    test "succeeds even if spec file doesn't exist" do
      scope = full_scope_fixture()

      # Create component in DB but no spec file
      Components.upsert_component(scope, %{
        module_name: "TestApp.NoFile",
        type: "module",
        name: "NoFile"
      })

      params = %{module_name: "TestApp.NoFile"}
      frame = %Frame{assigns: %{current_scope: scope}}

      assert {:reply, response, ^frame} = DeleteSpec.execute(params, frame)
      assert response.isError == false

      # Parse response
      assert [%{"type" => "text", "text" => json_text}] = response.content
      data = Jason.decode!(json_text)

      assert data["success"] == true

      # Verify component was deleted from DB
      assert Components.get_component_by_module_name(scope, "TestApp.NoFile") == nil
    end

    test "cascades delete to dependencies" do
      scope = full_scope_fixture()

      # Create spec file
      spec_path = "docs/spec/test_app/with_deps.spec.md"
      File.mkdir_p!(Path.dirname(spec_path))
      File.write!(spec_path, "# TestApp.WithDeps\n\nHas dependencies")

      # Create components
      main =
        Components.upsert_component(scope, %{
          module_name: "TestApp.WithDeps",
          type: "context",
          name: "WithDeps"
        })

      dep =
        Components.upsert_component(scope, %{
          module_name: "TestApp.Dependency",
          type: "module",
          name: "Dependency"
        })

      # Create dependency relationship
      Components.create_dependency(scope, %{
        source_component_id: main.id,
        target_component_id: dep.id
      })

      # Verify dependency exists
      deps = Components.list_dependencies(scope)
      assert length(deps) == 1

      params = %{module_name: "TestApp.WithDeps"}
      frame = %Frame{assigns: %{current_scope: scope}}

      assert {:reply, response, ^frame} = DeleteSpec.execute(params, frame)
      assert response.isError == false

      # Verify component was deleted
      assert Components.get_component_by_module_name(scope, "TestApp.WithDeps") == nil

      # Verify dependency was cascade deleted
      deps_after = Components.list_dependencies(scope)
      assert length(deps_after) == 0

      # Verify dependency component still exists
      assert Components.get_component_by_module_name(scope, "TestApp.Dependency") != nil

      # Cleanup
      File.rm_rf!("docs/spec/test_app")
    end

    test "returns error when component not found" do
      scope = full_scope_fixture()

      params = %{module_name: "TestApp.NonExistent"}
      frame = %Frame{assigns: %{current_scope: scope}}

      assert {:reply, response, ^frame} = DeleteSpec.execute(params, frame)
      assert response.type == :tool
      assert response.isError == true
    end

    test "returns error when scope is invalid" do
      params = %{module_name: "TestApp.Invalid"}
      frame = %Frame{assigns: %{}}

      assert {:reply, response, ^frame} = DeleteSpec.execute(params, frame)
      assert response.type == :tool
      assert response.isError == true
    end

    test "deletes spec with nested directory structure" do
      scope = full_scope_fixture()

      # Create deeply nested spec file
      spec_path = "docs/spec/test_app/deeply/nested/component.spec.md"
      File.mkdir_p!(Path.dirname(spec_path))
      File.write!(spec_path, "# TestApp.Deeply.Nested.Component\n\nNested")

      Components.upsert_component(scope, %{
        module_name: "TestApp.Deeply.Nested.Component",
        type: "module",
        name: "Component"
      })

      params = %{module_name: "TestApp.Deeply.Nested.Component"}
      frame = %Frame{assigns: %{current_scope: scope}}

      assert {:reply, response, ^frame} = DeleteSpec.execute(params, frame)
      assert response.isError == false

      # Verify spec file was deleted
      refute File.exists?(spec_path)

      # Verify component was deleted
      assert Components.get_component_by_module_name(scope, "TestApp.Deeply.Nested.Component") ==
               nil

      # Cleanup
      File.rm_rf!("docs/spec/test_app")
    end
  end
end

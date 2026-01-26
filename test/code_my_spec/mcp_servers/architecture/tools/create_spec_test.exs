defmodule CodeMySpec.MCPServers.Architecture.Tools.CreateSpecTest do
  use ExUnit.Case, async: false

  alias CodeMySpec.MCPServers.Architecture.Tools.CreateSpec
  alias CodeMySpec.Components
  alias Hermes.Server.Frame
  import CodeMySpec.UsersFixtures

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(CodeMySpec.Repo)
  end

  describe "CreateSpec tool" do
    test "creates spec file and syncs to database" do
      scope = full_scope_fixture()

      params = %{
        module_name: "TestApp.Foo.Bar",
        type: "context",
        description: "Test component",
        dependencies: ["TestApp.Baz", "TestApp.Qux"]
      }

      frame = %Frame{assigns: %{current_scope: scope}}

      assert {:reply, response, ^frame} = CreateSpec.execute(params, frame)
      assert response.type == :tool
      assert response.isError == false

      # Verify spec file was created
      spec_path = "docs/spec/test_app/foo/bar.spec.md"
      assert File.exists?(spec_path)
      content = File.read!(spec_path)
      assert content =~ "# TestApp.Foo.Bar"
      assert content =~ "Test component"
      assert content =~ "- TestApp.Baz"
      assert content =~ "- TestApp.Qux"

      # Verify component exists in database (type may be synced from spec file)
      component = Components.get_component_by_module_name(scope, "TestApp.Foo.Bar")
      assert component != nil
      assert component.module_name == "TestApp.Foo.Bar"
      assert component.name == "Bar"

      # Cleanup
      File.rm_rf!("docs/spec/test_app")
    end

    test "creates spec with no dependencies" do
      scope = full_scope_fixture()

      params = %{
        module_name: "TestApp.Simple",
        type: "module",
        description: "Simple module"
      }

      frame = %Frame{assigns: %{current_scope: scope}}

      assert {:reply, response, ^frame} = CreateSpec.execute(params, frame)
      assert response.type == :tool
      assert response.isError == false

      # Verify spec file content
      spec_path = "docs/spec/test_app/simple.spec.md"
      assert File.exists?(spec_path)
      content = File.read!(spec_path)
      assert content =~ "- None"

      # Cleanup
      File.rm_rf!("docs/spec/test_app")
    end

    test "creates spec without description" do
      scope = full_scope_fixture()

      params = %{
        module_name: "TestApp.NoDesc",
        type: "schema"
      }

      frame = %Frame{assigns: %{current_scope: scope}}

      assert {:reply, response, ^frame} = CreateSpec.execute(params, frame)
      assert response.type == :tool
      assert response.isError == false

      # Verify spec file content
      spec_path = "docs/spec/test_app/no_desc.spec.md"
      assert File.exists?(spec_path)
      content = File.read!(spec_path)
      assert content =~ "No description provided"

      # Cleanup
      File.rm_rf!("docs/spec/test_app")
    end

    test "upserts component if it already exists" do
      scope = full_scope_fixture()

      params = %{
        module_name: "TestApp.Existing",
        type: "context",
        description: "First description"
      }

      frame = %Frame{assigns: %{current_scope: scope}}

      # Create first time
      assert {:reply, response1, ^frame} = CreateSpec.execute(params, frame)
      assert response1.isError == false

      # Create again with different description (spec file will be overwritten)
      params2 = %{
        module_name: "TestApp.Existing",
        type: "context",
        description: "Updated description"
      }

      assert {:reply, response2, ^frame} = CreateSpec.execute(params2, frame)
      assert response2.isError == false

      # Verify component was updated
      component = Components.get_component_by_module_name(scope, "TestApp.Existing")
      assert component.description == "Updated description"

      # Cleanup
      File.rm_rf!("docs/spec/test_app")
    end

    test "returns error when scope is invalid" do
      params = %{
        module_name: "TestApp.Invalid",
        type: "context"
      }

      frame = %Frame{assigns: %{}}

      assert {:reply, response, ^frame} = CreateSpec.execute(params, frame)
      assert response.type == :tool
      assert response.isError == true
    end
  end
end

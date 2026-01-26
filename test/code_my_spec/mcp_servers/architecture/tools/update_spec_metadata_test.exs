defmodule CodeMySpec.McpServers.Architecture.Tools.UpdateSpecMetadataTest do
  use ExUnit.Case, async: false

  alias CodeMySpec.McpServers.Architecture.Tools.UpdateSpecMetadata
  alias CodeMySpec.Components
  alias Hermes.Server.Frame
  import CodeMySpec.UsersFixtures

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(CodeMySpec.Repo)
  end

  describe "UpdateSpecMetadata tool" do
    test "updates description without touching Functions section" do
      scope = full_scope_fixture()

      # Create initial spec file with Functions section
      spec_path = "docs/spec/test_app/updatable.spec.md"
      File.mkdir_p!(Path.dirname(spec_path))

      initial_content = """
      # TestApp.Updatable

      Original description

      ## Dependencies

      - TestApp.Foo
      - TestApp.Bar

      ## Functions

      ### my_function/1

      Does something important.

      ```elixir
      @spec my_function(String.t()) :: :ok
      ```

      **Process**:
      1. Step one
      2. Step two

      **Test Assertions**:
      - assertion one
      - assertion two
      """

      File.write!(spec_path, initial_content)

      # Create component in DB
      Components.upsert_component(scope, %{
        module_name: "TestApp.Updatable",
        type: "module",
        description: "Original description"
      })

      params = %{
        module_name: "TestApp.Updatable",
        description: "Updated description"
      }

      frame = %Frame{assigns: %{current_scope: scope}}

      assert {:reply, response, ^frame} = UpdateSpecMetadata.execute(params, frame)
      assert response.type == :tool
      assert response.isError == false

      # Verify spec file was updated
      updated_content = File.read!(spec_path)
      assert updated_content =~ "Updated description"
      assert updated_content =~ "## Functions"
      assert updated_content =~ "### my_function/1"
      assert updated_content =~ "Does something important"
      assert updated_content =~ "**Process**:"
      assert updated_content =~ "**Test Assertions**:"

      # Verify dependencies section unchanged
      assert updated_content =~ "## Dependencies"
      assert updated_content =~ "- TestApp.Foo"
      assert updated_content =~ "- TestApp.Bar"

      # Verify component was synced to database
      component = Components.get_component_by_module_name(scope, "TestApp.Updatable")
      assert component.description == "Updated description"

      # Cleanup
      File.rm_rf!("docs/spec/test_app")
    end

    test "updates dependencies without touching Functions section" do
      scope = full_scope_fixture()

      spec_path = "docs/spec/test_app/deps_update.spec.md"
      File.mkdir_p!(Path.dirname(spec_path))

      initial_content = """
      # TestApp.DepsUpdate

      Some description

      ## Dependencies

      - TestApp.Old

      ## Functions

      ### another_function/2

      Another important function.

      ```elixir
      @spec another_function(atom(), map()) :: {:ok, term()}
      ```
      """

      File.write!(spec_path, initial_content)

      params = %{
        module_name: "TestApp.DepsUpdate",
        dependencies: ["TestApp.New1", "TestApp.New2"]
      }

      frame = %Frame{assigns: %{current_scope: scope}}

      assert {:reply, response, ^frame} = UpdateSpecMetadata.execute(params, frame)
      assert response.isError == false

      # Verify spec file was updated
      updated_content = File.read!(spec_path)
      assert updated_content =~ "- TestApp.New1"
      assert updated_content =~ "- TestApp.New2"
      refute updated_content =~ "- TestApp.Old"

      # Verify description unchanged
      assert updated_content =~ "Some description"

      # Verify Functions section unchanged
      assert updated_content =~ "## Functions"
      assert updated_content =~ "### another_function/2"
      assert updated_content =~ "Another important function"

      # Cleanup
      File.rm_rf!("docs/spec/test_app")
    end

    test "updates both description and dependencies" do
      scope = full_scope_fixture()

      spec_path = "docs/spec/test_app/both_update.spec.md"
      File.mkdir_p!(Path.dirname(spec_path))

      initial_content = """
      # TestApp.BothUpdate

      Old description

      ## Dependencies

      - TestApp.OldDep

      ## Functions

      ### keep_me/0

      This should remain.
      """

      File.write!(spec_path, initial_content)

      params = %{
        module_name: "TestApp.BothUpdate",
        description: "New description",
        dependencies: ["TestApp.NewDep1", "TestApp.NewDep2"]
      }

      frame = %Frame{assigns: %{current_scope: scope}}

      assert {:reply, response, ^frame} = UpdateSpecMetadata.execute(params, frame)
      assert response.isError == false

      updated_content = File.read!(spec_path)
      assert updated_content =~ "New description"
      assert updated_content =~ "- TestApp.NewDep1"
      assert updated_content =~ "- TestApp.NewDep2"
      assert updated_content =~ "## Functions"
      assert updated_content =~ "### keep_me/0"

      # Cleanup
      File.rm_rf!("docs/spec/test_app")
    end

    test "preserves Fields section when updating metadata" do
      scope = full_scope_fixture()

      spec_path = "docs/spec/test_app/with_fields.spec.md"
      File.mkdir_p!(Path.dirname(spec_path))

      initial_content = """
      # TestApp.WithFields

      Schema description

      ## Dependencies

      - Ecto.Schema

      ## Fields

      | Field | Type | Required | Description | Constraints |
      |-------|------|----------|-------------|-------------|
      | id    | integer | Yes (auto) | Primary key | Auto-generated |
      | name  | string | Yes | Name field | Min: 1, Max: 255 |

      ## Functions

      ### changeset/2

      Validates the schema.
      """

      File.write!(spec_path, initial_content)

      params = %{
        module_name: "TestApp.WithFields",
        description: "Updated schema description"
      }

      frame = %Frame{assigns: %{current_scope: scope}}

      assert {:reply, response, ^frame} = UpdateSpecMetadata.execute(params, frame)
      assert response.isError == false

      updated_content = File.read!(spec_path)
      assert updated_content =~ "Updated schema description"
      assert updated_content =~ "## Fields"
      assert updated_content =~ "| Field | Type | Required"
      assert updated_content =~ "| id    | integer"
      assert updated_content =~ "## Functions"
      assert updated_content =~ "### changeset/2"

      # Cleanup
      File.rm_rf!("docs/spec/test_app")
    end

    test "handles empty dependencies list" do
      scope = full_scope_fixture()

      spec_path = "docs/spec/test_app/empty_deps.spec.md"
      File.mkdir_p!(Path.dirname(spec_path))

      initial_content = """
      # TestApp.EmptyDeps

      Description

      ## Dependencies

      - TestApp.Something

      ## Functions

      ### my_func/0
      """

      File.write!(spec_path, initial_content)

      params = %{
        module_name: "TestApp.EmptyDeps",
        dependencies: []
      }

      frame = %Frame{assigns: %{current_scope: scope}}

      assert {:reply, response, ^frame} = UpdateSpecMetadata.execute(params, frame)
      assert response.isError == false

      updated_content = File.read!(spec_path)
      assert updated_content =~ "- None"
      refute updated_content =~ "- TestApp.Something"

      # Cleanup
      File.rm_rf!("docs/spec/test_app")
    end

    test "updates component type in database" do
      scope = full_scope_fixture()

      spec_path = "docs/spec/test_app/type_update.spec.md"
      File.mkdir_p!(Path.dirname(spec_path))

      initial_content = """
      # TestApp.TypeUpdate

      Description

      ## Dependencies

      - None
      """

      File.write!(spec_path, initial_content)

      # Create component with initial type
      Components.upsert_component(scope, %{
        module_name: "TestApp.TypeUpdate",
        type: "module",
        description: "Description"
      })

      params = %{
        module_name: "TestApp.TypeUpdate",
        type: "context"
      }

      frame = %Frame{assigns: %{current_scope: scope}}

      assert {:reply, response, ^frame} = UpdateSpecMetadata.execute(params, frame)
      assert response.isError == false

      # Verify type was updated in database
      component = Components.get_component_by_module_name(scope, "TestApp.TypeUpdate")
      assert component.type == "context"

      # Cleanup
      File.rm_rf!("docs/spec/test_app")
    end

    test "returns error when spec file doesn't exist" do
      scope = full_scope_fixture()

      params = %{
        module_name: "TestApp.NonExistent",
        description: "New description"
      }

      frame = %Frame{assigns: %{current_scope: scope}}

      assert {:reply, response, ^frame} = UpdateSpecMetadata.execute(params, frame)
      assert response.type == :tool
      assert response.isError == true
    end

    test "returns error when scope is invalid" do
      params = %{
        module_name: "TestApp.Invalid",
        description: "New description"
      }

      frame = %Frame{assigns: %{}}

      assert {:reply, response, ^frame} = UpdateSpecMetadata.execute(params, frame)
      assert response.type == :tool
      assert response.isError == true
    end

    test "preserves complex multi-section spec structure" do
      scope = full_scope_fixture()

      spec_path = "docs/spec/test_app/complex.spec.md"
      File.mkdir_p!(Path.dirname(spec_path))

      initial_content = """
      # TestApp.Complex

      Original description

      ## Dependencies

      - TestApp.Dep1

      ## Delegates

      - func1/1: Target.Module.func1/1

      ## Fields

      | Field | Type | Required |
      |-------|------|----------|
      | id    | int  | Yes      |

      ## Functions

      ### func1/1

      First function.

      ### func2/2

      Second function with details.

      **Process**:
      1. Do something

      **Test Assertions**:
      - Check something

      ## Custom Section

      Some custom content that should be preserved.
      """

      File.write!(spec_path, initial_content)

      params = %{
        module_name: "TestApp.Complex",
        description: "Updated description",
        dependencies: ["TestApp.NewDep"]
      }

      frame = %Frame{assigns: %{current_scope: scope}}

      assert {:reply, response, ^frame} = UpdateSpecMetadata.execute(params, frame)
      assert response.isError == false

      updated_content = File.read!(spec_path)

      # Verify metadata was updated
      assert updated_content =~ "Updated description"
      assert updated_content =~ "- TestApp.NewDep"
      refute updated_content =~ "- TestApp.Dep1"

      # Verify all other sections preserved
      assert updated_content =~ "## Delegates"
      assert updated_content =~ "- func1/1: Target.Module.func1/1"
      assert updated_content =~ "## Fields"
      assert updated_content =~ "| Field | Type | Required |"
      assert updated_content =~ "## Functions"
      assert updated_content =~ "### func1/1"
      assert updated_content =~ "### func2/2"
      assert updated_content =~ "**Process**:"
      assert updated_content =~ "**Test Assertions**:"
      assert updated_content =~ "## Custom Section"
      assert updated_content =~ "Some custom content that should be preserved"

      # Cleanup
      File.rm_rf!("docs/spec/test_app")
    end
  end
end

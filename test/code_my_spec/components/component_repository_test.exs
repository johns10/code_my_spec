defmodule CodeMySpec.Components.ComponentRepositoryTest do
  use CodeMySpec.DataCase, async: true

  import CodeMySpec.ComponentsFixtures
  import CodeMySpec.ProjectsFixtures
  import CodeMySpec.UsersFixtures
  import CodeMySpec.AccountsFixtures

  alias CodeMySpec.Components.{Component, ComponentRepository}
  alias CodeMySpec.Repo

  setup do
    user = user_fixture()
    account = account_with_owner_fixture(user)
    scope = user_scope_fixture(user, account)
    project = project_fixture(scope)
    scope = user_scope_fixture(user, account, project)

    %{scope: scope, project: project, user: user, account: account}
  end

  describe "list_components/1" do
    test "returns all components for the project", %{scope: scope} do
      component1 = component_fixture(scope, %{name: "Component1"})
      component2 = component_fixture(scope, %{name: "Component2"})

      # Create component in different project to ensure isolation
      other_user = user_fixture()
      other_account = account_with_owner_fixture(other_user)
      other_scope = user_scope_fixture(other_user, other_account)
      other_project = project_fixture(other_scope)
      other_scope = user_scope_fixture(other_user, other_account, other_project)
      _other_component = component_fixture(other_scope, %{name: "OtherComponent"})

      result = ComponentRepository.list_components(scope)

      assert length(result) == 2
      assert Enum.find(result, &(&1.id == component1.id))
      assert Enum.find(result, &(&1.id == component2.id))
    end

    test "returns empty list when no components exist", %{scope: scope} do
      result = ComponentRepository.list_components(scope)
      assert result == []
    end
  end

  describe "get_component!/2" do
    test "returns component when it exists in project", %{scope: scope} do
      component = component_fixture(scope)

      result = ComponentRepository.get_component!(scope, component.id)

      assert result.id == component.id
      assert result.name == component.name
    end

    test "raises when component doesn't exist", %{scope: scope} do
      assert_raise Ecto.NoResultsError, fn ->
        ComponentRepository.get_component!(scope, 999)
      end
    end

    test "raises when component exists but belongs to different project", %{scope: scope} do
      # Create component in different project
      other_user = user_fixture()
      other_account = account_with_owner_fixture(other_user)
      other_scope = user_scope_fixture(other_user, other_account)
      other_project = project_fixture(other_scope)
      other_scope = user_scope_fixture(other_user, other_account, other_project)
      other_component = component_fixture(other_scope)

      assert_raise Ecto.NoResultsError, fn ->
        ComponentRepository.get_component!(scope, other_component.id)
      end
    end
  end

  describe "get_component/2" do
    test "returns component when it exists in project", %{scope: scope} do
      component = component_fixture(scope)

      result = ComponentRepository.get_component(scope, component.id)

      assert result.id == component.id
      assert result.name == component.name
    end

    test "returns nil when component doesn't exist", %{scope: scope} do
      result = ComponentRepository.get_component(scope, 999)
      assert is_nil(result)
    end

    test "returns nil when component exists but belongs to different project", %{scope: scope} do
      # Create component in different project
      other_user = user_fixture()
      other_account = account_with_owner_fixture(other_user)
      other_scope = user_scope_fixture(other_user, other_account)
      other_project = project_fixture(other_scope)
      other_scope = user_scope_fixture(other_user, other_account, other_project)
      other_component = component_fixture(other_scope)

      result = ComponentRepository.get_component(scope, other_component.id)
      assert is_nil(result)
    end
  end

  describe "create_component/2" do
    test "creates component with valid attributes", %{scope: scope} do
      attrs = %{
        name: "NewComponent",
        type: :context,
        module_name: "MyApp.NewComponent",
        description: "A new component"
      }

      assert {:ok, component} = ComponentRepository.create_component(scope, attrs)
      assert component.name == "NewComponent"
      assert component.type == :context
      assert component.module_name == "MyApp.NewComponent"
      assert component.description == "A new component"
      assert component.project_id == scope.active_project_id

      # Verify database persistence
      db_component = Repo.get(Component, component.id)
      assert db_component.name == "NewComponent"
    end

    test "returns error with invalid attributes", %{scope: scope} do
      attrs = %{name: "", module_name: ""}

      assert {:error, changeset} = ComponentRepository.create_component(scope, attrs)

      assert errors_on(changeset) == %{
               name: ["can't be blank"],
               module_name: ["can't be blank"],
               type: ["can't be blank"]
             }
    end

    test "returns error with invalid module name format", %{scope: scope} do
      attrs = %{
        name: "TestComponent",
        type: :context,
        module_name: "invalid_module_name"
      }

      assert {:error, changeset} = ComponentRepository.create_component(scope, attrs)
      assert errors_on(changeset) == %{module_name: ["must be a valid Elixir module name"]}
    end

    test "returns error when name already exists in project", %{scope: scope} do
      component_fixture(scope, %{name: "DuplicateName"})

      attrs = %{
        name: "DuplicateName",
        type: :context,
        module_name: "MyApp.Different"
      }

      assert {:error, changeset} = ComponentRepository.create_component(scope, attrs)
      assert errors_on(changeset) == %{name: ["has already been taken"]}
    end

    test "returns error when module_name already exists in project", %{scope: scope} do
      component_fixture(scope, %{module_name: "MyApp.Duplicate"})

      attrs = %{
        name: "DifferentName",
        type: :context,
        module_name: "MyApp.Duplicate"
      }

      assert {:error, changeset} = ComponentRepository.create_component(scope, attrs)
      assert errors_on(changeset) == %{module_name: ["has already been taken"]}
    end

    test "allows duplicate names across different projects", %{scope: scope} do
      # Create component in different project with same name
      other_user = user_fixture()
      other_account = account_with_owner_fixture(other_user)
      other_scope = user_scope_fixture(other_user, other_account)
      other_project = project_fixture(other_scope)
      other_scope = user_scope_fixture(other_user, other_account, other_project)
      component_fixture(other_scope, %{name: "SameName", module_name: "Other.SameName"})

      attrs = %{
        name: "SameName",
        type: :context,
        module_name: "MyApp.SameName"
      }

      assert {:ok, component} = ComponentRepository.create_component(scope, attrs)
      assert component.name == "SameName"
    end
  end

  describe "update_component/3" do
    test "updates component with valid attributes", %{scope: scope} do
      component = component_fixture(scope)
      attrs = %{name: "UpdatedName", description: "Updated description"}

      assert {:ok, updated_component} =
               ComponentRepository.update_component(scope, component, attrs)

      assert updated_component.name == "UpdatedName"
      assert updated_component.description == "Updated description"
      # unchanged
      assert updated_component.type == component.type

      # Verify database persistence
      db_component = Repo.get(Component, component.id)
      assert db_component.name == "UpdatedName"
    end

    test "returns error with invalid attributes", %{scope: scope} do
      component = component_fixture(scope)
      attrs = %{name: "", module_name: "invalid_format"}

      assert {:error, changeset} = ComponentRepository.update_component(scope, component, attrs)

      assert errors_on(changeset) == %{
               name: ["can't be blank"],
               module_name: ["must be a valid Elixir module name"]
             }
    end

    test "returns error when updated name conflicts with existing component", %{scope: scope} do
      _component1 = component_fixture(scope, %{name: "Component1"})
      component2 = component_fixture(scope, %{name: "Component2"})

      attrs = %{name: "Component1"}

      assert {:error, changeset} = ComponentRepository.update_component(scope, component2, attrs)
      assert errors_on(changeset) == %{name: ["has already been taken"]}
    end
  end

  describe "delete_component/2" do
    test "deletes component successfully", %{scope: scope} do
      component = component_fixture(scope)

      assert {:ok, deleted_component} = ComponentRepository.delete_component(scope, component)
      assert deleted_component.id == component.id

      # Verify removal from database
      assert is_nil(Repo.get(Component, component.id))
    end

    test "returns error when component has dependencies", %{scope: scope} do
      {parent, child} = component_with_dependencies_fixture(scope)

      # Should be able to delete parent (no incoming dependencies)
      assert {:ok, _} = ComponentRepository.delete_component(scope, parent)

      # But child deletion should work since dependency is cascade deleted
      assert {:ok, _} = ComponentRepository.delete_component(scope, child)
    end
  end

  describe "list_components_with_dependencies/1" do
    test "returns components with preloaded dependencies", %{scope: scope} do
      {parent, child} = component_with_dependencies_fixture(scope)

      result = ComponentRepository.list_components_with_dependencies(scope)

      assert length(result) == 2

      parent_result = Enum.find(result, &(&1.id == parent.id))
      child_result = Enum.find(result, &(&1.id == child.id))

      assert Ecto.assoc_loaded?(parent_result.dependencies)
      assert Ecto.assoc_loaded?(parent_result.dependents)
      assert Ecto.assoc_loaded?(parent_result.outgoing_dependencies)
      assert Ecto.assoc_loaded?(parent_result.incoming_dependencies)

      assert Ecto.assoc_loaded?(child_result.dependencies)
      assert Ecto.assoc_loaded?(child_result.dependents)
    end

    test "returns empty list when no components exist", %{scope: scope} do
      result = ComponentRepository.list_components_with_dependencies(scope)
      assert result == []
    end
  end

  describe "get_component_with_dependencies/2" do
    test "returns component with preloaded dependencies", %{scope: scope} do
      {parent, _child} = component_with_dependencies_fixture(scope)

      result = ComponentRepository.get_component_with_dependencies(scope, parent.id)

      assert result.id == parent.id
      assert Ecto.assoc_loaded?(result.dependencies)
      assert Ecto.assoc_loaded?(result.dependents)
      assert Ecto.assoc_loaded?(result.outgoing_dependencies)
      assert Ecto.assoc_loaded?(result.incoming_dependencies)
    end

    test "returns nil when component doesn't exist", %{scope: scope} do
      result = ComponentRepository.get_component_with_dependencies(scope, 999)
      assert is_nil(result)
    end
  end

  describe "get_component_by_module_name/2" do
    test "returns component when module name exists", %{scope: scope} do
      component = component_fixture(scope, %{module_name: "MyApp.UniqueModule"})

      result = ComponentRepository.get_component_by_module_name(scope, "MyApp.UniqueModule")

      assert result.id == component.id
      assert result.module_name == "MyApp.UniqueModule"
    end

    test "returns nil when module name doesn't exist", %{scope: scope} do
      result = ComponentRepository.get_component_by_module_name(scope, "NonExistent.Module")
      assert is_nil(result)
    end

    test "returns nil when module name exists in different project", %{scope: scope} do
      # Create component in different project
      other_user = user_fixture()
      other_account = account_with_owner_fixture(other_user)
      other_scope = user_scope_fixture(other_user, other_account)
      other_project = project_fixture(other_scope)
      other_scope = user_scope_fixture(other_user, other_account, other_project)
      component_fixture(other_scope, %{module_name: "Other.Module"})

      result = ComponentRepository.get_component_by_module_name(scope, "Other.Module")
      assert is_nil(result)
    end
  end

  describe "list_components_by_type/2" do
    test "returns components filtered by type", %{scope: scope} do
      genserver_comp = genserver_component_fixture(scope)
      schema_comp = schema_component_fixture(scope)
      _context_comp = component_fixture(scope, %{type: :context})

      genserver_result = ComponentRepository.list_components_by_type(scope, :genserver)
      schema_result = ComponentRepository.list_components_by_type(scope, :schema)
      context_result = ComponentRepository.list_components_by_type(scope, :context)

      assert length(genserver_result) == 1
      assert hd(genserver_result).id == genserver_comp.id

      assert length(schema_result) == 1
      assert hd(schema_result).id == schema_comp.id

      assert length(context_result) == 1
    end

    test "returns empty list when no components of type exist", %{scope: scope} do
      result = ComponentRepository.list_components_by_type(scope, :registry)
      assert result == []
    end
  end

  describe "search_components_by_name/2" do
    test "returns components matching name pattern", %{scope: scope} do
      component1 = component_fixture(scope, %{name: "UserService"})
      component2 = component_fixture(scope, %{name: "UserRepository"})
      _component3 = component_fixture(scope, %{name: "OrderService"})

      result = ComponentRepository.search_components_by_name(scope, "User")

      assert length(result) == 2
      component_ids = Enum.map(result, & &1.id)
      assert component1.id in component_ids
      assert component2.id in component_ids
    end

    test "search is case insensitive", %{scope: scope} do
      component = component_fixture(scope, %{name: "UserService"})

      result = ComponentRepository.search_components_by_name(scope, "user")

      assert length(result) == 1
      assert hd(result).id == component.id
    end

    test "returns empty list when no matches found", %{scope: scope} do
      component_fixture(scope, %{name: "UserService"})

      result = ComponentRepository.search_components_by_name(scope, "NonExistent")

      assert result == []
    end

    test "handles partial matches", %{scope: scope} do
      component = component_fixture(scope, %{name: "UserManagementService"})

      result = ComponentRepository.search_components_by_name(scope, "Management")

      assert length(result) == 1
      assert hd(result).id == component.id
    end
  end
end

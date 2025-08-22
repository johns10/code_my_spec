defmodule CodeMySpec.Components.RequirementsRepositoryTest do
  use CodeMySpec.DataCase, async: true

  import CodeMySpec.ComponentsFixtures
  import CodeMySpec.ProjectsFixtures
  import CodeMySpec.UsersFixtures
  import CodeMySpec.AccountsFixtures
  import CodeMySpec.RequirementsFixtures

  alias CodeMySpec.Components.RequirementsRepository
  alias CodeMySpec.Components.Requirements.Requirement
  alias CodeMySpec.Repo

  setup do
    user = user_fixture()
    account = account_with_owner_fixture(user)
    scope = user_scope_fixture(user, account)
    project = project_fixture(scope)
    scope = user_scope_fixture(user, account, project)
    component = component_fixture(scope)

    %{scope: scope, project: project, component: component, user: user, account: account}
  end

  describe "create_requirement/3" do
    test "creates a requirement with valid data", %{scope: scope, component: component} do
      attrs = requirement_attrs()

      assert {:ok, requirement} =
               RequirementsRepository.create_requirement(scope, component, attrs)

      assert requirement.name == "design_file"
      assert requirement.type == :file_existence
      assert requirement.satisfied == false
      assert requirement.component_id == component.id
    end

    test "returns error with invalid data", %{scope: scope, component: component} do
      attrs = requirement_attrs(%{satisfied: nil})

      assert {:error, changeset} =
               RequirementsRepository.create_requirement(scope, component, attrs)

      assert changeset.errors[:satisfied]
    end
  end

  describe "get_requirement/2" do
    test "returns requirement within project scope", %{scope: scope, component: component} do
      {:ok, requirement} =
        RequirementsRepository.create_requirement(scope, component, requirement_attrs())

      result = RequirementsRepository.get_requirement(scope, requirement.id)
      assert result.id == requirement.id
    end

    test "returns nil for requirement in different project" do
      # Create requirement in original project
      user = user_fixture()
      account = account_with_owner_fixture(user)
      original_scope = user_scope_fixture(user, account)
      project = project_fixture(original_scope)
      original_scope = user_scope_fixture(user, account, project)
      original_component = component_fixture(original_scope)

      {:ok, requirement} =
        RequirementsRepository.create_requirement(
          original_scope,
          original_component,
          requirement_attrs()
        )

      # Try to access from different project
      other_user = user_fixture()
      other_account = account_with_owner_fixture(other_user)
      other_scope = user_scope_fixture(other_user, other_account)
      other_project = project_fixture(other_scope)
      other_scope = user_scope_fixture(other_user, other_account, other_project)

      result = RequirementsRepository.get_requirement(other_scope, requirement.id)
      assert result == nil
    end

    test "returns nil for non-existent requirement", %{scope: scope} do
      result = RequirementsRepository.get_requirement(scope, 999)
      assert result == nil
    end
  end

  describe "update_requirement/3" do
    test "updates requirement with valid data", %{scope: scope, component: component} do
      {:ok, requirement} =
        RequirementsRepository.create_requirement(scope, component, requirement_attrs())

      update_attrs = %{satisfied: true, details: %{reason: "File found"}}

      assert {:ok, updated} =
               RequirementsRepository.update_requirement(scope, requirement, update_attrs)

      assert updated.satisfied == true
      assert updated.details == %{reason: "File found"}
    end

    test "returns error with invalid data", %{scope: scope, component: component} do
      {:ok, requirement} =
        RequirementsRepository.create_requirement(scope, component, requirement_attrs())

      invalid_attrs = %{satisfied: nil}

      assert {:error, changeset} =
               RequirementsRepository.update_requirement(scope, requirement, invalid_attrs)

      assert changeset.errors[:satisfied]
    end
  end

  describe "delete_requirement/2" do
    test "deletes requirement", %{scope: scope, component: component} do
      {:ok, requirement} =
        RequirementsRepository.create_requirement(scope, component, requirement_attrs())

      assert {:ok, deleted} = RequirementsRepository.delete_requirement(scope, requirement)
      assert deleted.id == requirement.id
      assert RequirementsRepository.get_requirement(scope, requirement.id) == nil
    end
  end

  describe "list_requirements_for_component/2" do
    test "returns all requirements for a component", %{scope: scope, component: component} do
      {:ok, req1} =
        RequirementsRepository.create_requirement(
          scope,
          component,
          requirement_attrs(%{name: "design_file"})
        )

      {:ok, req2} =
        RequirementsRepository.create_requirement(
          scope,
          component,
          requirement_attrs(%{name: "test_file", type: :file_existence})
        )

      # Create requirement for different component
      other_component = component_fixture(scope)

      {:ok, _other_req} =
        RequirementsRepository.create_requirement(
          scope,
          other_component,
          requirement_attrs(%{name: "other_file"})
        )

      result = RequirementsRepository.list_requirements_for_component(scope, component.id)

      assert length(result) == 2
      requirement_ids = Enum.map(result, & &1.id)
      assert req1.id in requirement_ids
      assert req2.id in requirement_ids
    end

    test "returns empty list for component with no requirements", %{
      scope: scope,
      component: component
    } do
      result = RequirementsRepository.list_requirements_for_component(scope, component.id)
      assert result == []
    end

    test "respects project scope", %{scope: scope, component: component} do
      {:ok, _requirement} =
        RequirementsRepository.create_requirement(scope, component, requirement_attrs())

      # Different project scope
      other_user = user_fixture()
      other_account = account_with_owner_fixture(other_user)
      other_scope = user_scope_fixture(other_user, other_account)
      other_project = project_fixture(other_scope)
      other_scope = user_scope_fixture(other_user, other_account, other_project)

      result = RequirementsRepository.list_requirements_for_component(other_scope, component.id)
      assert result == []
    end
  end

  describe "by_satisfied_status/2" do
    test "filters requirements by satisfied status", %{scope: scope, component: component} do
      {:ok, satisfied_req} =
        RequirementsRepository.create_requirement(
          scope,
          component,
          requirement_attrs(%{satisfied: true})
        )

      {:ok, unsatisfied_req} =
        RequirementsRepository.create_requirement(
          scope,
          component,
          requirement_attrs(%{satisfied: false, name: "test_file"})
        )

      satisfied_query =
        Requirement
        |> RequirementsRepository.by_satisfied_status(true)

      satisfied_results = Repo.all(satisfied_query)

      unsatisfied_query =
        Requirement
        |> RequirementsRepository.by_satisfied_status(false)

      unsatisfied_results = Repo.all(unsatisfied_query)

      assert satisfied_req.id in Enum.map(satisfied_results, & &1.id)
      assert unsatisfied_req.id in Enum.map(unsatisfied_results, & &1.id)
    end
  end

  describe "by_requirement_name/2" do
    test "filters requirements by name", %{scope: scope, component: component} do
      {:ok, design_req} =
        RequirementsRepository.create_requirement(
          scope,
          component,
          requirement_attrs(%{name: "design_file"})
        )

      {:ok, _test_req} =
        RequirementsRepository.create_requirement(
          scope,
          component,
          requirement_attrs(%{name: "test_file"})
        )

      query =
        Requirement
        |> RequirementsRepository.by_requirement_name(:design_file)

      results = Repo.all(query)

      assert length(results) == 1
      assert hd(results).id == design_req.id
    end
  end

  describe "recreate_component_requirements/3" do
    test "replaces existing requirements with new ones", %{scope: scope, component: component} do
      # Create initial requirements
      {:ok, _old_req1} =
        RequirementsRepository.create_requirement(
          scope,
          component,
          requirement_attrs(%{name: "old_file1"})
        )

      {:ok, _old_req2} =
        RequirementsRepository.create_requirement(
          scope,
          component,
          requirement_attrs(%{name: "old_file2"})
        )

      # Define new requirements
      new_requirements = [
        requirement_attrs(%{name: "new_file1", satisfied: true}),
        requirement_attrs(%{name: "new_file2", satisfied: false})
      ]

      assert {:ok, created_requirements} =
               RequirementsRepository.recreate_component_requirements(
                 scope,
                 component,
                 new_requirements
               )

      # Check that old requirements are gone and new ones exist
      all_requirements =
        RequirementsRepository.list_requirements_for_component(scope, component.id)

      assert length(all_requirements) == 2
      assert length(created_requirements) == 2

      names = Enum.map(all_requirements, & &1.name)
      assert "new_file1" in names
      assert "new_file2" in names
      refute "old_file1" in names
      refute "old_file2" in names
    end

    test "handles empty requirements list", %{scope: scope, component: component} do
      {:ok, _req} =
        RequirementsRepository.create_requirement(scope, component, requirement_attrs())

      assert {:ok, []} =
               RequirementsRepository.recreate_component_requirements(scope, component, [])

      all_requirements =
        RequirementsRepository.list_requirements_for_component(scope, component.id)

      assert all_requirements == []
    end
  end

  describe "clear_project_requirements/1" do
    test "removes all requirements for project", %{scope: scope, component: component} do
      {:ok, _req1} =
        RequirementsRepository.create_requirement(
          scope,
          component,
          requirement_attrs(%{name: "file1"})
        )

      {:ok, _req2} =
        RequirementsRepository.create_requirement(
          scope,
          component,
          requirement_attrs(%{name: "file2"})
        )

      # Create requirement in different project (should not be affected)
      other_user = user_fixture()
      other_account = account_with_owner_fixture(other_user)
      other_scope = user_scope_fixture(other_user, other_account)
      other_project = project_fixture(other_scope)
      other_scope = user_scope_fixture(other_user, other_account, other_project)
      other_component = component_fixture(other_scope)

      {:ok, other_req} =
        RequirementsRepository.create_requirement(
          other_scope,
          other_component,
          requirement_attrs()
        )

      assert :ok = RequirementsRepository.clear_project_requirements(scope)

      # Check that requirements for this project are gone
      project_requirements =
        RequirementsRepository.list_requirements_for_component(scope, component.id)

      assert project_requirements == []

      # Check that other project's requirements remain
      other_requirements =
        RequirementsRepository.list_requirements_for_component(other_scope, other_component.id)

      assert length(other_requirements) == 1
      assert hd(other_requirements).id == other_req.id
    end
  end

  describe "components_with_unsatisfied_requirements/1" do
    test "returns components with unsatisfied requirements", %{scope: scope} do
      component1 = component_fixture(scope, %{name: "Component1"})
      component2 = component_fixture(scope, %{name: "Component2"})
      component3 = component_fixture(scope, %{name: "Component3"})

      # Component1: has unsatisfied requirement
      {:ok, _} =
        RequirementsRepository.create_requirement(
          scope,
          component1,
          requirement_attrs(%{satisfied: false})
        )

      # Component2: has only satisfied requirements
      {:ok, _} =
        RequirementsRepository.create_requirement(
          scope,
          component2,
          requirement_attrs(%{satisfied: true})
        )

      # Component3: has mixed requirements (should still appear because some are unsatisfied)
      {:ok, _} =
        RequirementsRepository.create_requirement(
          scope,
          component3,
          requirement_attrs(%{satisfied: true, name: "satisfied_req"})
        )

      {:ok, _} =
        RequirementsRepository.create_requirement(
          scope,
          component3,
          requirement_attrs(%{satisfied: false, name: "unsatisfied_req"})
        )

      result = RequirementsRepository.components_with_unsatisfied_requirements(scope)

      component_ids = Enum.map(result, & &1.id)
      assert component1.id in component_ids
      refute component2.id in component_ids
      assert component3.id in component_ids
    end

    test "returns empty list when all requirements are satisfied", %{
      scope: scope,
      component: component
    } do
      {:ok, _} =
        RequirementsRepository.create_requirement(
          scope,
          component,
          requirement_attrs(%{satisfied: true})
        )

      result = RequirementsRepository.components_with_unsatisfied_requirements(scope)
      assert result == []
    end
  end

  describe "components_ready_for_work/1" do
    test "returns components with all requirements satisfied or no requirements", %{scope: scope} do
      # No requirements
      component1 = component_fixture(scope, %{name: "Component1"})
      # All satisfied
      component2 = component_fixture(scope, %{name: "Component2"})
      # Has unsatisfied
      component3 = component_fixture(scope, %{name: "Component3"})

      # Component2: all satisfied
      {:ok, _} =
        RequirementsRepository.create_requirement(
          scope,
          component2,
          requirement_attrs(%{satisfied: true})
        )

      {:ok, _} =
        RequirementsRepository.create_requirement(
          scope,
          component2,
          requirement_attrs(%{satisfied: true, name: "another_req"})
        )

      # Component3: has unsatisfied
      {:ok, _} =
        RequirementsRepository.create_requirement(
          scope,
          component3,
          requirement_attrs(%{satisfied: false})
        )

      result = RequirementsRepository.components_ready_for_work(scope)

      component_ids = Enum.map(result, & &1.id)
      # No requirements = ready
      assert component1.id in component_ids
      # All satisfied = ready
      assert component2.id in component_ids
      # Has unsatisfied = not ready
      refute component3.id in component_ids
    end

    test "respects project scope", %{scope: scope, component: component} do
      {:ok, _} =
        RequirementsRepository.create_requirement(
          scope,
          component,
          requirement_attrs(%{satisfied: true})
        )

      # Different project
      other_user = user_fixture()
      other_account = account_with_owner_fixture(other_user)
      other_scope = user_scope_fixture(other_user, other_account)
      other_project = project_fixture(other_scope)
      other_scope = user_scope_fixture(other_user, other_account, other_project)

      result = RequirementsRepository.components_ready_for_work(other_scope)
      component_ids = Enum.map(result, & &1.id)
      refute component.id in component_ids
    end
  end
end

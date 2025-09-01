defmodule CodeMySpec.Components.RequirementsRepositoryTest do
  use CodeMySpec.DataCase, async: true

  import CodeMySpec.ComponentsFixtures
  import CodeMySpec.ProjectsFixtures
  import CodeMySpec.UsersFixtures
  import CodeMySpec.AccountsFixtures
  import CodeMySpec.RequirementsFixtures

  alias CodeMySpec.Components.RequirementsRepository

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

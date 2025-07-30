defmodule CodeMySpec.Components.DependencyRepositoryTest do
  use CodeMySpec.DataCase, async: true

  import CodeMySpec.ComponentsFixtures
  import CodeMySpec.UsersFixtures

  alias CodeMySpec.Components.{DependencyRepository, Dependency}
  alias CodeMySpec.Repo

  describe "list_dependencies/1" do
    test "returns all dependencies for components in scope project" do
      scope = full_scope_fixture()
      
      # Create components and dependencies in the scoped project
      source = component_fixture(scope, %{name: "Source", type: :context})
      target = component_fixture(scope, %{name: "Target", type: :schema})
      
      {:ok, dependency} = DependencyRepository.create_dependency(%{
        source_component_id: source.id,
        target_component_id: target.id,
        type: :call
      })

      # Create dependency in different project that should not be returned
      other_scope = full_scope_fixture()
      other_source = component_fixture(other_scope, %{name: "OtherSource"})
      other_target = component_fixture(other_scope, %{name: "OtherTarget"})
      
      {:ok, _other_dependency} = DependencyRepository.create_dependency(%{
        source_component_id: other_source.id,
        target_component_id: other_target.id,
        type: :import
      })

      dependencies = DependencyRepository.list_dependencies(scope)

      assert length(dependencies) == 1
      assert List.first(dependencies).id == dependency.id
      assert Ecto.assoc_loaded?(List.first(dependencies).source_component)
      assert Ecto.assoc_loaded?(List.first(dependencies).target_component)
    end

    test "returns empty list when no dependencies exist in scope" do
      scope = full_scope_fixture()
      
      dependencies = DependencyRepository.list_dependencies(scope)

      assert dependencies == []
    end

    test "preloads source and target components" do
      scope = full_scope_fixture()
      source = component_fixture(scope)
      target = component_fixture(scope)
      
      {:ok, _dependency} = DependencyRepository.create_dependency(%{
        source_component_id: source.id,
        target_component_id: target.id,
        type: :use
      })

      [dependency] = DependencyRepository.list_dependencies(scope)

      assert dependency.source_component.name == source.name
      assert dependency.target_component.name == target.name
    end
  end

  describe "get_dependency!/2" do
    test "returns dependency with preloaded associations when exists in scope" do
      scope = full_scope_fixture()
      source = component_fixture(scope)
      target = component_fixture(scope)
      
      {:ok, created_dependency} = DependencyRepository.create_dependency(%{
        source_component_id: source.id,
        target_component_id: target.id,
        type: :alias
      })

      dependency = DependencyRepository.get_dependency!(scope, created_dependency.id)

      assert dependency.id == created_dependency.id
      assert dependency.type == :alias
      assert Ecto.assoc_loaded?(dependency.source_component)
      assert Ecto.assoc_loaded?(dependency.target_component)
      assert dependency.source_component.name == source.name
      assert dependency.target_component.name == target.name
    end

    test "raises Ecto.NoResultsError when dependency not found" do
      scope = full_scope_fixture()

      assert_raise Ecto.NoResultsError, fn ->
        DependencyRepository.get_dependency!(scope, 999)
      end
    end

    test "raises Ecto.NoResultsError when dependency exists but not in scope" do
      scope = full_scope_fixture()
      other_scope = full_scope_fixture()
      
      source = component_fixture(other_scope)
      target = component_fixture(other_scope)
      
      {:ok, dependency} = DependencyRepository.create_dependency(%{
        source_component_id: source.id,
        target_component_id: target.id,
        type: :call
      })

      assert_raise Ecto.NoResultsError, fn ->
        DependencyRepository.get_dependency!(scope, dependency.id)
      end
    end
  end

  describe "create_dependency/1" do
    test "creates dependency with valid attributes" do
      scope = full_scope_fixture()
      source = component_fixture(scope)
      target = component_fixture(scope)

      attrs = %{
        source_component_id: source.id,
        target_component_id: target.id,
        type: :require
      }

      assert {:ok, dependency} = DependencyRepository.create_dependency(attrs)
      assert dependency.source_component_id == source.id
      assert dependency.target_component_id == target.id
      assert dependency.type == :require

      # Verify it was persisted to database
      persisted = Repo.get!(Dependency, dependency.id)
      assert persisted.source_component_id == source.id
    end

    test "returns error changeset with missing required fields" do
      assert {:error, changeset} = DependencyRepository.create_dependency(%{})
      
      assert errors_on(changeset) == %{
        source_component_id: ["can't be blank"],
        target_component_id: ["can't be blank"],
        type: ["can't be blank"]
      }
    end

    test "returns error changeset when source and target are the same" do
      scope = full_scope_fixture()
      component = component_fixture(scope)

      attrs = %{
        source_component_id: component.id,
        target_component_id: component.id,
        type: :call
      }

      assert {:error, changeset} = DependencyRepository.create_dependency(attrs)
      assert "cannot depend on itself" in errors_on(changeset).target_component_id
    end

    test "returns error changeset with invalid foreign key" do
      attrs = %{
        source_component_id: 999,
        target_component_id: 998,
        type: :import
      }

      assert {:error, changeset} = DependencyRepository.create_dependency(attrs)
      assert changeset.errors != []
    end

    test "returns error changeset for duplicate dependency" do
      scope = full_scope_fixture()
      source = component_fixture(scope)
      target = component_fixture(scope)

      attrs = %{
        source_component_id: source.id,
        target_component_id: target.id,
        type: :call
      }

      assert {:ok, _dependency} = DependencyRepository.create_dependency(attrs)
      assert {:error, changeset} = DependencyRepository.create_dependency(attrs)
      
      assert changeset.errors != []
    end
  end

  describe "delete_dependency/1" do
    test "deletes dependency successfully" do
      scope = full_scope_fixture()
      source = component_fixture(scope)
      target = component_fixture(scope)
      
      {:ok, dependency} = DependencyRepository.create_dependency(%{
        source_component_id: source.id,
        target_component_id: target.id,
        type: :other
      })

      assert {:ok, deleted_dependency} = DependencyRepository.delete_dependency(dependency)
      assert deleted_dependency.id == dependency.id

      # Verify it was removed from database
      assert Repo.get(Dependency, dependency.id) == nil
    end

    test "handles stale dependency deletion gracefully" do
      scope = full_scope_fixture()
      source = component_fixture(scope)
      target = component_fixture(scope)
      
      {:ok, dependency} = DependencyRepository.create_dependency(%{
        source_component_id: source.id,
        target_component_id: target.id,
        type: :use
      })

      # Delete the dependency directly to make it stale
      Repo.delete!(dependency)

      # Attempting to delete the stale dependency should fail with appropriate error
      assert_raise Ecto.StaleEntryError, fn ->
        DependencyRepository.delete_dependency(dependency)
      end
    end
  end

  describe "validate_dependency_graph/1" do
    test "returns :ok when no circular dependencies exist" do
      scope = full_scope_fixture()
      
      comp_a = component_fixture(scope, %{name: "A"})
      comp_b = component_fixture(scope, %{name: "B"})
      comp_c = component_fixture(scope, %{name: "C"})

      # Create linear dependencies: A -> B -> C
      {:ok, _dep1} = DependencyRepository.create_dependency(%{
        source_component_id: comp_a.id,
        target_component_id: comp_b.id,
        type: :call
      })

      {:ok, _dep2} = DependencyRepository.create_dependency(%{
        source_component_id: comp_b.id,
        target_component_id: comp_c.id,
        type: :import
      })

      assert DependencyRepository.validate_dependency_graph(scope) == :ok
    end

    test "returns error with circular dependency details when cycle exists" do
      scope = full_scope_fixture()
      
      comp_a = component_fixture(scope, %{name: "ComponentA"})
      comp_b = component_fixture(scope, %{name: "ComponentB"})

      # Create circular dependency: A -> B and B -> A
      {:ok, _dep1} = DependencyRepository.create_dependency(%{
        source_component_id: comp_a.id,
        target_component_id: comp_b.id,
        type: :call
      })

      {:ok, _dep2} = DependencyRepository.create_dependency(%{
        source_component_id: comp_b.id,
        target_component_id: comp_a.id,
        type: :use
      })

      assert {:error, cycles} = DependencyRepository.validate_dependency_graph(scope)
      assert length(cycles) == 2  # Both directions detected
      
      cycle = List.first(cycles)
      assert Map.has_key?(cycle, :components)
      assert Map.has_key?(cycle, :path)
      assert length(cycle.components) == 2
      assert length(cycle.path) == 2
    end

    test "ignores circular dependencies from other projects" do
      scope = full_scope_fixture()
      other_scope = full_scope_fixture()
      
      # Create circular dependency in other project
      other_a = component_fixture(other_scope, %{name: "OtherA"})
      other_b = component_fixture(other_scope, %{name: "OtherB"})

      {:ok, _dep1} = DependencyRepository.create_dependency(%{
        source_component_id: other_a.id,
        target_component_id: other_b.id,
        type: :call
      })

      {:ok, _dep2} = DependencyRepository.create_dependency(%{
        source_component_id: other_b.id,
        target_component_id: other_a.id,
        type: :use
      })

      # Current scope should be clean
      assert DependencyRepository.validate_dependency_graph(scope) == :ok
    end
  end

  describe "resolve_dependency_order/1" do
    test "returns components ordered by dependency count" do
      scope = full_scope_fixture()
      
      # Create components with different dependency counts
      no_deps = component_fixture(scope, %{name: "NoDeps"})
      one_dep = component_fixture(scope, %{name: "OneDep"})
      two_deps = component_fixture(scope, %{name: "TwoDeps"})
      target = component_fixture(scope, %{name: "Target"})

      # Create dependencies: one_dep -> target, two_deps -> target, two_deps -> no_deps
      {:ok, _dep1} = DependencyRepository.create_dependency(%{
        source_component_id: one_dep.id,
        target_component_id: target.id,
        type: :call
      })

      {:ok, _dep2} = DependencyRepository.create_dependency(%{
        source_component_id: two_deps.id,
        target_component_id: target.id,
        type: :import
      })

      {:ok, _dep3} = DependencyRepository.create_dependency(%{
        source_component_id: two_deps.id,
        target_component_id: no_deps.id,
        type: :use
      })

      assert {:ok, components} = DependencyRepository.resolve_dependency_order(scope)
      
      component_names = Enum.map(components, & &1.name)
      
      # Components with fewer dependencies should come first
      no_deps_index = Enum.find_index(component_names, &(&1 == "NoDeps"))
      one_dep_index = Enum.find_index(component_names, &(&1 == "OneDep"))
      two_deps_index = Enum.find_index(component_names, &(&1 == "TwoDeps"))
      
      assert no_deps_index < one_dep_index
      assert one_dep_index < two_deps_index
    end

    test "returns all components in scope even with no dependencies" do
      scope = full_scope_fixture()
      
      comp_a = component_fixture(scope, %{name: "A"})
      comp_b = component_fixture(scope, %{name: "B"})
      comp_c = component_fixture(scope, %{name: "C"})

      assert {:ok, components} = DependencyRepository.resolve_dependency_order(scope)
      
      component_ids = Enum.map(components, & &1.id) |> Enum.sort()
      expected_ids = [comp_a.id, comp_b.id, comp_c.id] |> Enum.sort()
      
      assert component_ids == expected_ids
    end

    test "only returns components from the scoped project" do
      scope = full_scope_fixture()
      other_scope = full_scope_fixture()
      
      _in_scope = component_fixture(scope, %{name: "InScope"})
      _out_of_scope = component_fixture(other_scope, %{name: "OutOfScope"})

      assert {:ok, components} = DependencyRepository.resolve_dependency_order(scope)
      
      assert length(components) == 1
      assert List.first(components).name == "InScope"
    end
  end
end

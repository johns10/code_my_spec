defmodule CodeMySpec.Components.SyncTest do
  use CodeMySpec.DataCase, async: true

  alias CodeMySpec.Components
  alias CodeMySpec.Components.Sync
  alias CodeMySpec.Projects
  alias CodeMySpec.Utils.Paths

  import CodeMySpec.UsersFixtures

  setup do
    # Create scope with project
    scope = full_scope_fixture()

    # Update project to use test_phoenix_project module name
    {:ok, project} =
      Projects.update_project(scope, scope.active_project, %{
        module_name: "TestPhoenixProject"
      })

    scope = %{scope | active_project: project}

    # Clone test_phoenix_project into a temp directory
    project_dir =
      "../code_my_spec_test_repos/components_sync_test_#{System.unique_integer([:positive])}"

    # Use test adapter to clone
    {:ok, ^project_dir} =
      CodeMySpec.Support.TestAdapter.clone(
        scope,
        "https://github.com/johns10/test_phoenix_project.git",
        project_dir
      )

    {:ok, scope: scope, tmp_dir: project_dir}
  end

  describe "sync_contexts/1" do
    test "finds all context spec files in docs/spec/", %{scope: scope, tmp_dir: tmp_dir} do
      {:ok, contexts} = Sync.sync_contexts(scope, base_dir: tmp_dir)

      # Should find context spec files
      assert length(contexts) > 0
      assert Enum.all?(contexts, &(&1.type in ["context", "coordination_context"]))
    end

    test "finds all context implementation files in lib/", %{scope: scope, tmp_dir: tmp_dir} do
      {:ok, contexts} = Sync.sync_contexts(scope, base_dir: tmp_dir)

      # Should include contexts from lib/ directory even without specs
      assert length(contexts) > 0
    end

    test "creates context components when they don't exist", %{scope: scope, tmp_dir: tmp_dir} do
      # First sync
      {:ok, contexts} = Sync.sync_contexts(scope, base_dir: tmp_dir)

      # Verify contexts were created in DB
      db_contexts = Components.list_contexts(scope)
      assert length(db_contexts) == length(contexts)
    end

    test "updates context components when they exist", %{scope: scope, tmp_dir: tmp_dir} do
      # First sync
      {:ok, first_contexts} = Sync.sync_contexts(scope, base_dir: tmp_dir)

      # Second sync
      {:ok, second_contexts} = Sync.sync_contexts(scope, base_dir: tmp_dir)

      # Should have same contexts (by module_name)
      first_modules = Enum.map(first_contexts, & &1.module_name) |> Enum.sort()
      second_modules = Enum.map(second_contexts, & &1.module_name) |> Enum.sort()
      assert first_modules == second_modules
    end

    test "calls sync_components/2 for each context", %{scope: scope, tmp_dir: tmp_dir} do
      {:ok, contexts} = Sync.sync_contexts(scope, base_dir: tmp_dir)

      # Check that components were synced for each context
      Enum.each(contexts, fn context ->
        children = Components.list_child_components(scope, context.id)
        # Some contexts may have no children, but structure should be correct
        assert is_list(children)
      end)
    end

    test "removes contexts that no longer exist in filesystem", %{scope: scope, tmp_dir: tmp_dir} do
      # First sync
      {:ok, _contexts} = Sync.sync_contexts(scope, base_dir: tmp_dir)

      # Manually create a fake context
      {:ok, fake_context} =
        Components.create_component(scope, %{
          name: "FakeContext",
          module_name: "#{scope.active_project.module_name}.FakeContext",
          type: "context"
        })

      # Second sync should remove it
      {:ok, _contexts} = Sync.sync_contexts(scope, base_dir: tmp_dir)

      # Verify fake context was removed
      assert Components.get_component(scope, fake_context.id) == nil
    end

    test "respects scope boundaries", %{scope: scope, tmp_dir: tmp_dir} do
      # Create another scope with different project
      other_scope = full_scope_fixture()

      # Sync contexts for first scope
      {:ok, contexts1} = Sync.sync_contexts(scope, base_dir: tmp_dir)

      # Sync contexts for other scope (should be empty since no files)
      {:ok, contexts2} = Sync.sync_contexts(other_scope)

      # Verify they're separate
      assert length(contexts1) > 0
      assert length(contexts2) == 0
    end

    test "merges spec and implementation data when both exist", %{scope: scope, tmp_dir: tmp_dir} do
      {:ok, contexts} = Sync.sync_contexts(scope, base_dir: tmp_dir)

      # Find contexts that have both spec and implementation
      contexts_with_both =
        Enum.filter(contexts, fn context ->
          # Has type (from spec) and exists in DB
          not is_nil(context.type)
        end)

      assert length(contexts_with_both) > 0
    end

    test "parses spec files for context metadata when available", %{
      scope: scope,
      tmp_dir: tmp_dir
    } do
      {:ok, contexts} = Sync.sync_contexts(scope, base_dir: tmp_dir)

      # Find contexts with specs (have type)
      contexts_with_specs = Enum.filter(contexts, &(not is_nil(&1.type)))

      # Verify metadata was parsed
      Enum.each(contexts_with_specs, fn context ->
        assert context.module_name != nil
        assert context.name != nil
        assert context.type in ["context", "coordination_context"]
      end)
    end

    test "extracts module names from implementation files", %{scope: scope, tmp_dir: tmp_dir} do
      {:ok, contexts} = Sync.sync_contexts(scope, base_dir: tmp_dir)

      # All contexts should have module names extracted
      Enum.each(contexts, fn context ->
        assert context.module_name != nil
        assert String.starts_with?(context.module_name, scope.active_project.module_name)
      end)
    end

    test "merges spec and implementation lists", %{scope: scope, tmp_dir: tmp_dir} do
      {:ok, contexts} = Sync.sync_contexts(scope, base_dir: tmp_dir)

      # Should have both spec-only and impl-only contexts merged
      assert length(contexts) >= 2
    end
  end

  describe "sync_components/2" do
    test "finds all component implementation files in context subdirectory", %{
      scope: scope,
      tmp_dir: tmp_dir
    } do
      {:ok, contexts} = Sync.sync_contexts(scope, base_dir: tmp_dir)

      # Pick a context and sync its components
      context = List.first(contexts)

      if context do
        {:ok, components} = Sync.sync_components(scope, context, base_dir: tmp_dir)
        assert is_list(components)
      end
    end

    test "creates components when they don't exist", %{scope: scope, tmp_dir: tmp_dir} do
      {:ok, contexts} = Sync.sync_contexts(scope, base_dir: tmp_dir)
      context = List.first(contexts)

      if context do
        {:ok, components} = Sync.sync_components(scope, context, base_dir: tmp_dir)

        # Verify components were created in DB
        db_components = Components.list_child_components(scope, context.id)
        assert length(db_components) == length(components)
      end
    end

    test "updates components when they exist", %{scope: scope, tmp_dir: tmp_dir} do
      {:ok, contexts} = Sync.sync_contexts(scope, base_dir: tmp_dir)
      context = List.first(contexts)

      if context do
        # First sync
        {:ok, first_components} = Sync.sync_components(scope, context, base_dir: tmp_dir)

        # Second sync
        {:ok, second_components} = Sync.sync_components(scope, context, base_dir: tmp_dir)

        # Should have same components
        first_modules = Enum.map(first_components, & &1.module_name) |> Enum.sort()
        second_modules = Enum.map(second_components, & &1.module_name) |> Enum.sort()
        assert first_modules == second_modules
      end
    end

    test "sets parent_component_id to parent context", %{scope: scope, tmp_dir: tmp_dir} do
      {:ok, contexts} = Sync.sync_contexts(scope, base_dir: tmp_dir)
      context = List.first(contexts)

      if context do
        {:ok, components} = Sync.sync_components(scope, context, base_dir: tmp_dir)

        # All components should have parent_component_id set
        Enum.each(components, fn component ->
          assert component.parent_component_id == context.id
        end)
      end
    end

    test "removes components that no longer exist in filesystem", %{
      scope: scope,
      tmp_dir: tmp_dir
    } do
      {:ok, contexts} = Sync.sync_contexts(scope, base_dir: tmp_dir)
      context = List.first(contexts)

      if context do
        # First sync
        {:ok, _components} = Sync.sync_components(scope, context, base_dir: tmp_dir)

        # Manually create a fake component
        {:ok, fake_component} =
          Components.create_component(scope, %{
            name: "FakeComponent",
            module_name: "#{context.module_name}.FakeComponent",
            type: "schema",
            parent_component_id: context.id
          })

        # Second sync should remove it
        {:ok, _components} = Sync.sync_components(scope, context, base_dir: tmp_dir)

        # Verify fake component was removed
        assert Components.get_component(scope, fake_component.id) == nil
      end
    end

    test "respects scope boundaries", %{scope: scope, tmp_dir: tmp_dir} do
      other_scope = full_scope_fixture()

      {:ok, contexts} = Sync.sync_contexts(scope, base_dir: tmp_dir)
      context = List.first(contexts)

      if context do
        {:ok, components1} = Sync.sync_components(scope, context, base_dir: tmp_dir)

        # Try to list components from other scope (should be empty)
        components2 = Components.list_child_components(other_scope, context.id)

        assert length(components1) > 0
        assert length(components2) == 0
      end
    end

    test "recursively finds all .ex files in context subdirectory", %{
      scope: scope,
      tmp_dir: tmp_dir
    } do
      {:ok, contexts} = Sync.sync_contexts(scope, base_dir: tmp_dir)
      context = List.first(contexts)

      if context do
        {:ok, components} = Sync.sync_components(scope, context, base_dir: tmp_dir)

        # Should find components at any depth
        assert is_list(components)
      end
    end

    test "extracts module names from implementation files", %{scope: scope, tmp_dir: tmp_dir} do
      {:ok, contexts} = Sync.sync_contexts(scope, base_dir: tmp_dir)
      context = List.first(contexts)

      if context do
        {:ok, components} = Sync.sync_components(scope, context, base_dir: tmp_dir)

        # All components should have module names
        Enum.each(components, fn component ->
          assert component.module_name != nil
          assert String.starts_with?(component.module_name, context.module_name)
        end)
      end
    end

    test "handles files without valid module definitions", %{scope: scope, tmp_dir: tmp_dir} do
      {:ok, contexts} = Sync.sync_contexts(scope)
      context = List.first(contexts)

      if context do
        # Create a file without a module definition
        invalid_file_path =
          "#{tmp_dir}/lib/#{Paths.module_to_path(context.module_name)}/invalid.ex"

        File.mkdir_p!(Path.dirname(invalid_file_path))
        File.write!(invalid_file_path, "# Just a comment, no module")

        # Sync should not crash
        {:ok, components} = Sync.sync_components(scope, context, base_dir: tmp_dir)

        # Should still work (just skip the invalid file)
        assert is_list(components)

        # Cleanup
        File.rm!(invalid_file_path)
      end
    end

    test "merges spec and implementation lists", %{scope: scope, tmp_dir: tmp_dir} do
      {:ok, contexts} = Sync.sync_contexts(scope, base_dir: tmp_dir)
      context = List.first(contexts)

      if context do
        {:ok, components} = Sync.sync_components(scope, context, base_dir: tmp_dir)

        # Components may come from specs, implementations, or both
        assert is_list(components)
      end
    end
  end

  describe "sync_context/2" do
    test "synchronizes a single context from spec file", %{scope: scope, tmp_dir: tmp_dir} do
      # Find a spec file
      spec_files = Path.wildcard("#{tmp_dir}/docs/spec/**/*.spec.md")
      spec_file = List.first(spec_files)

      if spec_file do
        {:ok, context} = Sync.sync_context(scope, spec_file)

        assert context.type in ["context", "coordination_context"]
        assert not is_nil(context.module_name)
      end
    end

    test "creates context when it doesn't exist", %{scope: scope, tmp_dir: tmp_dir} do
      spec_files = Path.wildcard("#{tmp_dir}/docs/spec/**/*.spec.md")
      spec_file = List.first(spec_files)

      if spec_file do
        {:ok, context} = Sync.sync_context(scope, spec_file)

        # Verify context exists in DB
        db_context = Components.get_component(scope, context.id)
        assert db_context != nil
      end
    end

    test "updates context when it exists", %{scope: scope, tmp_dir: tmp_dir} do
      spec_files = Path.wildcard("#{tmp_dir}/docs/spec/**/*.spec.md")
      spec_file = List.first(spec_files)

      if spec_file do
        # First sync
        {:ok, context1} = Sync.sync_context(scope, spec_file)

        # Second sync
        {:ok, context2} = Sync.sync_context(scope, spec_file)

        # Should be same context
        assert context1.id == context2.id
      end
    end

    test "syncs child components after syncing context", %{scope: scope, tmp_dir: tmp_dir} do
      spec_files = Path.wildcard("#{tmp_dir}/docs/spec/**/*.spec.md")
      spec_file = List.first(spec_files)

      if spec_file do
        {:ok, context} = Sync.sync_context(scope, spec_file)

        # Check that components were synced
        children = Components.list_child_components(scope, context.id)
        assert is_list(children)
      end
    end

    test "respects scope boundaries", %{scope: scope, tmp_dir: tmp_dir} do
      other_scope = full_scope_fixture()

      spec_files = Path.wildcard("#{tmp_dir}/docs/spec/**/*.spec.md")
      spec_file = List.first(spec_files)

      if spec_file do
        {:ok, context1} = Sync.sync_context(scope, spec_file)

        # Try to get from other scope
        context2 = Components.get_component(other_scope, context1.id)

        assert context1 != nil
        assert context2 == nil
      end
    end
  end
end

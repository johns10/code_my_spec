defmodule CodeMySpec.McpServers.Architecture.Tools.ReviewArchitectureDesignTest do
  use ExUnit.Case, async: false

  alias CodeMySpec.McpServers.Architecture.Tools.ReviewArchitectureDesign
  alias Hermes.Server.Frame

  import CodeMySpec.UsersFixtures
  import CodeMySpec.StoriesFixtures
  import CodeMySpec.ComponentsFixtures
  import CodeMySpec.DependencyFixtures

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(CodeMySpec.Repo)
  end

  describe "execute/2" do
    test "returns review prompt with architecture metrics" do
      scope = full_scope_fixture()

      # Create some components
      component_fixture(scope, %{module_name: "MyApp.UserController", type: "controller"})
      component_fixture(scope, %{module_name: "MyApp.Accounts", type: "context"})

      frame = %Frame{assigns: %{current_scope: scope}}

      {:reply, response, _frame} = ReviewArchitectureDesign.execute(%{}, frame)

      assert %Hermes.Server.Response{type: :tool} = response
      assert [%{"type" => "text", "text" => prompt}] = response.content

      assert prompt =~ "Architecture Design Review"
      assert prompt =~ "Total Components: 2"
      assert prompt =~ "Surface Components: 1"
      assert prompt =~ "Domain Components: 1"
    end

    test "references architecture view files" do
      scope = full_scope_fixture()
      frame = %Frame{assigns: %{current_scope: scope}}

      {:reply, response, _frame} = ReviewArchitectureDesign.execute(%{}, frame)

      assert [%{"type" => "text", "text" => prompt}] = response.content

      assert prompt =~ "docs/architecture/overview.md"
      assert prompt =~ "docs/architecture/dependency_graph.mmd"
      assert prompt =~ "docs/architecture/namespace_hierarchy.md"
    end

    test "shows unsatisfied stories count" do
      scope = full_scope_fixture()

      # Create unsatisfied stories (no component_id)
      story_fixture(scope, %{title: "Story 1"})
      story_fixture(scope, %{title: "Story 2"})
      story_fixture(scope, %{title: "Story 3"})

      frame = %Frame{assigns: %{current_scope: scope}}

      {:reply, response, _frame} = ReviewArchitectureDesign.execute(%{}, frame)

      assert [%{"type" => "text", "text" => prompt}] = response.content

      assert prompt =~ "3 stories without assigned components"
      assert prompt =~ "Story 1"
      assert prompt =~ "Story 2"
      assert prompt =~ "Story 3"
    end

    test "handles case with no unsatisfied stories" do
      scope = full_scope_fixture()

      component = component_fixture(scope, %{module_name: "MyApp.Feature", type: "context"})

      # Create satisfied story (has component_id)
      story_fixture(scope, %{title: "Completed", component_id: component.id})

      frame = %Frame{assigns: %{current_scope: scope}}

      {:reply, response, _frame} = ReviewArchitectureDesign.execute(%{}, frame)

      assert [%{"type" => "text", "text" => prompt}] = response.content

      assert prompt =~ "0 stories without assigned components"
      assert prompt =~ "All stories have been assigned to components ✅"
    end

    test "shows component organization by type" do
      scope = full_scope_fixture()

      component_fixture(scope, %{module_name: "MyApp.UserController", type: "controller"})
      component_fixture(scope, %{module_name: "MyApp.DashboardLive", type: "liveview"})
      component_fixture(scope, %{module_name: "MyApp.Accounts", type: "context"})
      component_fixture(scope, %{module_name: "MyApp.Accounts.User", type: "schema"})

      frame = %Frame{assigns: %{current_scope: scope}}

      {:reply, response, _frame} = ReviewArchitectureDesign.execute(%{}, frame)

      assert [%{"type" => "text", "text" => prompt}] = response.content

      # Match with markdown formatting
      assert prompt =~ "**Controllers** (1):"
      assert prompt =~ "UserController"
      assert prompt =~ "**Liveviews** (1):"
      assert prompt =~ "DashboardLive"
      assert prompt =~ "**Contexts** (1):"
      assert prompt =~ "Accounts"
      assert prompt =~ "**Schemas** (1):"
      assert prompt =~ "User"
    end

    test "detects circular dependencies" do
      scope = full_scope_fixture()

      comp_a = component_fixture(scope, %{module_name: "MyApp.A", type: "context"})
      comp_b = component_fixture(scope, %{module_name: "MyApp.B", type: "context"})

      # Create circular dependency (A->B and B->A creates 2 bidirectional deps)
      circular_dependency_fixture(scope, comp_a, comp_b)

      frame = %Frame{assigns: %{current_scope: scope}}

      {:reply, response, _frame} = ReviewArchitectureDesign.execute(%{}, frame)

      assert [%{"type" => "text", "text" => prompt}] = response.content

      assert prompt =~ "Circular Dependencies: 2 ❌"
      assert prompt =~ "circular dependencies detected"
    end

    test "shows healthy dependencies when no cycles" do
      scope = full_scope_fixture()

      comp_a = component_fixture(scope, %{module_name: "MyApp.A", type: "controller"})
      comp_b = component_fixture(scope, %{module_name: "MyApp.B", type: "context"})

      # One-way dependency (healthy)
      dependency_fixture(scope, comp_a, comp_b)

      frame = %Frame{assigns: %{current_scope: scope}}

      {:reply, response, _frame} = ReviewArchitectureDesign.execute(%{}, frame)

      assert [%{"type" => "text", "text" => prompt}] = response.content

      assert prompt =~ "Circular Dependencies: 0 ✅"
      assert prompt =~ "No circular dependencies found ✅"
      assert prompt =~ "Dependency graph is healthy"
    end

    test "includes review questions about surface-to-domain separation" do
      scope = full_scope_fixture()
      frame = %Frame{assigns: %{current_scope: scope}}

      {:reply, response, _frame} = ReviewArchitectureDesign.execute(%{}, frame)

      assert [%{"type" => "text", "text" => prompt}] = response.content

      assert prompt =~ "Surface-to-Domain Separation"
      assert prompt =~ "surface components (controllers, liveviews, CLI)"
      assert prompt =~ "Do surface components delegate to contexts"
    end

    test "includes review questions about dependency flow" do
      scope = full_scope_fixture()
      frame = %Frame{assigns: %{current_scope: scope}}

      {:reply, response, _frame} = ReviewArchitectureDesign.execute(%{}, frame)

      assert [%{"type" => "text", "text" => prompt}] = response.content

      assert prompt =~ "Dependency Flow"
      assert prompt =~ "dependencies flow inward (surface → domain)"
      assert prompt =~ "domain → surface dependencies"
    end

    test "includes review questions about component responsibilities" do
      scope = full_scope_fixture()
      frame = %Frame{assigns: %{current_scope: scope}}

      {:reply, response, _frame} = ReviewArchitectureDesign.execute(%{}, frame)

      assert [%{"type" => "text", "text" => prompt}] = response.content

      assert prompt =~ "Component Responsibilities"
      assert prompt =~ "clear, focused responsibility"
      assert prompt =~ "overlapping or unclear purposes"
    end

    test "includes next steps for unsatisfied stories" do
      scope = full_scope_fixture()

      story_fixture(scope, %{title: "Unmapped story"})

      frame = %Frame{assigns: %{current_scope: scope}}

      {:reply, response, _frame} = ReviewArchitectureDesign.execute(%{}, frame)

      assert [%{"type" => "text", "text" => prompt}] = response.content

      assert prompt =~ "Next Steps"
      assert prompt =~ "Mapping the 1 unsatisfied stories to surface components"
    end

    test "counts surface vs domain components correctly" do
      scope = full_scope_fixture()

      # Surface components
      component_fixture(scope, %{module_name: "MyApp.UserController", type: "controller"})
      component_fixture(scope, %{module_name: "MyApp.DashboardLive", type: "liveview"})
      component_fixture(scope, %{module_name: "MyApp.CLI.Export", type: "cli"})
      component_fixture(scope, %{module_name: "MyApp.EmailWorker", type: "worker"})

      # Domain components
      component_fixture(scope, %{module_name: "MyApp.Accounts", type: "context"})
      component_fixture(scope, %{module_name: "MyApp.Accounts.User", type: "schema"})
      component_fixture(scope, %{module_name: "MyApp.Accounts.Repository", type: "repository"})

      frame = %Frame{assigns: %{current_scope: scope}}

      {:reply, response, _frame} = ReviewArchitectureDesign.execute(%{}, frame)

      assert [%{"type" => "text", "text" => prompt}] = response.content

      assert prompt =~ "Surface Components: 4"
      assert prompt =~ "Domain Components: 3"
      assert prompt =~ "Contexts: 1"
    end

    test "detects orphaned components" do
      scope = full_scope_fixture()

      # Orphaned component (no dependencies, not a context)
      component_fixture(scope, %{module_name: "MyApp.Orphan", type: "schema"})

      # Connected components
      comp_a = component_fixture(scope, %{module_name: "MyApp.A", type: "controller"})
      comp_b = component_fixture(scope, %{module_name: "MyApp.B", type: "context"})
      dependency_fixture(scope, comp_a, comp_b)

      frame = %Frame{assigns: %{current_scope: scope}}

      {:reply, response, _frame} = ReviewArchitectureDesign.execute(%{}, frame)

      assert [%{"type" => "text", "text" => prompt}] = response.content

      assert prompt =~ "Orphaned Components: 1 ⚠️"
    end

    test "handles empty architecture gracefully" do
      scope = full_scope_fixture()
      frame = %Frame{assigns: %{current_scope: scope}}

      {:reply, response, _frame} = ReviewArchitectureDesign.execute(%{}, frame)

      assert [%{"type" => "text", "text" => prompt}] = response.content

      assert prompt =~ "Total Components: 0"
      assert prompt =~ "No components exist yet"
      assert prompt =~ "Start by mapping user stories to surface components"
    end

    test "truncates long lists to 5 items" do
      scope = full_scope_fixture()

      # Create 7 unsatisfied stories
      for i <- 1..7 do
        story_fixture(scope, %{title: "Story #{i}"})
      end

      frame = %Frame{assigns: %{current_scope: scope}}

      {:reply, response, _frame} = ReviewArchitectureDesign.execute(%{}, frame)

      assert [%{"type" => "text", "text" => prompt}] = response.content

      # Should show first 5 stories
      assert prompt =~ "Story 1"
      assert prompt =~ "Story 5"
      # Should mention there are more
      assert prompt =~ "and 2 more"
    end

    test "shows component dependency counts in organization" do
      scope = full_scope_fixture()

      controller =
        component_fixture(scope, %{module_name: "MyApp.UserController", type: "controller"})

      context1 = component_fixture(scope, %{module_name: "MyApp.Accounts", type: "context"})
      context2 = component_fixture(scope, %{module_name: "MyApp.Auth", type: "context"})

      # Controller depends on 2 contexts
      dependency_fixture(scope, controller, context1)
      dependency_fixture(scope, controller, context2)

      frame = %Frame{assigns: %{current_scope: scope}}

      {:reply, response, _frame} = ReviewArchitectureDesign.execute(%{}, frame)

      assert [%{"type" => "text", "text" => prompt}] = response.content

      assert prompt =~ "UserController"
      assert prompt =~ "2 dependencies"
    end

    test "returns error for invalid scope" do
      frame = %Frame{assigns: %{}}

      {:reply, response, _frame} = ReviewArchitectureDesign.execute(%{}, frame)

      assert response.type == :tool
      assert response.isError == true
    end
  end
end

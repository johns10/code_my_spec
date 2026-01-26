defmodule CodeMySpec.MCPServers.Architecture.Tools.StartArchitectureDesignTest do
  use ExUnit.Case, async: false

  alias CodeMySpec.MCPServers.Architecture.Tools.StartArchitectureDesign
  alias Hermes.Server.Frame

  import CodeMySpec.UsersFixtures
  import CodeMySpec.StoriesFixtures
  import CodeMySpec.ComponentsFixtures
  import CodeMySpec.DependencyFixtures

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(CodeMySpec.Repo)
  end

  describe "execute/2" do
    test "returns prompt with unsatisfied stories" do
      scope = full_scope_fixture()

      story_fixture(scope, %{
        title: "User can view dashboard",
        description: "As a user, I want to see a dashboard with key metrics",
        acceptance_criteria: [
          "Dashboard loads within 2 seconds",
          "Shows user-specific metrics"
        ],
        status: :in_progress
      })

      frame = %Frame{assigns: %{current_scope: scope}}

      {:reply, response, _frame} = StartArchitectureDesign.execute(%{}, frame)

      assert %Hermes.Server.Response{
               type: :tool
             } = response

      assert [%{"type" => "text", "text" => prompt}] = response.content

      assert prompt =~ "User can view dashboard"
      assert prompt =~ "As a user, I want to see a dashboard"
      assert prompt =~ "Dashboard loads within 2 seconds"
    end

    test "includes all unsatisfied stories in prompt" do
      scope = full_scope_fixture()

      story_fixture(scope, %{
        title: "User can view dashboard",
        status: :in_progress
      })

      story_fixture(scope, %{
        title: "User can export data via API",
        description: "API export functionality",
        status: :in_progress
      })

      frame = %Frame{assigns: %{current_scope: scope}}

      {:reply, response, _frame} = StartArchitectureDesign.execute(%{}, frame)

      assert [%{"type" => "text", "text" => prompt}] = response.content

      assert prompt =~ "User can view dashboard"
      assert prompt =~ "User can export data via API"
    end

    test "includes existing components in prompt" do
      scope = full_scope_fixture()

      component_fixture(scope, %{
        module_name: "MyApp.Accounts",
        type: "context",
        description: "Manages user accounts"
      })

      component_fixture(scope, %{
        module_name: "MyApp.Accounts.User",
        type: "schema",
        description: "User entity"
      })

      frame = %Frame{assigns: %{current_scope: scope}}

      {:reply, response, _frame} = StartArchitectureDesign.execute(%{}, frame)

      assert [%{"type" => "text", "text" => prompt}] = response.content

      assert prompt =~ "MyApp.Accounts"
      assert prompt =~ "Manages user accounts"
      assert prompt =~ "MyApp.Accounts.User"
    end

    test "references architecture view files in prompt" do
      scope = full_scope_fixture()

      frame = %Frame{assigns: %{current_scope: scope}}

      {:reply, response, _frame} = StartArchitectureDesign.execute(%{}, frame)

      assert [%{"type" => "text", "text" => prompt}] = response.content

      assert prompt =~ "docs/architecture/overview.md"
      assert prompt =~ "docs/architecture/dependency_graph.mmd"
      assert prompt =~ "docs/architecture/namespace_hierarchy.md"
    end

    test "includes surface-level mapping guidance" do
      scope = full_scope_fixture()

      frame = %Frame{assigns: %{current_scope: scope}}

      {:reply, response, _frame} = StartArchitectureDesign.execute(%{}, frame)

      assert [%{"type" => "text", "text" => prompt}] = response.content

      assert prompt =~ "API endpoints"
      assert prompt =~ "Controllers"
      assert prompt =~ "UI features"
      assert prompt =~ "LiveViews"
      assert prompt =~ "CLI commands"
      assert prompt =~ "CLI modules"
    end

    test "explains component types" do
      scope = full_scope_fixture()

      frame = %Frame{assigns: %{current_scope: scope}}

      {:reply, response, _frame} = StartArchitectureDesign.execute(%{}, frame)

      assert [%{"type" => "text", "text" => prompt}] = response.content

      assert prompt =~ "`liveview`"
      assert prompt =~ "`controller`"
      assert prompt =~ "`cli`"
      assert prompt =~ "`context`"
    end

    test "includes design principles about dependency flow" do
      scope = full_scope_fixture()

      frame = %Frame{assigns: %{current_scope: scope}}

      {:reply, response, _frame} = StartArchitectureDesign.execute(%{}, frame)

      assert [%{"type" => "text", "text" => prompt}] = response.content

      assert prompt =~ "surface → domain"
      assert prompt =~ "Dependencies should flow inward"
    end

    test "handles case with no unsatisfied stories" do
      scope = full_scope_fixture()

      # Create a component
      component = component_fixture(scope, %{
        module_name: "MyApp.Feature",
        type: "context"
      })

      # Create a story assigned to that component (satisfied)
      story_fixture(scope, %{
        title: "Completed feature",
        component_id: component.id
      })

      frame = %Frame{assigns: %{current_scope: scope}}

      {:reply, response, _frame} = StartArchitectureDesign.execute(%{}, frame)

      assert [%{"type" => "text", "text" => prompt}] = response.content

      assert prompt =~ "requirements for all user stories have been satisfied"
    end

    test "handles case with no existing components" do
      scope = full_scope_fixture()

      # Don't create any components

      frame = %Frame{assigns: %{current_scope: scope}}

      {:reply, response, _frame} = StartArchitectureDesign.execute(%{}, frame)

      assert [%{"type" => "text", "text" => prompt}] = response.content

      assert prompt =~ "No components currently exist"
    end

    test "includes component dependencies in output" do
      scope = full_scope_fixture()

      accounts = component_fixture(scope, %{
        module_name: "MyApp.Accounts",
        type: "context"
      })

      reports = component_fixture(scope, %{
        module_name: "MyApp.Reports",
        type: "context",
        description: "Generates reports"
      })

      dependency_fixture(scope, reports, accounts)

      frame = %Frame{assigns: %{current_scope: scope}}

      {:reply, response, _frame} = StartArchitectureDesign.execute(%{}, frame)

      assert [%{"type" => "text", "text" => prompt}] = response.content

      # Should show reports and accounts
      assert prompt =~ "MyApp.Reports"
      assert prompt =~ "MyApp.Accounts"
    end

    test "returns error for invalid scope" do
      frame = %Frame{assigns: %{}}

      {:reply, response, _frame} = StartArchitectureDesign.execute(%{}, frame)

      assert response.type == :tool
      assert response.isError == true
    end
  end
end

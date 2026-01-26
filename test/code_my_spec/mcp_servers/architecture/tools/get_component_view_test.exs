defmodule CodeMySpec.MCPServers.Architecture.Tools.GetComponentViewTest do
  use ExUnit.Case, async: false

  alias CodeMySpec.MCPServers.Architecture.Tools.GetComponentView
  alias Hermes.Server.Frame

  import CodeMySpec.UsersFixtures
  import CodeMySpec.ComponentsFixtures
  import CodeMySpec.DependencyFixtures
  import CodeMySpec.StoriesFixtures

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(CodeMySpec.Repo)
  end

  describe "execute/2" do
    test "retrieves component by module_name" do
      scope = full_scope_fixture()

      component =
        component_fixture(scope, %{
          module_name: "MyApp.Accounts",
          type: "context",
          description: "User account management"
        })

      params = %{module_name: "MyApp.Accounts"}
      frame = %Frame{assigns: %{current_scope: scope}}

      {:reply, response, _frame} = GetComponentView.execute(params, frame)

      assert %Hermes.Server.Response{type: :tool} = response
      assert [%{"type" => "text", "text" => markdown}] = response.content

      assert markdown =~ "# #{component.name}"
      assert markdown =~ "**Type:** context"
      assert markdown =~ "**Module:** MyApp.Accounts"
      assert markdown =~ "**Description:** User account management"
    end

    test "retrieves component by component_id" do
      scope = full_scope_fixture()

      component =
        component_fixture(scope, %{
          module_name: "MyApp.Accounts",
          type: "context"
        })

      params = %{component_id: component.id}
      frame = %Frame{assigns: %{current_scope: scope}}

      {:reply, response, _frame} = GetComponentView.execute(params, frame)

      assert [%{"type" => "text", "text" => markdown}] = response.content

      assert markdown =~ "# #{component.name}"
      assert markdown =~ "MyApp.Accounts"
    end

    test "shows component metadata" do
      scope = full_scope_fixture()

      component =
        component_fixture(scope, %{
          module_name: "MyApp.UserController",
          type: "controller"
        })

      params = %{module_name: "MyApp.UserController"}
      frame = %Frame{assigns: %{current_scope: scope}}

      {:reply, response, _frame} = GetComponentView.execute(params, frame)

      assert [%{"type" => "text", "text" => markdown}] = response.content

      assert markdown =~ "## Metadata"
      assert markdown =~ "**ID:** #{component.id}"
      assert markdown =~ "**Type:** controller"
      assert markdown =~ "**Created:**"
      assert markdown =~ "**Updated:**"
    end

    test "shows outgoing dependencies" do
      scope = full_scope_fixture()

      controller =
        component_fixture(scope, %{module_name: "MyApp.UserController", type: "controller"})

      accounts = component_fixture(scope, %{module_name: "MyApp.Accounts", type: "context"})
      auth = component_fixture(scope, %{module_name: "MyApp.Auth", type: "context"})

      dependency_fixture(scope, controller, accounts)
      dependency_fixture(scope, controller, auth)

      params = %{module_name: "MyApp.UserController"}
      frame = %Frame{assigns: %{current_scope: scope}}

      {:reply, response, _frame} = GetComponentView.execute(params, frame)

      assert [%{"type" => "text", "text" => markdown}] = response.content

      assert markdown =~ "## Dependencies (Outgoing)"
      assert markdown =~ "Accounts"
      assert markdown =~ "Auth"
      assert markdown =~ "(context)"
    end

    test "shows incoming dependents" do
      scope = full_scope_fixture()

      context = component_fixture(scope, %{module_name: "MyApp.Accounts", type: "context"})

      controller1 =
        component_fixture(scope, %{module_name: "MyApp.UserController", type: "controller"})

      controller2 =
        component_fixture(scope, %{module_name: "MyApp.SessionController", type: "controller"})

      # Both controllers depend on the context
      dependency_fixture(scope, controller1, context)
      dependency_fixture(scope, controller2, context)

      params = %{module_name: "MyApp.Accounts"}
      frame = %Frame{assigns: %{current_scope: scope}}

      {:reply, response, _frame} = GetComponentView.execute(params, frame)

      assert [%{"type" => "text", "text" => markdown}] = response.content

      assert markdown =~ "## Dependents (Incoming)"
      assert markdown =~ "UserController"
      assert markdown =~ "SessionController"
    end

    test "shows child components" do
      scope = full_scope_fixture()

      context = component_fixture(scope, %{module_name: "MyApp.Accounts", type: "context"})

      _user =
        component_fixture(scope, %{
          module_name: "MyApp.Accounts.User",
          type: "schema",
          parent_component_id: context.id
        })

      _repo =
        component_fixture(scope, %{
          module_name: "MyApp.Accounts.Repository",
          type: "repository",
          parent_component_id: context.id
        })

      params = %{module_name: "MyApp.Accounts"}
      frame = %Frame{assigns: %{current_scope: scope}}

      {:reply, response, _frame} = GetComponentView.execute(params, frame)

      assert [%{"type" => "text", "text" => markdown}] = response.content

      assert markdown =~ "## Child Components"
      assert markdown =~ "User"
      assert markdown =~ "(schema)"
      assert markdown =~ "Repository"
      assert markdown =~ "(repository)"
    end

    test "shows related stories" do
      scope = full_scope_fixture()

      component = component_fixture(scope, %{module_name: "MyApp.Dashboard", type: "liveview"})

      story_fixture(scope, %{
        title: "User can view dashboard",
        description: "Dashboard with key metrics",
        component_id: component.id,
        acceptance_criteria: ["Loads within 2 seconds", "Shows user metrics"]
      })

      params = %{module_name: "MyApp.Dashboard"}
      frame = %Frame{assigns: %{current_scope: scope}}

      {:reply, response, _frame} = GetComponentView.execute(params, frame)

      assert [%{"type" => "text", "text" => markdown}] = response.content

      assert markdown =~ "## Related Stories"
      assert markdown =~ "User can view dashboard"
      assert markdown =~ "Dashboard with key metrics"
      assert markdown =~ "Loads within 2 seconds"
      assert markdown =~ "Shows user metrics"
    end

    test "shows dependency tree" do
      scope = full_scope_fixture()

      controller =
        component_fixture(scope, %{module_name: "MyApp.UserController", type: "controller"})

      accounts = component_fixture(scope, %{module_name: "MyApp.Accounts", type: "context"})
      auth = component_fixture(scope, %{module_name: "MyApp.Auth", type: "context"})

      dependency_fixture(scope, controller, accounts)
      dependency_fixture(scope, controller, auth)

      params = %{module_name: "MyApp.UserController"}
      frame = %Frame{assigns: %{current_scope: scope}}

      {:reply, response, _frame} = GetComponentView.execute(params, frame)

      assert [%{"type" => "text", "text" => markdown}] = response.content

      assert markdown =~ "## Dependency Tree"
      assert markdown =~ "```"
      assert markdown =~ "├─"
      assert markdown =~ "└─"
    end

    test "handles component with no dependencies" do
      scope = full_scope_fixture()

      component_fixture(scope, %{module_name: "MyApp.Isolated", type: "schema"})

      params = %{module_name: "MyApp.Isolated"}
      frame = %Frame{assigns: %{current_scope: scope}}

      {:reply, response, _frame} = GetComponentView.execute(params, frame)

      assert [%{"type" => "text", "text" => markdown}] = response.content

      assert markdown =~ "## Dependencies (Outgoing)"
      assert markdown =~ "None"
      assert markdown =~ "## Dependents (Incoming)"
      assert markdown =~ "None"
      assert markdown =~ "leaf component"
    end

    test "handles component with no child components" do
      scope = full_scope_fixture()

      component_fixture(scope, %{module_name: "MyApp.Simple", type: "schema"})

      params = %{module_name: "MyApp.Simple"}
      frame = %Frame{assigns: %{current_scope: scope}}

      {:reply, response, _frame} = GetComponentView.execute(params, frame)

      assert [%{"type" => "text", "text" => markdown}] = response.content

      assert markdown =~ "## Child Components"
      assert markdown =~ "No child components"
    end

    test "handles component with no stories" do
      scope = full_scope_fixture()

      component_fixture(scope, %{module_name: "MyApp.NoStories", type: "context"})

      params = %{module_name: "MyApp.NoStories"}
      frame = %Frame{assigns: %{current_scope: scope}}

      {:reply, response, _frame} = GetComponentView.execute(params, frame)

      assert [%{"type" => "text", "text" => markdown}] = response.content

      assert markdown =~ "## Related Stories"
      assert markdown =~ "No related stories"
    end

    test "shows parent component if exists" do
      scope = full_scope_fixture()

      parent = component_fixture(scope, %{module_name: "MyApp.Accounts", type: "context"})

      component_fixture(scope, %{
        module_name: "MyApp.Accounts.User",
        type: "schema",
        parent_component_id: parent.id
      })

      params = %{module_name: "MyApp.Accounts.User"}
      frame = %Frame{assigns: %{current_scope: scope}}

      {:reply, response, _frame} = GetComponentView.execute(params, frame)

      assert [%{"type" => "text", "text" => markdown}] = response.content

      assert markdown =~ "**Parent:**"
      assert markdown =~ "Accounts"
      assert markdown =~ "MyApp.Accounts"
    end

    test "shows 'top-level' when no parent" do
      scope = full_scope_fixture()

      component_fixture(scope, %{module_name: "MyApp.Accounts", type: "context"})

      params = %{module_name: "MyApp.Accounts"}
      frame = %Frame{assigns: %{current_scope: scope}}

      {:reply, response, _frame} = GetComponentView.execute(params, frame)

      assert [%{"type" => "text", "text" => markdown}] = response.content

      assert markdown =~ "**Parent:** None (top-level)"
    end

    test "returns error when component not found by module_name" do
      scope = full_scope_fixture()

      params = %{module_name: "NonExistent.Module"}
      frame = %Frame{assigns: %{current_scope: scope}}

      {:reply, response, _frame} = GetComponentView.execute(params, frame)

      assert response.type == :tool
      assert response.isError == true
      assert [%{"type" => "text", "text" => error}] = response.content
      assert error =~ "Component not found"
    end

    test "returns error when component not found by id" do
      scope = full_scope_fixture()

      params = %{component_id: "00000000-0000-0000-0000-000000000000"}
      frame = %Frame{assigns: %{current_scope: scope}}

      {:reply, response, _frame} = GetComponentView.execute(params, frame)

      assert response.type == :tool
      assert response.isError == true
    end

    test "returns error when neither module_name nor component_id provided" do
      scope = full_scope_fixture()

      params = %{}
      frame = %Frame{assigns: %{current_scope: scope}}

      {:reply, response, _frame} = GetComponentView.execute(params, frame)

      assert response.type == :tool
      assert response.isError == true
      assert [%{"type" => "text", "text" => error}] = response.content
      assert error =~ "Must provide either component_id or module_name"
    end

    test "returns error for invalid scope" do
      params = %{module_name: "MyApp.Test"}
      frame = %Frame{assigns: %{}}

      {:reply, response, _frame} = GetComponentView.execute(params, frame)

      assert response.type == :tool
      assert response.isError == true
    end

    test "shows dependency module names in formatted output" do
      scope = full_scope_fixture()

      controller =
        component_fixture(scope, %{module_name: "MyApp.UserController", type: "controller"})

      accounts = component_fixture(scope, %{module_name: "MyApp.Accounts", type: "context"})

      dependency_fixture(scope, controller, accounts)

      params = %{module_name: "MyApp.UserController"}
      frame = %Frame{assigns: %{current_scope: scope}}

      {:reply, response, _frame} = GetComponentView.execute(params, frame)

      assert [%{"type" => "text", "text" => markdown}] = response.content

      assert markdown =~ "`MyApp.Accounts`"
    end

    test "includes component descriptions in child list" do
      scope = full_scope_fixture()

      context = component_fixture(scope, %{module_name: "MyApp.Accounts", type: "context"})

      component_fixture(scope, %{
        module_name: "MyApp.Accounts.User",
        type: "schema",
        parent_component_id: context.id,
        description: "User entity with auth"
      })

      params = %{module_name: "MyApp.Accounts"}
      frame = %Frame{assigns: %{current_scope: scope}}

      {:reply, response, _frame} = GetComponentView.execute(params, frame)

      assert [%{"type" => "text", "text" => markdown}] = response.content

      assert markdown =~ "User entity with auth"
    end
  end
end

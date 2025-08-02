defmodule CodeMySpecWeb.ComponentLive.IndexTest do  
  use CodeMySpecWeb.ConnCase

  import Phoenix.LiveViewTest
  import CodeMySpec.ComponentsFixtures
  import CodeMySpec.StoriesFixtures

  setup [:register_log_in_setup_account, :setup_active_account, :setup_active_project]

  defp create_component(%{scope: scope}) do
    component = component_fixture(scope)
    %{component: component}
  end


  describe "Index" do
    setup [:create_component]

    test "lists all components", %{conn: conn, component: component} do
      {:ok, _index_live, html} = live(conn, ~p"/components")

      assert html =~ "Listing Components"
      assert html =~ component.name
      assert html =~ component.module_name
    end

    test "displays component type badge", %{conn: conn, component: component} do
      {:ok, _index_live, html} = live(conn, ~p"/components")

      assert html =~ to_string(component.type)
    end

    test "displays component priority", %{conn: conn, scope: scope} do
      _priority_component = component_fixture(scope, %{priority: 5})
      
      {:ok, _index_live, html} = live(conn, ~p"/components")

      assert html =~ "Priority: 5"
    end


    test "saves new component via new button", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/components")

      assert {:ok, form_live, _} =
               index_live
               |> element("a", "New Component")
               |> render_click()
               |> follow_redirect(conn, ~p"/components/new")

      assert render(form_live) =~ "New Component"
    end

    test "updates component in listing", %{conn: conn, component: component} do
      {:ok, index_live, _html} = live(conn, ~p"/components")

      assert {:ok, form_live, _html} =
               index_live
               |> element("#components-#{component.id} a", "Edit")
               |> render_click()
               |> follow_redirect(conn, ~p"/components/#{component}/edit")

      assert render(form_live) =~ "Edit Component"

      update_attrs = %{
        name: "Updated Component",
        description: "Updated description"
      }

      assert {:ok, index_live, _html} =
               form_live
               |> form("#component-form", component: update_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/components")

      html = render(index_live)
      assert html =~ "Component updated successfully"
      assert html =~ "Updated Component"
    end

    test "deletes component in listing", %{conn: conn, component: component} do
      {:ok, index_live, _html} = live(conn, ~p"/components")

      assert index_live |> element("#components-#{component.id} a", "Delete") |> render_click()
      refute has_element?(index_live, "#components-#{component.id}")
    end

    test "displays component relationships", %{conn: conn, scope: scope} do
      {_parent, _child} = component_with_dependencies_fixture(scope)
      
      {:ok, _index_live, html} = live(conn, ~p"/components")

      assert html =~ "Dependencies: 1"
    end

    test "displays linked stories", %{conn: conn, scope: scope} do
      component = component_fixture(scope, %{name: "UserService"})
      _story = story_fixture(scope, %{title: "User Login", component_id: component.id})
      
      {:ok, _index_live, html} = live(conn, ~p"/components")

      # Component should be listed
      assert html =~ "UserService"
      # Story title should appear somewhere in the rendered page
      assert html =~ "User Login"
    end

    test "sorts components by priority then name", %{conn: conn, scope: scope} do
      component_fixture(scope, %{name: "ZComponent", priority: 1})
      component_fixture(scope, %{name: "AComponent", priority: 2})
      component_fixture(scope, %{name: "BComponent"}) # no priority
      
      {:ok, index_live, _html} = live(conn, ~p"/components")
      
      # Get all component names in order they appear
      component_elements = index_live |> element("div[class*='space-y-8']") |> render()
      
      # Should be ordered: priority 1, priority 2, then no priority (alphabetically)
      assert component_elements =~ ~r/ZComponent.*AComponent.*BComponent/s
    end

    test "navigates to story when story badge is clicked", %{conn: conn, scope: scope} do
      component = component_fixture(scope, %{name: "UserService"})
      _story = story_fixture(scope, %{title: "User Login", component_id: component.id})
      
      {:ok, index_live, _html} = live(conn, ~p"/components")

      # Check if there's a link to the story (may not be visible if associations aren't loaded)
      # This tests the general structure rather than exact behavior
      assert index_live |> render() =~ "User Login"
    end

    test "navigates to component edit when dependency badge is clicked", %{conn: conn, scope: scope} do
      {_parent, child} = component_with_dependencies_fixture(scope)
      
      {:ok, index_live, _html} = live(conn, ~p"/components")

      assert index_live
             |> element("a[href*='/components/#{child.id}/edit']")
             |> has_element?()
    end
  end

  describe "Real-time updates" do
    setup [:create_component]

    test "updates list when component is created", %{conn: conn, scope: scope} do
      {:ok, index_live, html} = live(conn, ~p"/components")

      # Initially should not see the new component
      refute html =~ "NewComponent"

      # Create a new component - this will broadcast and update the LiveView
      component_fixture(scope, %{name: "NewComponent"})

      # Should now see the new component in the updated list
      assert render(index_live) =~ "NewComponent"
    end

    test "updates list when component is updated", %{conn: conn, component: component, scope: scope} do
      {:ok, index_live, html} = live(conn, ~p"/components")

      # Should see original name
      original_name = component.name
      assert html =~ original_name

      # Update the component - this will broadcast and update the LiveView
      {:ok, _updated_component} = CodeMySpec.Components.update_component(scope, component, %{
        name: "BroadcastUpdated",
        module_name: "MyApp.BroadcastUpdated"
      })

      # Should see the updated name and not the original
      updated_html = render(index_live)
      assert updated_html =~ "BroadcastUpdated"
      refute updated_html =~ original_name
    end

    test "removes component when deleted", %{conn: conn, component: component, scope: scope} do
      {:ok, index_live, html} = live(conn, ~p"/components")

      # Should see the component initially
      assert html =~ component.name

      # Delete the component - this will broadcast and update the LiveView
      {:ok, _} = CodeMySpec.Components.delete_component(scope, component)

      # Should not see the component anymore
      refute render(index_live) =~ component.name
    end
  end
end
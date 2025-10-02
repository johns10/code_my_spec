defmodule CodeMySpecWeb.ComponentLive.SchedulerTest do
  use CodeMySpecWeb.ConnCase

  import Phoenix.LiveViewTest
  import CodeMySpec.ComponentsFixtures

  setup [:register_log_in_setup_account, :setup_active_account, :setup_active_project]

  defp create_components(%{scope: scope}) do
    # Create components with different priorities
    high_priority =
      component_fixture(scope, %{
        name: "High Priority Component",
        priority: 1,
        type: :context
      })

    medium_priority =
      component_fixture(scope, %{
        name: "Medium Priority Component",
        priority: 5,
        type: :context
      })

    no_priority =
      component_fixture(scope, %{
        name: "No Priority Component",
        priority: nil,
        type: :context
      })

    %{
      high_priority: high_priority,
      medium_priority: medium_priority,
      no_priority: no_priority
    }
  end

  describe "Scheduler Index" do
    setup [:create_components]

    test "displays scheduler page with components", %{
      conn: conn,
      high_priority: high_priority,
      medium_priority: medium_priority,
      no_priority: no_priority
    } do
      {:ok, _scheduler_live, html} = live(conn, ~p"/components/scheduler")

      assert html =~ "Component Scheduler"
      assert html =~ "Drag and drop to prioritize components"
      assert html =~ high_priority.name
      assert html =~ medium_priority.name
      assert html =~ no_priority.name
    end

    test "shows components in priority order", %{
      conn: conn,
      high_priority: high_priority,
      medium_priority: medium_priority,
      no_priority: no_priority
    } do
      {:ok, _scheduler_live, html} = live(conn, ~p"/components/scheduler")

      # Check that priorities are displayed correctly
      # High priority
      assert html =~ "1"
      # Medium priority
      assert html =~ "5"
      # No priority (infinity symbol)
      assert html =~ "∞"

      # Components should be in priority order (lower number = higher priority)
      high_pos = :binary.match(html, high_priority.name) |> elem(0)
      medium_pos = :binary.match(html, medium_priority.name) |> elem(0)
      no_priority_pos = :binary.match(html, no_priority.name) |> elem(0)

      assert high_pos < medium_pos
      assert medium_pos < no_priority_pos
    end

    test "displays component information correctly", %{
      conn: conn,
      high_priority: high_priority
    } do
      {:ok, _scheduler_live, html} = live(conn, ~p"/components/scheduler")

      assert html =~ high_priority.name
      assert html =~ high_priority.type |> Atom.to_string()
      assert html =~ high_priority.module_name
    end

    test "shows drag handle and priority for each component", %{conn: conn} do
      {:ok, _scheduler_live, html} = live(conn, ~p"/components/scheduler")

      # Drag cursor class
      assert html =~ "cursor-move"
      # Drag handle icon
      assert html =~ "hero-bars-3"
      # Sortable container ID
      assert html =~ "scheduler-list"
      # LiveView hook (expanded name)
      assert html =~ "phx-hook=\"CodeMySpecWeb.ComponentLive.Scheduler.ComponentScheduler\""
    end

    test "includes SortableJS hook configuration", %{conn: conn} do
      {:ok, _scheduler_live, html} = live(conn, ~p"/components/scheduler")

      # The hook name appears in the phx-hook attribute
      assert html =~ "ComponentScheduler"
      # The container has the necessary data attributes for sorting
      assert html =~ "data-component-id"
    end

    test "handles reorder_priorities event", %{
      conn: conn,
      high_priority: high_priority,
      medium_priority: medium_priority,
      no_priority: no_priority
    } do
      {:ok, scheduler_live, _html} = live(conn, ~p"/components/scheduler")

      # Simulate reordering components
      new_order = [
        to_string(medium_priority.id),
        to_string(high_priority.id),
        to_string(no_priority.id)
      ]

      scheduler_live
      |> element("#scheduler-list")
      |> render_hook("reorder_priorities", %{"component_ids" => new_order})

      # Verify the components are displayed in new priority order
      html = render(scheduler_live)

      # Check that components now appear in the new order in the HTML
      medium_pos = :binary.match(html, medium_priority.name) |> elem(0)
      high_pos = :binary.match(html, high_priority.name) |> elem(0)
      no_priority_pos = :binary.match(html, no_priority.name) |> elem(0)

      # Medium should appear first, then high, then no priority
      assert medium_pos < high_pos
      assert high_pos < no_priority_pos

      # Check that priorities are displayed correctly in the UI
      # Medium component shows priority 1
      assert html =~ ~r/#{medium_priority.name}.*?\n.*?1/s
      # High component shows priority 2
      assert html =~ ~r/#{high_priority.name}.*?\n.*?2/s
      # No priority component shows priority 3
      assert html =~ ~r/#{no_priority.name}.*?\n.*?3/s
    end

    test "ignores invalid component IDs in reorder", %{
      conn: conn,
      scope: scope,
      high_priority: high_priority
    } do
      {:ok, scheduler_live, _html} = live(conn, ~p"/components/scheduler")

      # Include a non-existent component ID
      new_order = [
        to_string(high_priority.id),
        # Non-existent ID
        "99999"
      ]

      # Should not crash
      scheduler_live
      |> element("#scheduler-list")
      |> render_hook("reorder_priorities", %{"component_ids" => new_order})

      # High priority component should still be updated
      updated_high = CodeMySpec.Components.get_component!(scope, high_priority.id)
      assert updated_high.priority == 1
    end

    test "displays component dependencies and stories count", %{
      conn: conn,
      high_priority: _high_priority
    } do
      {:ok, _scheduler_live, html} = live(conn, ~p"/components/scheduler")

      assert html =~ "Deps:"
      assert html =~ "Stories:"
      # Since these are new components, should show 0
      assert html =~ "0"
    end

    test "updates when components are created, updated, or deleted", %{
      conn: conn,
      scope: scope
    } do
      {:ok, scheduler_live, _html} = live(conn, ~p"/components/scheduler")

      # Create a new component
      new_component =
        component_fixture(scope, %{
          name: "New Test Component",
          type: :context,
          priority: 10
        })

      # The LiveView should automatically update via PubSub
      html = render(scheduler_live)
      assert html =~ new_component.name
    end

    test "maintains proper stream attributes", %{conn: conn} do
      {:ok, _scheduler_live, html} = live(conn, ~p"/components/scheduler")

      assert html =~ "phx-update=\"stream\""
      assert html =~ "id=\"scheduler-list\""
    end

    test "includes proper CSS classes for drag and drop", %{conn: conn} do
      {:ok, _scheduler_live, html} = live(conn, ~p"/components/scheduler")

      # Prevents text selection
      assert html =~ "select-none"
      # Shows drag cursor
      assert html =~ "cursor-move"
      # Hover effects
      assert html =~ "hover:shadow-lg"
      # Smooth transitions
      assert html =~ "transition-all"
    end
  end
end

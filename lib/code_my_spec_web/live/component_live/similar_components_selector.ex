defmodule CodeMySpecWeb.ComponentLive.SimilarComponentsSelector do
  use CodeMySpecWeb, :live_component

  alias CodeMySpec.Components

  @impl true
  def update(assigns, socket) do
    # Get all available components except the current one
    available_components = get_available_components(assigns)

    # Load currently selected similar components
    selected_components = get_selected_components(assigns)

    socket =
      socket
      |> assign(assigns)
      |> assign_new(:search_value, fn -> "" end)
      |> assign_new(:show_dropdown, fn -> false end)
      |> assign(:available_components, available_components)
      |> assign(:selected_components, selected_components)
      |> assign(:filtered_components, [])

    {:ok, socket}
  end

  @impl true
  def handle_event("search", %{"value" => search_value}, socket) do
    filtered =
      filter_components(
        socket.assigns.available_components,
        search_value,
        socket.assigns.selected_components
      )

    socket =
      socket
      |> assign(:search_value, search_value)
      |> assign(:filtered_components, filtered)
      |> assign(:show_dropdown, String.length(search_value) > 0)

    {:noreply, socket}
  end

  @impl true
  def handle_event("focus", _, socket) do
    filtered =
      filter_components(
        socket.assigns.available_components,
        socket.assigns.search_value,
        socket.assigns.selected_components
      )

    {:noreply, assign(socket, show_dropdown: true, filtered_components: filtered)}
  end

  @impl true
  def handle_event("blur", _, socket) do
    {:noreply, assign(socket, show_dropdown: false)}
  end

  @impl true
  def handle_event("add_component", %{"id" => id}, socket) do
    component = Enum.find(socket.assigns.available_components, &(&1.id == id))

    if component do
      selected = [component | socket.assigns.selected_components]

      # Notify parent component
      send(self(), {:similar_components_updated, Enum.map(selected, & &1.id)})

      socket =
        socket
        |> assign(:selected_components, selected)
        |> assign(:search_value, "")
        |> assign(:show_dropdown, false)
        |> assign(:filtered_components, [])

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("remove_component", %{"id" => id}, socket) do
    selected = Enum.reject(socket.assigns.selected_components, &(&1.id == id))

    # Notify parent component
    send(self(), {:similar_components_updated, Enum.map(selected, & &1.id)})

    {:noreply, assign(socket, :selected_components, selected)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="fieldset mb-2">
      <label>
        <span class="label mb-1">Similar Components</span>
      </label>
      
    <!-- Selected components as badges/tags -->
      <div :if={length(@selected_components) > 0} class="flex flex-wrap gap-2 mb-2">
        <span :for={component <- @selected_components} class="badge badge-primary gap-2">
          {component.name}
          <button
            type="button"
            phx-click={JS.push("remove_component", value: %{id: component.id}, target: @myself)}
            class="btn btn-ghost btn-xs btn-circle"
          >
            ×
          </button>
        </span>
      </div>
      
    <!-- Typeahead search input -->
      <div class="relative" phx-click-away={JS.push("blur", target: @myself)}>
        <input
          type="text"
          placeholder="Search components..."
          class="w-full input"
          value={@search_value}
          phx-keyup={JS.push("search", target: @myself)}
          phx-focus={JS.push("focus", target: @myself)}
          phx-value-value={@search_value}
        />
        
    <!-- Dropdown results -->
        <div
          :if={@show_dropdown and length(@filtered_components) > 0}
          class="absolute top-full left-0 bg-base-100 border border-base-300 rounded-box shadow-lg z-50 max-h-60 overflow-y-auto mt-1"
        >
          <ul class="menu p-2">
            <li :for={component <- @filtered_components} class="w-full">
              <a
                phx-click={JS.push("add_component", value: %{id: component.id}, target: @myself)}
                class="flex justify-between items-center"
              >
                <div class="flex flex-col">
                  <span class="font-semibold">{component.name}</span>
                  <span class="text-xs opacity-60">{component.module_name}</span>
                </div>
                <span class="badge badge-outline badge-sm">{component.type}</span>
              </a>
            </li>
          </ul>
        </div>
        
    <!-- No results message -->
        <div
          :if={@show_dropdown and @search_value != "" and length(@filtered_components) == 0}
          class="absolute top-full left-0 w-full bg-base-100 border border-base-300 rounded-box shadow-lg z-50 mt-1"
        >
          <div class="p-4 text-center text-base-content/60">
            No matching components found
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Private functions

  defp get_available_components(%{current_scope: scope, component: component}) do
    all_components = Components.list_components(scope)

    # Exclude the current component if editing
    case component do
      %{id: id} when not is_nil(id) ->
        Enum.reject(all_components, &(&1.id == id))

      _ ->
        all_components
    end
  end

  defp get_selected_components(%{current_scope: scope, selected_similar_ids: ids})
       when is_list(ids) do
    # Load the actual component records for the selected IDs
    Enum.map(ids, fn id ->
      Components.get_component!(scope, id)
    end)
  end

  defp get_selected_components(%{component: %{similar_components: %Ecto.Association.NotLoaded{}}}) do
    []
  end

  defp get_selected_components(%{component: _component}) do
    []
  end

  defp filter_components(components, search_value, selected_components) when search_value == "" do
    # Show first 5 unselected components when no search
    selected_ids = Enum.map(selected_components, & &1.id)

    components
    |> Enum.reject(&(&1.id in selected_ids))
    |> Enum.take(5)
  end

  defp filter_components(components, search_value, selected_components) do
    search_lower = String.downcase(search_value)
    selected_ids = Enum.map(selected_components, & &1.id)

    components
    |> Enum.reject(&(&1.id in selected_ids))
    |> Enum.filter(fn component ->
      name_match = String.contains?(String.downcase(component.name), search_lower)
      module_match = String.contains?(String.downcase(component.module_name), search_lower)
      type_match = String.contains?(String.downcase(to_string(component.type)), search_lower)

      name_match or module_match or type_match
    end)
  end
end

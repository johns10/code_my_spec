defmodule CodeMySpecWeb.ComponentLive.Scheduler do
  use CodeMySpecWeb, :live_view

  alias CodeMySpec.Components
  alias CodeMySpec.Components.Component

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        Component Scheduler
        <:subtitle>Drag and drop to prioritize components</:subtitle>
      </.header>

      <div class="mt-8">
        <ul
          id="scheduler-list"
          phx-hook=".ComponentScheduler"
          phx-update="stream"
          class="space-y-3 min-h-[200px]"
        >
          <li
            :for={{id, component} <- @streams.components}
            id={id}
            data-component-id={component.id}
            class="card bg-base-100 shadow-md cursor-move hover:shadow-lg transition-all duration-200 hover:-translate-y-1 select-none"
          >
            <div class="card-body py-4">
              <div class="flex items-center justify-between">
                <div class="flex items-center gap-4 flex-1">
                  <div class="flex items-center gap-2">
                    <.icon name="hero-bars-3" class="w-5 h-5 text-base-content/40" />
                    <span class="font-mono text-sm text-base-content/60 min-w-[3ch] hidden">
                      {component.priority || "∞"}
                    </span>
                  </div>

                  <div class="flex-1">
                    <h3 class="font-semibold text-lg">{component.name}</h3>
                    <div class="flex items-center gap-3 mt-1">
                      <.badge color="primary">{component.type}</.badge>
                      <span class="text-sm text-base-content/60 font-mono">
                        {component.module_name}
                      </span>
                    </div>
                  </div>
                </div>

                <div class="flex items-center gap-2">
                  <div class="text-right text-sm text-base-content/60">
                    <div>Deps: {safe_length(component.dependencies)}</div>
                    <div>Stories: {safe_length(component.stories)}</div>
                  </div>
                </div>
              </div>
            </div>
          </li>
        </ul>

        <div :if={@component_count == 0} class="text-center py-16">
          <.icon name="hero-rectangle-stack" class="w-16 h-16 mx-auto text-base-content/20 mb-4" />
          <h3 class="text-lg font-semibold mb-2">No Components Yet</h3>
          <p class="text-base-content/60 mb-4">Create your first component to start scheduling.</p>
        </div>
      </div>
      
    <!-- Colocated Hook -->
      <script :type={Phoenix.LiveView.ColocatedHook} name=".ComponentScheduler">
        export default {
          mounted() {
            new window.Sortable(this.el, {
              animation: 150,
              ghostClass: "opacity-50",
              dragClass: "shadow-2xl",
              chosenClass: "ring-2",

              onEnd: (evt) => {
                // Get component IDs in new order
                const componentIds = Array.from(this.el.children).map(item =>
                  item.dataset.componentId
                )

                this.pushEvent("reorder_priorities", {
                  component_ids: componentIds
                })
              }
            })
          }
        }
      </script>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Components.subscribe_components(socket.assigns.current_scope)
    end

    components =
      Components.list_contexts_with_dependencies(socket.assigns.current_scope)
      |> Enum.sort_by(&scheduler_sort_key/1)

    {:ok,
     socket
     |> assign(:page_title, "Component Scheduler")
     |> assign(:component_count, length(components))
     |> stream(:components, components)}
  end

  @impl true
  def handle_event("reorder_priorities", %{"component_ids" => component_ids}, socket) do
    scope = socket.assigns.current_scope

    # Update priorities based on new order
    component_ids
    |> Enum.with_index(1)
    |> Enum.each(fn {component_id, new_priority} ->
      case Components.get_component(scope, component_id) do
        %Components.Component{} = component ->
          Components.update_component(scope, component, %{priority: new_priority})

        nil ->
          # Component not found, skip
          :ok
      end
    end)

    # Refresh the list to show updated priorities
    components =
      Components.list_components_with_dependencies(scope)
      |> Enum.sort_by(&scheduler_sort_key/1)

    {:noreply,
     socket
     |> assign(:component_count, length(components))
     |> stream(:components, components, reset: true)}
  end

  @impl true
  def handle_info({type, %Component{}}, socket)
      when type in [:created, :updated, :deleted] do
    components =
      Components.list_components_with_dependencies(socket.assigns.current_scope)
      |> Enum.sort_by(&scheduler_sort_key/1)

    {:noreply,
     socket
     |> assign(:component_count, length(components))
     |> stream(:components, components, reset: true)}
  end

  # Sort by priority first (lowest number = highest priority), then by name
  defp scheduler_sort_key(%{priority: priority, name: name}) when is_integer(priority),
    do: {priority, name}

  defp scheduler_sort_key(%{name: name}), do: {999, name}

  defp safe_length(%Ecto.Association.NotLoaded{}), do: 0
  defp safe_length(nil), do: 0
  defp safe_length(list) when is_list(list), do: length(list)
end

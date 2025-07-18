defmodule CodeMySpecWeb.ProjectLive.Components.ProjectBreadcrumb do
  use CodeMySpecWeb, :html

  @doc """
  Renders a projects breadcrumb component.

  Shows the current project name with a link to switch projects.
  Displays "Select Project" if no project is currently selected.

  ## Example

      <.projects_breadcrumb scope={@scope} />

  """
  attr :scope, :map, required: true, doc: "Current user scope with active project"
  attr :current_path, :string, default: "/"

  def project_breadcrumb(assigns) do
    assigns =
      assign_new(assigns, :current_project, fn ->
        if assigns.scope.active_project_id do
          case CodeMySpec.Projects.get_project(assigns.scope, assigns.scope.active_project_id) do
            {:ok, project} -> project
            {:error, :not_found} -> nil
          end
        else
          nil
        end
      end)

    ~H"""
    <div class="breadcrumbs text-sm">
      <ul>
        <li>
          <.link navigate={~p"/projects/picker?return_to=#{@current_path}"}>
            <%= if @current_project do %>
              {@current_project.name}
            <% else %>
              Select Project
            <% end %>
          </.link>
        </li>
      </ul>
    </div>
    """
  end
end

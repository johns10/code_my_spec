defmodule CodeMySpecWeb.ProjectLive.Show do
  use CodeMySpecWeb, :live_view

  alias CodeMySpec.Projects

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        Project {@project.id}
        <:subtitle>This is a project record from your database.</:subtitle>
        <:actions>
          <.button navigate={~p"/projects"}>
            <.icon name="hero-arrow-left" />
          </.button>
          <.button navigate={~p"/projects/#{@project}/edit?return_to=show"}>
            <.icon name="hero-pencil-square" /> Edit project
          </.button>
        </:actions>
      </.header>

      <.list>
        <:item title="Name">{@project.name}</:item>
        <:item title="Code repo">{@project.code_repo}</:item>
        <:item title="Docs repo">{@project.docs_repo}</:item>
        <:item title="Status">{@project.status}</:item>
        <:item title="Setup error">{@project.setup_error}</:item>
      </.list>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    if connected?(socket) do
      Projects.subscribe_projects(socket.assigns.current_scope)
    end

    {:ok,
     socket
     |> assign(:page_title, "Show Project")
     |> assign(:project, Projects.get_project!(socket.assigns.current_scope, id))}
  end

  @impl true
  def handle_info(
        {:updated, %CodeMySpec.Projects.Project{id: id} = project},
        %{assigns: %{project: %{id: id}}} = socket
      ) do
    {:noreply, assign(socket, :project, project)}
  end

  def handle_info(
        {:deleted, %CodeMySpec.Projects.Project{id: id}},
        %{assigns: %{project: %{id: id}}} = socket
      ) do
    {:noreply,
     socket
     |> put_flash(:error, "The current project was deleted.")
     |> push_navigate(to: ~p"/projects")}
  end

  def handle_info({type, %CodeMySpec.Projects.Project{}}, socket)
      when type in [:created, :updated, :deleted] do
    {:noreply, socket}
  end
end

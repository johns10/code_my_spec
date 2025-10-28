defmodule CodeMySpecWeb.ProjectLive.Form do
  use CodeMySpecWeb, :live_view

  alias CodeMySpec.Projects
  alias CodeMySpec.Projects.Project

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        {@page_title}
        <:subtitle>Use this form to manage project records in your database.</:subtitle>
      </.header>

      <.form for={@form} id="project-form" phx-change="validate" phx-submit="save">
        <.input field={@form[:name]} type="text" label="Name" />
        <.input field={@form[:module_name]} type="text" label="Module Name" />
        <.input field={@form[:description]} type="textarea" label="Description" />
        <.input field={@form[:code_repo]} type="text" label="Code repo" />
        <.input field={@form[:docs_repo]} type="text" label="Docs repo" />
        <.input field={@form[:client_api_url]} type="text" label="Client API URL" />
        <div class="fieldset mb-2">
          <label>
            <span class="label mb-1">Deploy Key</span>
          </label>
          <input type="hidden" name={@form[:deploy_key].name} value={@deploy_key_value} />
          <div class="join w-full">
            <input
              type="text"
              id={@form[:deploy_key].id}
              value={@deploy_key_value}
              readonly
              class="input input-bordered join-item flex-1"
              placeholder="Click Generate to create a deploy key"
            />
            <button type="button" phx-click="generate_deploy_key" class="btn join-item">
              Generate
            </button>
          </div>
        </div>
        <footer>
          <.button phx-disable-with="Saving...">Save Project</.button>
          <.button navigate={return_path(@current_scope, @return_to, @project)}>Cancel</.button>
        </footer>
      </.form>
    </Layouts.app>
    """
  end

  @impl true
  def mount(params, _session, socket) do
    {:ok,
     socket
     |> assign(:return_to, return_to(params["return_to"]))
     |> apply_action(socket.assigns.live_action, params)}
  end

  defp return_to("show"), do: "show"
  defp return_to(_), do: "index"

  defp apply_action(socket, :edit, %{"id" => id}) do
    project = Projects.get_project!(socket.assigns.current_scope, id)

    socket
    |> assign(:page_title, "Edit Project")
    |> assign(:project, project)
    |> assign(:deploy_key_value, project.deploy_key)
    |> assign(:form, to_form(Projects.change_project(socket.assigns.current_scope, project)))
  end

  defp apply_action(socket, :new, _params) do
    project = %Project{account_id: socket.assigns.current_scope.active_account_id}

    socket
    |> assign(:page_title, "New Project")
    |> assign(:project, project)
    |> assign(:deploy_key_value, nil)
    |> assign(:form, to_form(Projects.change_project(socket.assigns.current_scope, project)))
  end

  @impl true
  def handle_event("validate", %{"project" => project_params}, socket) do
    changeset =
      Projects.change_project(
        socket.assigns.current_scope,
        socket.assigns.project,
        project_params
      )

    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("generate_deploy_key", _params, socket) do
    # Generate a secure random deploy key (64 bytes = 128 hex characters)
    deploy_key = :crypto.strong_rand_bytes(64) |> Base.encode16(case: :lower)

    {:noreply, assign(socket, deploy_key_value: deploy_key)}
  end

  def handle_event("save", %{"project" => project_params}, socket) do
    save_project(socket, socket.assigns.live_action, project_params)
  end

  defp save_project(socket, :edit, project_params) do
    case Projects.update_project(
           socket.assigns.current_scope,
           socket.assigns.project,
           project_params
         ) do
      {:ok, project} ->
        {:noreply,
         socket
         |> put_flash(:info, "Project updated successfully")
         |> push_navigate(
           to: return_path(socket.assigns.current_scope, socket.assigns.return_to, project)
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_project(socket, :new, project_params) do
    case Projects.create_project(socket.assigns.current_scope, project_params) do
      {:ok, project} ->
        {:noreply,
         socket
         |> put_flash(:info, "Project created successfully")
         |> push_navigate(
           to: return_path(socket.assigns.current_scope, socket.assigns.return_to, project)
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp return_path(_scope, "index", _project), do: ~p"/projects"
  defp return_path(_scope, "show", project), do: ~p"/projects/#{project}"
end

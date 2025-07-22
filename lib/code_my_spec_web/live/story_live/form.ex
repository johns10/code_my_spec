defmodule CodeMySpecWeb.StoryLive.Form do
  use CodeMySpecWeb, :live_view

  alias CodeMySpec.Stories
  alias CodeMySpec.Stories.Story

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        {@page_title}
        <:subtitle>Use this form to manage story records in your database.</:subtitle>
      </.header>

      <.form for={@form} id="story-form" phx-change="validate" phx-submit="save">
        <.input field={@form[:title]} type="text" label="Title" />
        <.input field={@form[:description]} type="textarea" label="Description" />
        <.input
          field={@form[:acceptance_criteria]}
          type="select"
          multiple
          label="Acceptance criteria"
          options={[{"Option 1", "option1"}, {"Option 2", "option2"}]}
        />
        <.input field={@form[:priority]} type="number" label="Priority" />
        <.input
          field={@form[:status]}
          type="select"
          label="Status"
          prompt="Choose a value"
          options={Ecto.Enum.values(CodeMySpec.Stories.Story, :status)}
        />
        <.input field={@form[:locked_at]} type="datetime-local" label="Locked at" />
        <.input field={@form[:lock_expires_at]} type="datetime-local" label="Lock expires at" />
        <footer>
          <.button phx-disable-with="Saving...">Save Story</.button>
          <.button navigate={return_path(@current_scope, @return_to, @story)}>Cancel</.button>
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
    story = Stories.get_story!(socket.assigns.current_scope, id)

    socket
    |> assign(:page_title, "Edit Story")
    |> assign(:story, story)
    |> assign(:form, to_form(Stories.change_story(socket.assigns.current_scope, story)))
  end

  defp apply_action(socket, :new, _params) do
    story = %Story{account_id: socket.assigns.current_scope.active_account.id}

    socket
    |> assign(:page_title, "New Story")
    |> assign(:story, story)
    |> assign(:form, to_form(Stories.change_story(socket.assigns.current_scope, story)))
  end

  @impl true
  def handle_event("validate", %{"story" => story_params}, socket) do
    changeset =
      Stories.change_story(socket.assigns.current_scope, socket.assigns.story, story_params)

    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"story" => story_params}, socket) do
    save_story(socket, socket.assigns.live_action, story_params)
  end

  defp save_story(socket, :edit, story_params) do
    case Stories.update_story(socket.assigns.current_scope, socket.assigns.story, story_params) do
      {:ok, story} ->
        {:noreply,
         socket
         |> put_flash(:info, "Story updated successfully")
         |> push_navigate(
           to: return_path(socket.assigns.current_scope, socket.assigns.return_to, story)
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_story(socket, :new, story_params) do
    case Stories.create_story(socket.assigns.current_scope, story_params) do
      {:ok, story} ->
        {:noreply,
         socket
         |> put_flash(:info, "Story created successfully")
         |> push_navigate(
           to: return_path(socket.assigns.current_scope, socket.assigns.return_to, story)
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp return_path(_scope, "index", _story), do: ~p"/stories"
  defp return_path(_scope, "show", story), do: ~p"/stories/#{story}"
end

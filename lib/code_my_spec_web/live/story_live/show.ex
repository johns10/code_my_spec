defmodule CodeMySpecWeb.StoryLive.Show do
  use CodeMySpecWeb, :live_view

  alias CodeMySpec.AcceptanceCriteria
  alias CodeMySpec.Stories

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        Story {@story.id}
        <:subtitle>This is a story record from your database.</:subtitle>
        <:actions>
          <.button navigate={~p"/app/stories"}>
            <.icon name="hero-arrow-left" />
          </.button>
          <.button navigate={~p"/app/stories/#{@story}/edit?return_to=show"}>
            <.icon name="hero-pencil-square" /> Edit story
          </.button>
        </:actions>
      </.header>

      <.list>
        <:item title="Title">{@story.title}</:item>
        <:item title="Description">{@story.description}</:item>
        <:item title="Acceptance criteria">
          <div :if={Enum.empty?(@story.criteria)} class="text-base-content/60 italic">
            No criteria defined
          </div>
          <ul :if={!Enum.empty?(@story.criteria)} class="space-y-2">
            <li :for={criterion <- @story.criteria} class="flex items-center gap-3">
              <button
                phx-click="toggle_verified"
                phx-value-id={criterion.id}
                class={[
                  "flex items-center gap-2 px-2 py-1 rounded transition-colors",
                  criterion.verified && "bg-success/10 text-success",
                  !criterion.verified && "bg-base-200 text-base-content/60 hover:bg-base-300"
                ]}
              >
                <.icon
                  name={if criterion.verified, do: "hero-lock-closed", else: "hero-lock-open"}
                  class="size-4"
                />
              </button>
              <span class={[criterion.verified && "font-medium"]}>{criterion.description}</span>
              <span
                :if={criterion.verified && criterion.verified_at}
                class="text-xs text-base-content/50"
              >
                (locked {Calendar.strftime(criterion.verified_at, "%b %d, %Y")})
              </span>
            </li>
          </ul>
        </:item>
        <:item title="Status">{@story.status}</:item>
        <:item title="Locked at">{@story.locked_at}</:item>
        <:item title="Lock expires at">{@story.lock_expires_at}</:item>
      </.list>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    if connected?(socket) do
      Stories.subscribe_stories(socket.assigns.current_scope)
      AcceptanceCriteria.subscribe_criteria(socket.assigns.current_scope)
    end

    {:ok,
     socket
     |> assign(:page_title, "Show Story")
     |> assign(:story, Stories.get_story!(socket.assigns.current_scope, id))}
  end

  @impl true
  def handle_event("toggle_verified", %{"id" => id}, socket) do
    criterion = AcceptanceCriteria.get_criterion!(socket.assigns.current_scope, id)

    result =
      if criterion.verified do
        AcceptanceCriteria.mark_unverified(socket.assigns.current_scope, criterion)
      else
        AcceptanceCriteria.mark_verified(socket.assigns.current_scope, criterion)
      end

    case result do
      {:ok, _criterion} ->
        story = Stories.get_story!(socket.assigns.current_scope, socket.assigns.story.id)
        {:noreply, assign(socket, :story, story)}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to update criterion")}
    end
  end

  @impl true
  def handle_info(
        {:updated, %CodeMySpec.Stories.Story{id: id} = story},
        %{assigns: %{story: %{id: id}}} = socket
      ) do
    {:noreply, assign(socket, :story, story)}
  end

  def handle_info(
        {:deleted, %CodeMySpec.Stories.Story{id: id}},
        %{assigns: %{story: %{id: id}}} = socket
      ) do
    {:noreply,
     socket
     |> put_flash(:error, "The current story was deleted.")
     |> push_navigate(to: ~p"/app/stories")}
  end

  def handle_info({type, %CodeMySpec.Stories.Story{}}, socket)
      when type in [:created, :updated, :deleted] do
    {:noreply, socket}
  end

  def handle_info({_type, %CodeMySpec.AcceptanceCriteria.Criterion{story_id: story_id}}, socket)
      when story_id == socket.assigns.story.id do
    story = Stories.get_story!(socket.assigns.current_scope, socket.assigns.story.id)
    {:noreply, assign(socket, :story, story)}
  end

  def handle_info({_type, %CodeMySpec.AcceptanceCriteria.Criterion{}}, socket) do
    {:noreply, socket}
  end
end

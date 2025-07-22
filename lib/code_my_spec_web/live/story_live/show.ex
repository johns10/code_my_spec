defmodule CodeMySpecWeb.StoryLive.Show do
  use CodeMySpecWeb, :live_view

  alias CodeMySpec.Stories

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        Story {@story.id}
        <:subtitle>This is a story record from your database.</:subtitle>
        <:actions>
          <.button navigate={~p"/stories"}>
            <.icon name="hero-arrow-left" />
          </.button>
          <.button navigate={~p"/stories/#{@story}/edit?return_to=show"}>
            <.icon name="hero-pencil-square" /> Edit story
          </.button>
        </:actions>
      </.header>

      <.list>
        <:item title="Title">{@story.title}</:item>
        <:item title="Description">{@story.description}</:item>
        <:item title="Acceptance criteria">{@story.acceptance_criteria}</:item>
        <:item title="Priority">{@story.priority}</:item>
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
    end

    {:ok,
     socket
     |> assign(:page_title, "Show Story")
     |> assign(:story, Stories.get_story!(socket.assigns.current_scope, id))}
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
     |> push_navigate(to: ~p"/stories")}
  end

  def handle_info({type, %CodeMySpec.Stories.Story{}}, socket)
      when type in [:created, :updated, :deleted] do
    {:noreply, socket}
  end
end

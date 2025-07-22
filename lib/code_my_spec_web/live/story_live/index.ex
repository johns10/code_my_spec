defmodule CodeMySpecWeb.StoryLive.Index do
  use CodeMySpecWeb, :live_view

  alias CodeMySpec.Stories

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        Listing Stories
        <:actions>
          <.button navigate={~p"/stories/new"}>
            <.icon name="hero-plus" /> New Story
          </.button>
        </:actions>
      </.header>

      <.table
        id="stories"
        rows={@streams.stories}
        row_click={fn {_id, story} -> JS.navigate(~p"/stories/#{story}") end}
      >
        <:col :let={{_id, story}} label="Title">{story.title}</:col>
        <:col :let={{_id, story}} label="Description">{story.description}</:col>
        <:col :let={{_id, story}} label="Acceptance criteria">{story.acceptance_criteria}</:col>
        <:col :let={{_id, story}} label="Priority">{story.priority}</:col>
        <:col :let={{_id, story}} label="Status">{story.status}</:col>
        <:col :let={{_id, story}} label="Locked at">{story.locked_at}</:col>
        <:col :let={{_id, story}} label="Lock expires at">{story.lock_expires_at}</:col>
        <:action :let={{_id, story}}>
          <div class="sr-only">
            <.link navigate={~p"/stories/#{story}"}>Show</.link>
          </div>
          <.link navigate={~p"/stories/#{story}/edit"}>Edit</.link>
        </:action>
        <:action :let={{id, story}}>
          <.link
            phx-click={JS.push("delete", value: %{id: story.id}) |> hide("##{id}")}
            data-confirm="Are you sure?"
          >
            Delete
          </.link>
        </:action>
      </.table>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Stories.subscribe_stories(socket.assigns.current_scope)
    end

    {:ok,
     socket
     |> assign(:page_title, "Listing Stories")
     |> stream(:stories, Stories.list_stories(socket.assigns.current_scope))}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    story = Stories.get_story!(socket.assigns.current_scope, id)
    {:ok, _} = Stories.delete_story(socket.assigns.current_scope, story)

    {:noreply, stream_delete(socket, :stories, story)}
  end

  @impl true
  def handle_info({type, %CodeMySpec.Stories.Story{}}, socket)
      when type in [:created, :updated, :deleted] do
    {:noreply,
     stream(socket, :stories, Stories.list_stories(socket.assigns.current_scope), reset: true)}
  end
end

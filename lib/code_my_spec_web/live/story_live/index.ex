defmodule CodeMySpecWeb.StoryLive.Index do
  use CodeMySpecWeb, :live_view

  alias CodeMySpec.Stories
  alias CodeMySpec.Stories.Markdown

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        Listing Stories
        <:actions>
          <button phx-click="export_markdown" class="btn btn-outline mr-3">
            <.icon name="hero-arrow-down-tray" /> Export
          </button>
          <.button navigate={~p"/stories/import"} class="btn btn-outline mr-3">
            <.icon name="hero-arrow-up-tray" /> Import
          </.button>
          <.button navigate={~p"/stories/new"}>
            <.icon name="hero-plus" /> New Story
          </.button>
        </:actions>
      </.header>

      <div class="space-y-8">
        <div :for={{id, story} <- @streams.stories} id={id} class="card bg-base-100 shadow-md">
          <div class="card-body">
            <h2
              class="card-title text-2xl mb-4 cursor-pointer hover:text-primary"
              phx-click={JS.navigate(~p"/stories/#{story}")}
            >
              {story.title}
            </h2>

            <p class="text-base-content/80 mb-4 leading-relaxed">
              {story.description}
            </p>

            <div class="mb-4">
              <h3 class="font-semibold mb-2">Acceptance Criteria:</h3>
              <ul class="list-disc list-inside space-y-1 text-base-content/80">
                <li :for={criterion <- parse_acceptance_criteria(story.acceptance_criteria)}>
                  {criterion}
                </li>
              </ul>
            </div>

            <div class="flex items-center justify-between">
              <div class="flex items-center gap-4">
                <.badge color={status_color(story.status)}>
                  Priority: {story.priority}
                </.badge>
              </div>

              <div class="card-actions">
                <.link navigate={~p"/stories/#{story}/edit"} class="btn btn-sm btn-outline">
                  Edit
                </.link>
                <.link
                  phx-click={JS.push("delete", value: %{id: story.id}) |> hide("##{id}")}
                  data-confirm="Are you sure?"
                  class="btn btn-sm btn-error btn-outline"
                >
                  Delete
                </.link>
              </div>
            </div>
          </div>
        </div>
      </div>
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
     |> stream(
       :stories,
       Stories.list_project_stories(socket.assigns.current_scope)
       |> Enum.sort_by(&priority_order/1)
     )}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    story = Stories.get_story!(socket.assigns.current_scope, id)
    {:ok, _} = Stories.delete_story(socket.assigns.current_scope, story)

    {:noreply, stream_delete(socket, :stories, story)}
  end


  @impl true
  def handle_event("export_markdown", _params, socket) do
    stories = Stories.list_project_stories(socket.assigns.current_scope)
    project_name = socket.assigns.current_scope.active_project.name

    story_attrs =
      stories
      |> Enum.sort_by(&priority_order/1)
      |> Enum.map(&story_to_attrs/1)

    markdown_content = Markdown.format_stories(story_attrs, project_name)
    filename = "#{String.downcase(String.replace(project_name, " ", "_"))}_stories.md"

    {:noreply,
     socket
     |> push_event("download_file", %{
       content: markdown_content,
       filename: filename,
       content_type: "text/markdown"
     })}
  end

  @impl true
  def handle_info({type, %CodeMySpec.Stories.Story{}}, socket)
      when type in [:created, :updated, :deleted] do
    {:noreply,
     stream(
       socket,
       :stories,
       Stories.list_project_stories(socket.assigns.current_scope)
       |> Enum.sort_by(&priority_order/1),
       reset: true
     )}
  end


  defp status_color(:in_progress), do: "info"
  defp status_color(:completed), do: "success"
  defp status_color(:dirty), do: "warning"
  defp status_color(_), do: "neutral"

  defp priority_order(%{priority: priority}) when is_integer(priority), do: priority
  defp priority_order(_), do: 999

  defp parse_acceptance_criteria(nil), do: []
  defp parse_acceptance_criteria(""), do: []
  defp parse_acceptance_criteria(criteria) when is_list(criteria), do: criteria

  defp parse_acceptance_criteria(criteria) when is_binary(criteria) do
    criteria
    |> String.split("\n")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp story_to_attrs(story) do
    %{
      title: story.title,
      description: story.description,
      acceptance_criteria: parse_acceptance_criteria(story.acceptance_criteria)
    }
  end
end

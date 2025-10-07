defmodule CodeMySpecWeb.ContentLive.Show do
  use CodeMySpecWeb, :live_view

  alias CodeMySpec.Content
  alias Phoenix.PubSub

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        <.link navigate={~p"/content"} class="link link-primary">
          ← Back to Content
        </.link>
      </.header>

      <div class="mt-6">
        <div class="flex items-center gap-3 mb-4">
          <h1 class="text-3xl font-bold">{@content.title || @content.slug}</h1>
          <.this_badge type={:content_type} value={@content.content_type} />
          <.this_badge type={:parse_status} value={@content.parse_status} />
        </div>

        <div class="grid grid-cols-2 gap-4 mb-6 p-4 bg-base-200 rounded-box">
          <div>
            <span class="font-semibold">Slug:</span>
            <span class="ml-2">{@content.slug}</span>
          </div>
          <div>
            <span class="font-semibold">Type:</span>
            <span class="ml-2">
              <.this_badge type={:content_type} value={@content.content_type} />
            </span>
          </div>
          <div>
            <span class="font-semibold">Status:</span>
            <span class="ml-2">
              <.this_badge type={:parse_status} value={@content.parse_status} />
            </span>
          </div>
          <div>
            <span class="font-semibold">Protected:</span>
            <span class="ml-2">
              <.this_badge type={:protected} value={@content.protected} />
            </span>
          </div>
          <div>
            <span class="font-semibold">Published:</span>
            <span class="ml-2">{format_publish_date(@content.publish_at)}</span>
          </div>
          <div>
            <span class="font-semibold">Expires:</span>
            <span class="ml-2">{format_expiry_date(@content.expires_at)}</span>
          </div>
          <div>
            <span class="font-semibold">Created:</span>
            <span class="ml-2">{format_datetime(@content.inserted_at)}</span>
          </div>
          <div>
            <span class="font-semibold">Updated:</span>
            <span class="ml-2">{format_datetime(@content.updated_at)}</span>
          </div>
        </div>

        <div
          :if={@content.parse_status == :error}
          class="alert alert-error mb-6"
        >
          <div>
            <h2 class="text-lg font-semibold mb-2">Parse Errors</h2>
            <pre class="text-sm whitespace-pre-wrap">{format_parse_errors(@content.parse_errors)}</pre>
            <p class="mt-2 text-sm">
              Fix these errors in the Git repository and re-sync.
            </p>
          </div>
        </div>

        <details class="mb-6">
          <summary class="cursor-pointer font-semibold text-lg mb-2">SEO Metadata</summary>
          <div class="pl-4 space-y-2">
            <div :if={@content.meta_title}>
              <span class="font-semibold">Meta Title:</span>
              <span class="ml-2">{@content.meta_title}</span>
            </div>
            <div :if={@content.meta_description}>
              <span class="font-semibold">Meta Description:</span>
              <span class="ml-2">{@content.meta_description}</span>
            </div>
            <div :if={@content.og_title}>
              <span class="font-semibold">OG Title:</span>
              <span class="ml-2">{@content.og_title}</span>
            </div>
            <div :if={@content.og_description}>
              <span class="font-semibold">OG Description:</span>
              <span class="ml-2">{@content.og_description}</span>
            </div>
            <div :if={@content.og_image}>
              <span class="font-semibold">OG Image:</span>
              <div class="ml-2 mt-2">
                <img src={@content.og_image} alt="OG Image" class="max-w-md border border-base-300" />
              </div>
            </div>
          </div>
        </details>

        <div class="mb-6">
          <h2 class="text-lg font-semibold mb-2">Tags</h2>
          <div :if={Enum.empty?(@tags)} class="opacity-60">No tags</div>
          <div :if={!Enum.empty?(@tags)} class="flex gap-2">
            <span
              :for={tag <- @tags}
              class="badge badge-ghost"
            >
              {tag.name}
            </span>
          </div>
        </div>

        <div class="mb-6">
          <div class="flex items-center justify-between mb-4">
            <h2 class="text-lg font-semibold">Content</h2>
            <div class="btn-group">
              <.button
                phx-click="toggle-view"
                class={if @show_raw, do: "btn-ghost", else: "btn-primary"}
              >
                Processed
              </.button>
              <.button
                phx-click="toggle-view"
                class={if @show_raw, do: "btn-primary", else: "btn-ghost"}
              >
                Raw
              </.button>
            </div>
          </div>

          <div class="card bg-base-100 border border-base-300">
            <div class="card-body">
              <%= if @show_raw do %>
                <pre class="text-sm whitespace-pre-wrap font-mono bg-base-200 p-4 rounded overflow-x-auto">{@content.raw_content}</pre>
              <% else %>
                <%= if @content.processed_content do %>
                  <div class="prose max-w-none">
                    {raw(@content.processed_content)}
                  </div>
                <% else %>
                  <div class="opacity-60 italic">
                    <%= if String.ends_with?(@content.slug, ".heex") do %>
                      HEEx templates are rendered at request time. View raw to see template.
                    <% else %>
                      No processed content available.
                    <% end %>
                  </div>
                <% end %>
              <% end %>
            </div>
          </div>
        </div>

        <div class="flex gap-4">
          <.button
            phx-click="delete"
            data-confirm="Are you sure? Content will re-sync on next Git sync."
            class="btn-error"
          >
            Delete Content
          </.button>
          <.link
            :if={is_published?(@content)}
            navigate={public_url(@content)}
            class="btn btn-success"
          >
            View Public
          </.link>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    scope = socket.assigns.current_scope
    content = Content.get_content!(scope, id)
    tags = Content.get_content_tags(scope, content)

    if connected?(socket) do
      subscribe_content(scope)
    end

    {:ok,
     socket
     |> assign(:page_title, content.title || content.slug)
     |> assign(:content, content)
     |> assign(:tags, tags)
     |> assign(:show_raw, false)}
  end

  @impl true
  def handle_event("toggle-view", _params, socket) do
    {:noreply, assign(socket, :show_raw, !socket.assigns.show_raw)}
  end

  def handle_event("delete", _params, socket) do
    scope = socket.assigns.current_scope
    content = socket.assigns.content
    {:ok, _} = Content.delete_content(scope, content)

    {:noreply,
     socket
     |> put_flash(:info, "Content deleted. Will re-sync on next Git sync.")
     |> push_navigate(to: ~p"/content")}
  end

  @impl true
  def handle_info({:updated, %Content.Content{id: id}}, socket)
      when id == socket.assigns.content.id do
    scope = socket.assigns.current_scope
    content = Content.get_content!(scope, id)
    tags = Content.get_content_tags(scope, content)

    {:noreply,
     socket
     |> assign(:content, content)
     |> assign(:tags, tags)}
  end

  def handle_info({:deleted, %Content.Content{id: id}}, socket)
      when id == socket.assigns.content.id do
    {:noreply,
     socket
     |> put_flash(:info, "Content was deleted")
     |> push_navigate(to: ~p"/content")}
  end

  def handle_info({:sync_completed, _sync_result}, socket) do
    scope = socket.assigns.current_scope

    case Content.get_content!(scope, socket.assigns.content.id) do
      content ->
        tags = Content.get_content_tags(scope, content)

        {:noreply,
         socket
         |> assign(:content, content)
         |> assign(:tags, tags)}
    end
  rescue
    Ecto.NoResultsError ->
      {:noreply,
       socket
       |> put_flash(:info, "Content was removed during sync")
       |> push_navigate(to: ~p"/content")}
  end

  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  defp subscribe_content(scope) do
    PubSub.subscribe(
      CodeMySpec.PubSub,
      "account:#{scope.active_account_id}:project:#{scope.active_project_id}:content"
    )
  end

  defp this_badge(assigns) do
    badge_class =
      case {assigns.type, assigns.value} do
        {:content_type, :blog} -> "badge-info"
        {:content_type, :page} -> "badge-success"
        {:content_type, :landing} -> "badge-secondary"
        {:parse_status, :success} -> "badge-success"
        {:parse_status, :error} -> "badge-error"
        {:parse_status, :pending} -> "badge-warning"
        {:protected, true} -> "badge-warning"
        {:protected, false} -> "badge-ghost"
        _ -> "badge-ghost"
      end

    icon =
      case {assigns.type, assigns.value} do
        {:parse_status, :success} -> " "
        {:parse_status, :error} -> " "
        {:parse_status, :pending} -> "� "
        {:protected, true} -> "= "
        {:protected, false} -> "= "
        _ -> ""
      end

    display_value =
      case {assigns.type, assigns.value} do
        {:protected, true} -> "Protected"
        {:protected, false} -> "Public"
        _ -> assigns.value
      end

    assigns =
      assign(assigns, :badge_class, badge_class)
      |> assign(:icon, icon)
      |> assign(:display_value, display_value)

    ~H"""
    <span class={"badge #{@badge_class}"}>
      {@icon}{@display_value}
    </span>
    """
  end

  defp format_publish_date(nil), do: "Not published"

  defp format_publish_date(datetime) do
    now = DateTime.utc_now()

    if DateTime.compare(datetime, now) == :gt do
      "Scheduled: #{Calendar.strftime(datetime, "%Y-%m-%d %H:%M UTC")}"
    else
      Calendar.strftime(datetime, "%Y-%m-%d %H:%M UTC")
    end
  end

  defp format_expiry_date(nil), do: "Never"
  defp format_expiry_date(datetime), do: Calendar.strftime(datetime, "%Y-%m-%d %H:%M UTC")

  defp format_datetime(datetime), do: Calendar.strftime(datetime, "%Y-%m-%d %H:%M UTC")

  defp format_parse_errors(nil), do: "No error details available"
  defp format_parse_errors(errors) when errors == %{}, do: "No error details available"

  defp format_parse_errors(errors) do
    errors
    |> Enum.map(fn {key, value} -> "#{key}: #{inspect(value, pretty: true)}" end)
    |> Enum.join("\n")
  end

  defp is_published?(content) do
    now = DateTime.utc_now()

    content.parse_status == :success &&
      (is_nil(content.publish_at) || DateTime.compare(content.publish_at, now) != :gt) &&
      (is_nil(content.expires_at) || DateTime.compare(content.expires_at, now) == :gt)
  end

  defp public_url(content) do
    prefix = if content.protected, do: "/private", else: ""
    "#{prefix}/#{content.content_type}/#{content.slug}"
  end
end

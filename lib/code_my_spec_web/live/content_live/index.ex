defmodule CodeMySpecWeb.ContentLive.Index do
  use CodeMySpecWeb, :live_view

  alias CodeMySpec.Content
  alias Phoenix.PubSub

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        Content
        <:actions>
          <.button phx-click="trigger-sync">
            <.icon name="hero-arrow-path" /> Trigger Sync
          </.button>
        </:actions>
      </.header>

      <div class="mb-4 flex gap-2">
        <span class="badge badge-success gap-2">
          {@status_counts.success} Published
        </span>
        <span class="badge badge-error gap-2">
          {@status_counts.error} Errors
        </span>
      </div>

      <div class="mb-4 flex gap-2">
        <.input
          type="select"
          name="filter_type"
          value={@filter_type}
          phx-change="filter-type"
          options={[{"All Types", ""}, {"Blog", "blog"}, {"Page", "page"}, {"Landing", "landing"}]}
        />
        <.input
          type="select"
          name="filter_status"
          value={@filter_status}
          phx-change="filter-status"
          options={[
            {"All Status", ""},
            {"Success", "success"},
            {"Error", "error"},
            {"Pending", "pending"}
          ]}
        />
        <.button :if={@filter_type || @filter_status} phx-click="clear-filters" class="ml-2">
          Clear Filters
        </.button>
      </div>

      <.table
        id="content"
        rows={@streams.content}
        row_click={fn {_id, content} -> JS.navigate(~p"/content/#{content}") end}
      >
        <:col :let={{_id, content}} label="Title">
          <div>
            <div class="font-medium">{content.title || content.slug}</div>
            <div class="text-sm opacity-60">{content.slug}</div>
          </div>
        </:col>
        <:col :let={{_id, content}} label="Type">
          <.this_badge type={:content_type} value={content.content_type} />
        </:col>
        <:col :let={{_id, content}} label="Status">
          <.this_badge
            type={:parse_status}
            value={content.parse_status}
            title={format_parse_errors(content.parse_errors)}
          />
        </:col>
        <:col :let={{_id, content}} label="Published">
          {format_publish_date(content.publish_at)}
        </:col>
        <:col :let={{_id, content}} label="Expires">
          {format_expiry_date(content.expires_at)}
        </:col>
        <:action :let={{_id, content}}>
          <div class="sr-only">
            <.link navigate={~p"/content/#{content}"}>Show</.link>
          </div>
          <.link navigate={~p"/content/#{content}"}>View</.link>
        </:action>
        <:action :let={{id, content}}>
          <.link
            phx-click={JS.push("delete", value: %{id: content.id}) |> hide("##{id}")}
            data-confirm="Are you sure? Content will re-sync on next Git sync."
          >
            Delete
          </.link>
        </:action>
      </.table>

      <div :if={@content_count == 0} class="text-center py-12 opacity-60">
        <%= if @filter_type || @filter_status do %>
          No content matches the selected filters.
        <% else %>
          No content synced yet. Trigger a sync to import content from your Git repository.
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope

    if connected?(socket) do
      subscribe_content(scope)
    end

    content = Content.list_all_content(scope)

    {:ok,
     socket
     |> assign(:page_title, "Content")
     |> assign(:filter_type, nil)
     |> assign(:filter_status, nil)
     |> assign(:content_count, length(content))
     |> assign_status_counts(scope)
     |> stream(:content, content)}
  end

  @impl true
  def handle_event("filter-type", %{"filter_type" => type}, socket) do
    filter_type = if type == "", do: nil, else: type
    {:noreply, apply_filters(socket, filter_type, socket.assigns.filter_status)}
  end

  def handle_event("filter-status", %{"filter_status" => status}, socket) do
    filter_status = if status == "", do: nil, else: status
    {:noreply, apply_filters(socket, socket.assigns.filter_type, filter_status)}
  end

  def handle_event("clear-filters", _params, socket) do
    {:noreply, apply_filters(socket, nil, nil)}
  end

  def handle_event("delete", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope
    content = Content.get_content!(scope, id)
    {:ok, _} = Content.delete_content(scope, content)

    {:noreply, stream_delete(socket, :content, content)}
  end

  def handle_event("trigger-sync", _params, socket) do
    scope = socket.assigns.current_scope

    case CodeMySpec.ContentSync.sync_from_git(scope) do
      {:ok, sync_result} ->
        message = """
        Sync completed successfully!
        Total: #{sync_result.total_files} files
        Success: #{sync_result.successful}
        Errors: #{sync_result.errors}
        Duration: #{sync_result.duration_ms}ms
        """

        {:noreply, put_flash(socket, :info, message)}

      {:error, :no_active_project} ->
        {:noreply, put_flash(socket, :error, "No active project selected")}

      {:error, :project_not_found} ->
        {:noreply, put_flash(socket, :error, "Project not found")}

      {:error, :no_content_repo} ->
        {:noreply, put_flash(socket, :error, "Project has no content repository configured")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Sync failed: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_info({:created, %Content.Content{}}, socket) do
    {:noreply, reload_content(socket)}
  end

  def handle_info({:updated, %Content.Content{}}, socket) do
    {:noreply, reload_content(socket)}
  end

  def handle_info({:deleted, %Content.Content{}}, socket) do
    {:noreply, reload_content(socket)}
  end

  def handle_info(:bulk_delete, socket) do
    {:noreply, reload_content(socket)}
  end

  def handle_info({:sync_completed, _sync_result}, socket) do
    {:noreply, reload_content(socket)}
  end

  defp apply_filters(socket, filter_type, filter_status) do
    scope = socket.assigns.current_scope

    filters =
      %{}
      |> maybe_add_filter(:content_type, filter_type)
      |> maybe_add_filter(:parse_status, filter_status)

    content =
      if filters == %{} do
        Content.list_all_content(scope)
      else
        Content.list_content_with_status(scope, filters)
      end

    socket
    |> assign(:filter_type, filter_type)
    |> assign(:filter_status, filter_status)
    |> assign(:content_count, length(content))
    |> stream(:content, content, reset: true)
  end

  defp maybe_add_filter(filters, _key, nil), do: filters
  defp maybe_add_filter(filters, key, value), do: Map.put(filters, key, value)

  defp reload_content(socket) do
    scope = socket.assigns.current_scope

    socket
    |> assign_status_counts(scope)
    |> apply_filters(socket.assigns.filter_type, socket.assigns.filter_status)
  end

  defp assign_status_counts(socket, scope) do
    counts = Content.count_by_parse_status(scope)
    assign(socket, :status_counts, counts)
  end

  defp subscribe_content(scope) do
    PubSub.subscribe(
      CodeMySpec.PubSub,
      "account:#{scope.active_account_id}:project:#{scope.active_project_id}:content"
    )
  end

  # Helper function for badge component
  defp this_badge(assigns) do
    badge_class =
      case {assigns.type, assigns.value} do
        {:content_type, :blog} -> "badge-info"
        {:content_type, :page} -> "badge-success"
        {:content_type, :landing} -> "badge-secondary"
        {:parse_status, :success} -> "badge-success"
        {:parse_status, :error} -> "badge-error"
        {:parse_status, :pending} -> "badge-warning"
        _ -> "badge-ghost"
      end

    icon =
      case {assigns.type, assigns.value} do
        {:parse_status, :success} -> "OK"
        {:parse_status, :error} -> "ERR"
        {:parse_status, :pending} -> "..."
        _ -> ""
      end

    title = Map.get(assigns, :title)

    assigns = assign(assigns, :badge_class, badge_class) |> assign(:icon, icon) |> assign(:title_attr, title)

    ~H"""
    <span
      class={"badge #{@badge_class}"}
      title={@title_attr}
    >
      {if @icon != "", do: @icon <> " "}{@value}
    </span>
    """
  end

  defp format_publish_date(nil), do: "Draft"

  defp format_publish_date(datetime) do
    now = DateTime.utc_now()

    if DateTime.compare(datetime, now) == :gt do
      "Scheduled: #{Calendar.strftime(datetime, "%Y-%m-%d")}"
    else
      Calendar.strftime(datetime, "%Y-%m-%d")
    end
  end

  defp format_expiry_date(nil), do: "Never"
  defp format_expiry_date(datetime), do: Calendar.strftime(datetime, "%Y-%m-%d")

  defp format_parse_errors(nil), do: nil
  defp format_parse_errors(errors) when errors == %{}, do: nil

  defp format_parse_errors(errors) do
    errors
    |> Enum.map(fn {key, value} -> "#{key}: #{inspect(value)}" end)
    |> Enum.join("\n")
  end
end

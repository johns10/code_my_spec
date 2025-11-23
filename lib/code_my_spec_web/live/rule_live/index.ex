defmodule CodeMySpecWeb.RuleLive.Index do
  use CodeMySpecWeb, :live_view

  alias CodeMySpec.Rules

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        Listing Rules
        <:actions>
          <.button navigate={~p"/app/rules/new"}>
            <.icon name="hero-plus" /> New Rule
          </.button>
        </:actions>
      </.header>

      <.table
        id="rules"
        rows={@streams.rules}
        row_click={fn {_id, rule} -> JS.navigate(~p"/app/rules/#{rule}") end}
      >
        <:col :let={{_id, rule}} label="Name">{rule.name}</:col>
        <:col :let={{_id, rule}} label="Content">{rule.content}</:col>
        <:col :let={{_id, rule}} label="Component type">{rule.component_type}</:col>
        <:col :let={{_id, rule}} label="Session type">{rule.session_type}</:col>
        <:action :let={{_id, rule}}>
          <div class="sr-only">
            <.link navigate={~p"/app/rules/#{rule}"}>Show</.link>
          </div>
          <.link navigate={~p"/app/rules/#{rule}/edit"}>Edit</.link>
        </:action>
        <:action :let={{id, rule}}>
          <.link
            phx-click={JS.push("delete", value: %{id: rule.id}) |> hide("##{id}")}
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
      Rules.subscribe_rules(socket.assigns.current_scope)
    end

    {:ok,
     socket
     |> assign(:page_title, "Listing Rules")
     |> stream(:rules, Rules.list_rules(socket.assigns.current_scope))}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    rule = Rules.get_rule!(socket.assigns.current_scope, id)
    {:ok, _} = Rules.delete_rule(socket.assigns.current_scope, rule)

    {:noreply, stream_delete(socket, :rules, rule)}
  end

  @impl true
  def handle_info({type, %CodeMySpec.Rules.Rule{}}, socket)
      when type in [:created, :updated, :deleted] do
    {:noreply,
     stream(socket, :rules, Rules.list_rules(socket.assigns.current_scope), reset: true)}
  end
end

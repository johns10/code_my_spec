defmodule CodeMySpecWeb.RuleLive.Show do
  use CodeMySpecWeb, :live_view

  alias CodeMySpec.Rules

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        Rule {@rule.id}
        <:subtitle>This is a rule record from your database.</:subtitle>
        <:actions>
          <.button navigate={~p"/app/rules"}>
            <.icon name="hero-arrow-left" />
          </.button>
          <.button navigate={~p"/app/rules/#{@rule}/edit?return_to=show"}>
            <.icon name="hero-pencil-square" /> Edit rule
          </.button>
        </:actions>
      </.header>

      <.list>
        <:item title="Name">{@rule.name}</:item>
        <:item title="Content">{@rule.content}</:item>
        <:item title="Component type">{@rule.component_type}</:item>
        <:item title="Session type">{@rule.session_type}</:item>
      </.list>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    if connected?(socket) do
      Rules.subscribe_rules(socket.assigns.current_scope)
    end

    {:ok,
     socket
     |> assign(:page_title, "Show Rule")
     |> assign(:rule, Rules.get_rule!(socket.assigns.current_scope, id))}
  end

  @impl true
  def handle_info(
        {:updated, %CodeMySpec.Rules.Rule{id: id} = rule},
        %{assigns: %{rule: %{id: id}}} = socket
      ) do
    {:noreply, assign(socket, :rule, rule)}
  end

  def handle_info(
        {:deleted, %CodeMySpec.Rules.Rule{id: id}},
        %{assigns: %{rule: %{id: id}}} = socket
      ) do
    {:noreply,
     socket
     |> put_flash(:error, "The current rule was deleted.")
     |> push_navigate(to: ~p"/app/rules")}
  end

  def handle_info({type, %CodeMySpec.Rules.Rule{}}, socket)
      when type in [:created, :updated, :deleted] do
    {:noreply, socket}
  end
end

defmodule CodeMySpecWeb.RuleLive.Form do
  use CodeMySpecWeb, :live_view

  alias CodeMySpec.Rules
  alias CodeMySpec.Rules.Rule

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        {@page_title}
        <:subtitle>Use this form to manage rule records in your database.</:subtitle>
      </.header>

      <.form for={@form} id="rule-form" phx-change="validate" phx-submit="save">
        <.input field={@form[:name]} type="text" label="Name" />
        <.input field={@form[:content]} type="textarea" label="Content" />
        <.input field={@form[:component_type]} type="text" label="Component type" />
        <.input field={@form[:session_type]} type="text" label="Session type" />
        <footer>
          <.button phx-disable-with="Saving...">Save Rule</.button>
          <.button navigate={return_path(@current_scope, @return_to, @rule)}>Cancel</.button>
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
    rule = Rules.get_rule!(socket.assigns.current_scope, id)

    socket
    |> assign(:page_title, "Edit Rule")
    |> assign(:rule, rule)
    |> assign(:form, to_form(Rules.change_rule(socket.assigns.current_scope, rule)))
  end

  defp apply_action(socket, :new, _params) do
    rule = %Rule{account_id: socket.assigns.current_scope.active_account.id}

    socket
    |> assign(:page_title, "New Rule")
    |> assign(:rule, rule)
    |> assign(:form, to_form(Rules.change_rule(socket.assigns.current_scope, rule)))
  end

  @impl true
  def handle_event("validate", %{"rule" => rule_params}, socket) do
    changeset = Rules.change_rule(socket.assigns.current_scope, socket.assigns.rule, rule_params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"rule" => rule_params}, socket) do
    save_rule(socket, socket.assigns.live_action, rule_params)
  end

  defp save_rule(socket, :edit, rule_params) do
    case Rules.update_rule(socket.assigns.current_scope, socket.assigns.rule, rule_params) do
      {:ok, rule} ->
        {:noreply,
         socket
         |> put_flash(:info, "Rule updated successfully")
         |> push_navigate(
           to: return_path(socket.assigns.current_scope, socket.assigns.return_to, rule)
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_rule(socket, :new, rule_params) do
    case Rules.create_rule(socket.assigns.current_scope, rule_params) do
      {:ok, rule} ->
        {:noreply,
         socket
         |> put_flash(:info, "Rule created successfully")
         |> push_navigate(
           to: return_path(socket.assigns.current_scope, socket.assigns.return_to, rule)
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp return_path(_scope, "index", _rule), do: ~p"/rules"
  defp return_path(_scope, "show", rule), do: ~p"/rules/#{rule}"
end

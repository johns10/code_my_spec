defmodule CodeMySpecWeb.AccountLive.Invitations do
  use CodeMySpecWeb, :live_view

  alias CodeMySpec.Accounts
  alias CodeMySpec.Authorization
  alias CodeMySpec.Invitations
  alias CodeMySpec.Invitations.Invitation
  alias CodeMySpecWeb.AccountLive.Components.Navigation
  alias CodeMySpecWeb.InvitationsLive.Form, as: InviteForm
  alias CodeMySpecWeb.InvitationsLive.Components.PendingInvitations

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} current_path={@current_path}>
      <.live_component
        module={Navigation}
        id="navigation"
        account={@account}
        current_scope={@current_scope}
        active_tab={:invitations}
      />

      <div class="mt-6">
        <div class="card bg-base-100 border border-base-300">
          <div class="card-body">
            <h2 class="card-title">Invitations</h2>

            <.live_component
              module={InviteForm}
              id="invite-form"
              show={@show_invite_form}
              form={@invite_form}
              can_invite={can_manage_members?(@current_scope, @account)}
            />

            <.live_component
              module={PendingInvitations}
              id="pending-invitations"
              invitations={@pending_invitations}
              can_manage={can_manage_members?(@current_scope, @account)}
            />
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    current_scope = socket.assigns.current_scope

    case Accounts.get_account(current_scope, id) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Account not found")
         |> redirect(to: ~p"/accounts")}

      account ->
        pending_invitations = Invitations.list_pending_invitations(current_scope, account.id)

        Phoenix.PubSub.subscribe(CodeMySpec.PubSub, "account:#{account.id}")
        Invitations.subscribe_invitations(current_scope)

        {:ok,
         socket
         |> assign(:account, account)
         |> assign(:pending_invitations, pending_invitations)
         |> assign(:show_invite_form, false)
         |> assign(:invite_form, to_form(Invitation.changeset(%Invitation{}, %{})))}
    end
  end

  @impl true
  def handle_info({:show_invite_form, show}, socket) do
    {:noreply, assign(socket, :show_invite_form, show)}
  end

  def handle_info({:cancel_invite_form}, socket) do
    {:noreply,
     socket
     |> assign(:show_invite_form, false)
     |> assign(:invite_form, to_form(Invitation.changeset(%Invitation{}, %{})))}
  end

  def handle_info({:validate_invitation, invitation_params}, socket) do
    changeset = Invitation.changeset(%Invitation{}, invitation_params)
    {:noreply, assign(socket, :invite_form, to_form(changeset, action: :validate))}
  end

  def handle_info({:send_invitation, invitation_params}, socket) do
    case Invitations.invite_user(
           socket.assigns.current_scope,
           socket.assigns.account.id,
           invitation_params["email"],
           String.to_existing_atom(invitation_params["role"])
         ) do
      {:ok, _invitation} ->
        pending_invitations =
          Invitations.list_pending_invitations(
            socket.assigns.current_scope,
            socket.assigns.account.id
          )

        {:noreply,
         socket
         |> put_flash(:info, "Invitation sent successfully")
         |> assign(:pending_invitations, pending_invitations)
         |> assign(:show_invite_form, false)
         |> assign(:invite_form, to_form(Invitation.changeset(%Invitation{}, %{})))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :invite_form, to_form(changeset))}

      {:error, :user_already_member} ->
        changeset =
          %Invitation{}
          |> Invitation.changeset(invitation_params)
          |> Ecto.Changeset.add_error(:email, "User already has access to this account")

        {:noreply, assign(socket, :invite_form, to_form(changeset))}

      {:error, :not_authorized} ->
        {:noreply, put_flash(socket, :error, "You are not authorized to invite users")}

      {:error, :email_delivery_failed} ->
        {:noreply, put_flash(socket, :error, "Failed to send invitation email")}

      {:error, :no_active_account} ->
        {:noreply, put_flash(socket, :error, "No active account selected")}
    end
  end

  def handle_info({:cancel_invitation, invitation_id}, socket) do
    case Invitations.cancel_invitation(
           socket.assigns.current_scope,
           socket.assigns.account.id,
           invitation_id
         ) do
      {:ok, _invitation} ->
        pending_invitations =
          Invitations.list_pending_invitations(
            socket.assigns.current_scope,
            socket.assigns.account.id
          )

        {:noreply,
         socket
         |> put_flash(:info, "Invitation cancelled successfully")
         |> assign(:pending_invitations, pending_invitations)}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to cancel invitation")}
    end
  end

  @impl true
  def handle_info({:account_updated, account}, socket) do
    {:noreply, assign(socket, :account, account)}
  end

  def handle_info({:created, %Invitation{}}, socket) do
    pending_invitations =
      Invitations.list_pending_invitations(
        socket.assigns.current_scope,
        socket.assigns.account.id
      )

    {:noreply, assign(socket, :pending_invitations, pending_invitations)}
  end

  def handle_info({:updated, %Invitation{}}, socket) do
    pending_invitations =
      Invitations.list_pending_invitations(
        socket.assigns.current_scope,
        socket.assigns.account.id
      )

    {:noreply, assign(socket, :pending_invitations, pending_invitations)}
  end

  def handle_info({:deleted, %Invitation{}}, socket) do
    pending_invitations =
      Invitations.list_pending_invitations(
        socket.assigns.current_scope,
        socket.assigns.account.id
      )

    {:noreply, assign(socket, :pending_invitations, pending_invitations)}
  end

  def handle_info({:email, _email}, socket) do
    {:noreply, socket}
  end

  defp can_manage_members?(current_scope, account) do
    Authorization.authorize(:manage_members, current_scope, account.id)
  end
end

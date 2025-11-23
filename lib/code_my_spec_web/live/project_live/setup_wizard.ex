defmodule CodeMySpecWeb.ProjectLive.SetupWizard do
  use CodeMySpecWeb, :live_view

  alias CodeMySpec.Projects
  alias CodeMySpec.ProjectSetupWizard

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-5xl mx-auto">
        <.header>
          Setup Project: {@project.name}
          <:subtitle>Configure your development environment for this project</:subtitle>
          <:actions>
            <.button navigate={~p"/app/projects/#{@project}"}>
              <.icon name="hero-arrow-left" /> Back to Project
            </.button>
          </:actions>
        </.header>
        
    <!-- Progress Steps -->
        <div class="mt-8">
          <ul class="steps steps-horizontal w-full">
            <li class={"step #{if @current_step >= 1, do: "step-primary"}"}>
              GitHub
            </li>
            <li class={"step #{if @current_step >= 2, do: "step-primary"}"}>
              Repositories
            </li>
            <li class={"step #{if @current_step >= 3, do: "step-primary"}"}>
              VS Code
            </li>
            <li class={"step #{if @current_step >= 4, do: "step-primary"}"}>
              Setup Script
            </li>
          </ul>
        </div>
        
    <!-- Setup Status Cards -->
        <div class="mt-8 grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
          <!-- GitHub Connection Status -->
          <div class="card bg-base-100 border border-base-300">
            <div class="card-body p-4">
              <div class="flex items-center gap-3">
                <div class={"badge badge-lg #{if @setup_status.github_connected, do: "badge-success", else: "badge-ghost"}"}>
                  <.icon
                    name={
                      if @setup_status.github_connected,
                        do: "hero-check-circle",
                        else: "hero-x-circle"
                    }
                    class="size-5"
                  />
                </div>
                <div>
                  <h3 class="font-semibold text-sm">GitHub</h3>
                  <p class="text-xs text-base-content/70">
                    {if @setup_status.github_connected, do: "Connected", else: "Not Connected"}
                  </p>
                </div>
              </div>
            </div>
          </div>
          
    <!-- Code Repository Status -->
          <div class="card bg-base-100 border border-base-300">
            <div class="card-body p-4">
              <div class="flex items-center gap-3">
                <div class={"badge badge-lg #{if @setup_status.code_repo_configured, do: "badge-success", else: "badge-ghost"}"}>
                  <.icon
                    name={
                      if @setup_status.code_repo_configured,
                        do: "hero-check-circle",
                        else: "hero-x-circle"
                    }
                    class="size-5"
                  />
                </div>
                <div>
                  <h3 class="font-semibold text-sm">Code Repo</h3>
                  <p class="text-xs text-base-content/70">
                    {if @setup_status.code_repo_configured, do: "Configured", else: "Not Configured"}
                  </p>
                </div>
              </div>
            </div>
          </div>
          
    <!-- Docs Repository Status -->
          <div class="card bg-base-100 border border-base-300">
            <div class="card-body p-4">
              <div class="flex items-center gap-3">
                <div class={"badge badge-lg #{if @setup_status.docs_repo_configured, do: "badge-success", else: "badge-ghost"}"}>
                  <.icon
                    name={
                      if @setup_status.docs_repo_configured,
                        do: "hero-check-circle",
                        else: "hero-x-circle"
                    }
                    class="size-5"
                  />
                </div>
                <div>
                  <h3 class="font-semibold text-sm">Docs Repo</h3>
                  <p class="text-xs text-base-content/70">
                    {if @setup_status.docs_repo_configured, do: "Configured", else: "Not Configured"}
                  </p>
                </div>
              </div>
            </div>
          </div>
          
    <!-- VS Code Extension Status -->
          <div class="card bg-base-100 border border-base-300">
            <div class="card-body p-4">
              <div class="flex items-center gap-3">
                <div class={"badge badge-lg #{if @setup_status.vscode_extension_connected, do: "badge-success", else: "badge-ghost"}"}>
                  <.icon
                    name={
                      if @setup_status.vscode_extension_connected,
                        do: "hero-check-circle",
                        else: "hero-x-circle"
                    }
                    class="size-5"
                  />
                </div>
                <div>
                  <h3 class="font-semibold text-sm">VS Code</h3>
                  <p class="text-xs text-base-content/70">
                    {if @setup_status.vscode_extension_connected,
                      do: "Connected",
                      else: "Not Connected"}
                  </p>
                </div>
              </div>
            </div>
          </div>
        </div>
        
    <!-- Setup Complete Banner -->
        <div :if={@setup_status.setup_complete} class="mt-8">
          <div class="alert alert-success">
            <.icon name="hero-check-circle" class="size-6" />
            <div>
              <h3 class="font-bold">Setup Complete!</h3>
              <p class="text-sm">
                Your project environment is fully configured and ready to use.
              </p>
            </div>
          </div>
        </div>
        
    <!-- Step Content -->
        <div class="mt-8">
          <%= case @current_step do %>
            <% 1 -> %>
              <.step_github
                setup_status={@setup_status}
                project={@project}
                scope={@current_scope}
                connecting={@connecting}
              />
            <% 2 -> %>
              <.step_repositories
                setup_status={@setup_status}
                project={@project}
                scope={@current_scope}
                repo_form={@repo_form}
                creating_code_repo={@creating_code_repo}
                creating_docs_repo={@creating_docs_repo}
              />
            <% 3 -> %>
              <.step_vscode
                setup_status={@setup_status}
                project={@project}
                extension_instructions_visible={@extension_instructions_visible}
              />
            <% 4 -> %>
              <.step_script
                setup_status={@setup_status}
                project={@project}
                setup_script={@setup_script}
              />
          <% end %>
        </div>
        
    <!-- Navigation -->
        <div class="mt-8 flex justify-between items-center pb-8">
          <.button
            :if={@current_step > 1}
            phx-click="prev_step"
            class="btn btn-outline"
          >
            <.icon name="hero-arrow-left" /> Previous
          </.button>
          <div :if={@current_step == 1}></div>

          <.button
            :if={@current_step < 4}
            phx-click="next_step"
            class="btn btn-primary"
          >
            Next <.icon name="hero-arrow-right" />
          </.button>
          <.button
            :if={@current_step == 4 && @setup_status.setup_complete}
            navigate={~p"/app/projects/#{@project}"}
            class="btn btn-success"
          >
            Complete Setup <.icon name="hero-check-circle" />
          </.button>
        </div>
      </div>
    </Layouts.app>
    """
  end

  # ============================================================================
  # Step 1: GitHub Connection
  # ============================================================================

  attr :setup_status, :map, required: true
  attr :project, :map, required: true
  attr :scope, :map, required: true
  attr :connecting, :boolean, required: true

  defp step_github(assigns) do
    ~H"""
    <div class="card bg-base-100 border border-base-300">
      <div class="card-body">
        <h2 class="card-title">
          <.icon name="hero-link" class="size-6" /> Connect GitHub
        </h2>

        <p class="text-base-content/70">
          Connect your GitHub account to create and manage repositories for this project.
        </p>

        <div :if={!@setup_status.github_connected} class="mt-6">
          <div class="alert alert-info">
            <.icon name="hero-information-circle" class="size-5" />
            <div>
              <h4 class="font-semibold">Why GitHub?</h4>
              <p class="text-sm">
                GitHub integration allows CodeMySpec to automatically create and configure repositories for your code and documentation.
              </p>
            </div>
          </div>

          <div class="mt-6">
            <.button
              phx-click="connect_github"
              phx-disable-with="Connecting..."
              disabled={@connecting}
              class="btn btn-primary btn-lg w-full"
            >
              <.icon name="hero-link" class="size-5" />
              {if @connecting, do: "Connecting to GitHub...", else: "Connect GitHub Account"}
            </.button>
          </div>
        </div>

        <div :if={@setup_status.github_connected} class="mt-6">
          <div class="alert alert-success">
            <.icon name="hero-check-circle" class="size-6" />
            <div>
              <h4 class="font-semibold">GitHub Connected</h4>
              <p class="text-sm">Your GitHub account is connected and ready to use.</p>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # ============================================================================
  # Step 2: Repository Configuration
  # ============================================================================

  attr :setup_status, :map, required: true
  attr :project, :map, required: true
  attr :scope, :map, required: true
  attr :repo_form, :map, required: true
  attr :creating_code_repo, :boolean, required: true
  attr :creating_docs_repo, :boolean, required: true

  defp step_repositories(assigns) do
    ~H"""
    <div class="space-y-6">
      <!-- Code Repository Card -->
      <div class="card bg-base-100 border border-base-300">
        <div class="card-body">
          <h2 class="card-title">
            <.icon name="hero-code-bracket" class="size-6" /> Code Repository
          </h2>

          <p class="text-base-content/70">
            Configure the Git repository for your application code.
          </p>

          <div :if={!@setup_status.code_repo_configured} class="mt-6 space-y-4">
            <div :if={@setup_status.github_connected} class="flex gap-3">
              <.button
                phx-click="create_code_repo"
                phx-disable-with="Creating..."
                disabled={@creating_code_repo}
                class="btn btn-primary flex-1"
              >
                <.icon name="hero-plus-circle" class="size-5" />
                {if @creating_code_repo, do: "Creating Repository...", else: "Create on GitHub"}
              </.button>
            </div>

            <div class="divider">OR</div>

            <.form for={@repo_form} phx-submit="configure_code_repo" phx-change="validate_repo">
              <.input
                field={@repo_form[:code_repo]}
                type="text"
                label="Code Repository URL"
                placeholder="https://github.com/username/project-code.git"
                phx-debounce="500"
              />
              <.button type="submit" class="btn btn-outline w-full">
                <.icon name="hero-check" /> Configure Repository
              </.button>
            </.form>
          </div>

          <div :if={@setup_status.code_repo_configured} class="mt-6">
            <div class="alert alert-success">
              <.icon name="hero-check-circle" class="size-6" />
              <div class="flex-1">
                <h4 class="font-semibold">Code Repository Configured</h4>
                <p class="text-sm font-mono break-all">{@project.code_repo}</p>
              </div>
            </div>
          </div>
        </div>
      </div>
      
    <!-- Docs Repository Card -->
      <div class="card bg-base-100 border border-base-300">
        <div class="card-body">
          <h2 class="card-title">
            <.icon name="hero-document-text" class="size-6" /> Documentation Repository
          </h2>

          <p class="text-base-content/70">
            Configure the Git repository for your project documentation.
          </p>

          <div :if={!@setup_status.docs_repo_configured} class="mt-6 space-y-4">
            <div :if={@setup_status.github_connected} class="flex gap-3">
              <.button
                phx-click="create_docs_repo"
                phx-disable-with="Creating..."
                disabled={@creating_docs_repo}
                class="btn btn-primary flex-1"
              >
                <.icon name="hero-plus-circle" class="size-5" />
                {if @creating_docs_repo, do: "Creating Repository...", else: "Create on GitHub"}
              </.button>
            </div>

            <div class="divider">OR</div>

            <.form for={@repo_form} phx-submit="configure_docs_repo" phx-change="validate_repo">
              <.input
                field={@repo_form[:docs_repo]}
                type="text"
                label="Docs Repository URL"
                placeholder="https://github.com/username/project-docs.git"
                phx-debounce="500"
              />
              <.button type="submit" class="btn btn-outline w-full">
                <.icon name="hero-check" /> Configure Repository
              </.button>
            </.form>
          </div>

          <div :if={@setup_status.docs_repo_configured} class="mt-6">
            <div class="alert alert-success">
              <.icon name="hero-check-circle" class="size-6" />
              <div class="flex-1">
                <h4 class="font-semibold">Docs Repository Configured</h4>
                <p class="text-sm font-mono break-all">{@project.docs_repo}</p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # ============================================================================
  # Step 3: VS Code Extension
  # ============================================================================

  attr :setup_status, :map, required: true
  attr :project, :map, required: true
  attr :extension_instructions_visible, :boolean, required: true

  defp step_vscode(assigns) do
    ~H"""
    <div class="card bg-base-100 border border-base-300">
      <div class="card-body">
        <h2 class="card-title">
          <.icon name="hero-code-bracket-square" class="size-6" /> VS Code Extension
        </h2>

        <p class="text-base-content/70">
          Connect the CodeMySpec VS Code extension to enable real-time synchronization with your development environment.
        </p>

        <div :if={!@setup_status.vscode_extension_connected} class="mt-6 space-y-6">
          <.button
            class="btn btn-primary w-full"
            navigate="https://marketplace.visualstudio.com/items?itemName=CodeMySpec.code-my-spec"
          >
            <.icon name="hero-link" /> Install extension
          </.button>

          <div class="flex items-center justify-center gap-2 text-sm text-base-content/70">
            <div class="loading loading-spinner loading-sm"></div>
            <span>Waiting for extension to connect...</span>
          </div>
        </div>

        <div :if={@setup_status.vscode_extension_connected} class="mt-6">
          <div class="alert alert-success">
            <.icon name="hero-check-circle" class="size-6" />
            <div>
              <h4 class="font-semibold">VS Code Extension Connected</h4>
              <p class="text-sm">Your VS Code extension is connected and active.</p>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # ============================================================================
  # Step 4: Setup Script
  # ============================================================================

  attr :setup_status, :map, required: true
  attr :project, :map, required: true
  attr :setup_script, :string, required: true

  defp step_script(assigns) do
    ~H"""
    <div class="card bg-base-100 border border-base-300">
      <div class="card-body">
        <h2 class="card-title">
          <.icon name="hero-command-line" class="size-6" /> Setup Script
        </h2>

        <p class="text-base-content/70">
          Run this script to initialize your Phoenix project with the configured repositories.
        </p>

        <div class="mt-6 space-y-4">
          <div
            :if={!@setup_status.code_repo_configured && !@setup_status.docs_repo_configured}
            class="alert alert-warning"
          >
            <.icon name="hero-exclamation-triangle" class="size-5" />
            <div>
              <h4 class="font-semibold">No Repositories Configured</h4>
              <p class="text-sm">
                Configure at least one repository to generate a setup script.
              </p>
            </div>
          </div>

          <div :if={@setup_status.code_repo_configured || @setup_status.docs_repo_configured}>
            <div class="mockup-code">
              <pre><code>{@setup_script}</code></pre>
            </div>

            <div class="mt-4 flex gap-3">
              <.button
                phx-click={
                  JS.dispatch("phx:copy",
                    to: "#setup-script-content",
                    detail: %{content: @setup_script}
                  )
                }
                class="btn btn-primary"
              >
                <.icon name="hero-clipboard-document" class="size-5" /> Copy Script
              </.button>

              <.button
                phx-click="download_script"
                class="btn btn-outline"
              >
                <.icon name="hero-arrow-down-tray" class="size-5" /> Download Script
              </.button>
            </div>

            <div id="setup-script-content" style="display: none;">{@setup_script}</div>

            <div class="mt-6 alert alert-info">
              <.icon name="hero-information-circle" class="size-5" />
              <div>
                <h4 class="font-semibold">How to Use</h4>
                <ol class="text-sm space-y-1 mt-2 list-decimal list-inside">
                  <li>
                    Save this script as <code class="px-1 bg-base-300 rounded">setup.sh</code>
                    in your project root
                  </li>
                  <li>
                    Make it executable:
                    <code class="px-1 bg-base-300 rounded">chmod +x setup.sh</code>
                  </li>
                  <li>Run the script: <code class="px-1 bg-base-300 rounded">./setup.sh</code></li>
                </ol>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # ============================================================================
  # Lifecycle Callbacks
  # ============================================================================

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    project = Projects.get_project!(socket.assigns.current_scope, id)
    setup_status = ProjectSetupWizard.get_setup_status(socket.assigns.current_scope, project)

    # Subscribe to presence updates for VS Code extension
    if connected?(socket) do
      Phoenix.PubSub.subscribe(
        CodeMySpec.PubSub,
        "vscode:project:#{project.id}"
      )

      Projects.subscribe_projects(socket.assigns.current_scope)
    end

    # Generate setup script
    {:ok, setup_script} = ProjectSetupWizard.generate_setup_script(project)

    {:ok,
     socket
     |> assign(:page_title, "Setup Project")
     |> assign(:project, project)
     |> assign(:setup_status, setup_status)
     |> assign(:current_step, calculate_current_step(setup_status))
     |> assign(:connecting, false)
     |> assign(:creating_code_repo, false)
     |> assign(:creating_docs_repo, false)
     |> assign(:extension_instructions_visible, false)
     |> assign(:setup_script, setup_script)
     |> assign_repo_form()}
  end

  # ============================================================================
  # Event Handlers
  # ============================================================================

  @impl true
  def handle_event("next_step", _params, socket) do
    {:noreply, assign(socket, :current_step, min(socket.assigns.current_step + 1, 4))}
  end

  @impl true
  def handle_event("prev_step", _params, socket) do
    {:noreply, assign(socket, :current_step, max(socket.assigns.current_step - 1, 1))}
  end

  @impl true
  def handle_event("connect_github", _params, socket) do
    redirect_uri = url(~p"/auth/github/callback")

    case ProjectSetupWizard.connect_github(socket.assigns.current_scope, redirect_uri) do
      {:ok, authorization_url} ->
        {:noreply,
         socket
         |> assign(:connecting, true)
         |> redirect(external: authorization_url)}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to connect GitHub: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_event("create_code_repo", _params, socket) do
    socket = assign(socket, :creating_code_repo, true)

    case ProjectSetupWizard.create_code_repo(
           socket.assigns.current_scope,
           socket.assigns.project
         ) do
      {:ok, project} ->
        setup_status =
          ProjectSetupWizard.get_setup_status(socket.assigns.current_scope, project)

        {:ok, setup_script} = ProjectSetupWizard.generate_setup_script(project)

        {:noreply,
         socket
         |> assign(:project, project)
         |> assign(:setup_status, setup_status)
         |> assign(:setup_script, setup_script)
         |> assign(:creating_code_repo, false)
         |> put_flash(:info, "Code repository created successfully!")}

      {:error, reason} ->
        {:noreply,
         socket
         |> assign(:creating_code_repo, false)
         |> put_flash(:error, "Failed to create code repository: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_event("create_docs_repo", _params, socket) do
    socket = assign(socket, :creating_docs_repo, true)

    case ProjectSetupWizard.create_docs_repo(
           socket.assigns.current_scope,
           socket.assigns.project
         ) do
      {:ok, project} ->
        setup_status =
          ProjectSetupWizard.get_setup_status(socket.assigns.current_scope, project)

        {:ok, setup_script} = ProjectSetupWizard.generate_setup_script(project)

        {:noreply,
         socket
         |> assign(:project, project)
         |> assign(:setup_status, setup_status)
         |> assign(:setup_script, setup_script)
         |> assign(:creating_docs_repo, false)
         |> put_flash(:info, "Docs repository created successfully!")}

      {:error, reason} ->
        {:noreply,
         socket
         |> assign(:creating_docs_repo, false)
         |> put_flash(:error, "Failed to create docs repository: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_event("validate_repo", %{"repo_urls" => repo_params}, socket) do
    changeset =
      socket.assigns.project
      |> Projects.change_project(repo_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :repo_form, to_form(changeset))}
  end

  @impl true
  def handle_event("configure_code_repo", %{"repo_urls" => repo_params}, socket) do
    case ProjectSetupWizard.configure_repositories(
           socket.assigns.current_scope,
           socket.assigns.project,
           %{code_repo: repo_params["code_repo"]}
         ) do
      {:ok, project} ->
        setup_status =
          ProjectSetupWizard.get_setup_status(socket.assigns.current_scope, project)

        {:ok, setup_script} = ProjectSetupWizard.generate_setup_script(project)

        {:noreply,
         socket
         |> assign(:project, project)
         |> assign(:setup_status, setup_status)
         |> assign(:setup_script, setup_script)
         |> assign_repo_form()
         |> put_flash(:info, "Code repository configured successfully!")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         socket
         |> assign(:repo_form, to_form(changeset))
         |> put_flash(:error, "Invalid repository URL")}
    end
  end

  @impl true
  def handle_event("configure_docs_repo", %{"repo_urls" => repo_params}, socket) do
    case ProjectSetupWizard.configure_repositories(
           socket.assigns.current_scope,
           socket.assigns.project,
           %{docs_repo: repo_params["docs_repo"]}
         ) do
      {:ok, project} ->
        setup_status =
          ProjectSetupWizard.get_setup_status(socket.assigns.current_scope, project)

        {:ok, setup_script} = ProjectSetupWizard.generate_setup_script(project)

        {:noreply,
         socket
         |> assign(:project, project)
         |> assign(:setup_status, setup_status)
         |> assign(:setup_script, setup_script)
         |> assign_repo_form()
         |> put_flash(:info, "Docs repository configured successfully!")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         socket
         |> assign(:repo_form, to_form(changeset))
         |> put_flash(:error, "Invalid repository URL")}
    end
  end

  @impl true
  def handle_event("toggle_extension_instructions", _params, socket) do
    {:noreply,
     assign(
       socket,
       :extension_instructions_visible,
       !socket.assigns.extension_instructions_visible
     )}
  end

  @impl true
  def handle_event("download_script", _params, socket) do
    # In a real implementation, this would trigger a file download
    # For now, we'll just show a flash message
    {:noreply, put_flash(socket, :info, "Copy the script and save it as setup.sh")}
  end

  # ============================================================================
  # PubSub Handlers
  # ============================================================================

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: "presence_diff"}, socket) do
    # VS Code extension presence changed
    setup_status =
      ProjectSetupWizard.get_setup_status(socket.assigns.current_scope, socket.assigns.project)

    {:noreply, assign(socket, :setup_status, setup_status)}
  end

  @impl true
  def handle_info({:updated, %CodeMySpec.Projects.Project{} = project}, socket) do
    if project.id == socket.assigns.project.id do
      setup_status = ProjectSetupWizard.get_setup_status(socket.assigns.current_scope, project)
      {:ok, setup_script} = ProjectSetupWizard.generate_setup_script(project)

      {:noreply,
       socket
       |> assign(:project, project)
       |> assign(:setup_status, setup_status)
       |> assign(:setup_script, setup_script)
       |> assign_repo_form()}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({type, %CodeMySpec.Projects.Project{}}, socket)
      when type in [:created, :deleted] do
    {:noreply, socket}
  end

  # ============================================================================
  # Private Helpers
  # ============================================================================

  defp assign_repo_form(socket) do
    changeset = Projects.change_project(socket.assigns.current_scope, socket.assigns.project, %{})
    assign(socket, :repo_form, to_form(changeset))
  end

  defp calculate_current_step(setup_status) do
    cond do
      !setup_status.github_connected -> 1
      !setup_status.code_repo_configured && !setup_status.docs_repo_configured -> 2
      !setup_status.vscode_extension_connected -> 3
      true -> 4
    end
  end
end

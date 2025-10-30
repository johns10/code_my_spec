defmodule CodeMySpecWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use CodeMySpecWeb, :html

  import CodeMySpecWeb.AccountLive.Components.AccountsBreadcrumb
  import CodeMySpecWeb.ProjectLive.Components.ProjectBreadcrumb

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  attr :current_path, :string, default: "/"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <header class="navbar bg-base-100 shadow-sm">
      <div class="flex-1">
        <a href="/" class="flex-1 flex w-fit items-center gap-2">
          <img src={~p"/images/logo.svg"} width="36" />
          <span class="text-sm font-semibold">v{Application.spec(:phoenix, :vsn)}</span>
        </a>
      </div>
      <div class="flex-none">
        <div class="flex items-center space-x-2">
          <ul class="menu menu-horizontal px-1">
            <li><.link href={~p"/accounts"} class="btn btn-ghost">Accounts</.link></li>
            <li><.link href={~p"/projects"} class="btn btn-ghost">Projects</.link></li>
            <li><.link href={~p"/stories"} class="btn btn-ghost">Stories</.link></li>
            <li>
              <details>
                <summary>Components</summary>
                <ul class="bg-base-100 rounded-t-none p-2">
                  <li><.link href={~p"/components"} class="text-sm">Components</.link></li>
                  <li><.link href={~p"/components/scheduler"} class="text-sm">Scheduler</.link></li>
                </ul>
              </details>
            </li>
            <li><.link href={~p"/content_admin"} class="btn btn-ghost">Content</.link></li>
            <li>
              <.link href={~p"/architecture"} class="btn btn-ghost">Architecture</.link>
            </li>
          </ul>
          <.theme_toggle />
        </div>
      </div>
    </header>

    <%= if @current_scope do %>
      <div class="breadcrumbs text-sm px-8">
        <ul>
          <li><.account_breadcrumb scope={@current_scope} current_path={@current_path} /></li>
          <li><.project_breadcrumb scope={@current_scope} current_path={@current_path} /></li>
        </ul>
      </div>
    <% end %>

    <main class="px-4 py-20 sm:px-6 lg:px-8">
      <div class="mx-auto max-w-2xl space-y-4">
        {render_slot(@inner_block)}
      </div>
    </main>

    <.flash_group flash={@flash} />
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Renders the marketing/public layout for home page and blog.

  This layout provides a clean, marketing-focused design without app navigation.

  ## Examples

      <Layouts.marketing flash={@flash}>
        <h1>Content</h1>
      </Layouts.marketing>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :page_title, :string, default: "CodeMySpec"

  slot :inner_block, required: true

  def marketing(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-base-200 via-base-100 to-base-200">
      <div class="max-w-7xl mx-auto px-4 py-8">
        <!-- Navbar -->
        <div class="navbar bg-base-100/50 backdrop-blur-lg rounded-box shadow-xl mb-20">
          <div class="navbar-start">
            <a href="/" class="btn btn-ghost text-xl font-bold normal-case">CodeMySpec</a>
          </div>

          <div class="navbar-end gap-2">
            <ul class="menu menu-horizontal px-1">
              <li>
                <a href="/blog" class="gap-2">
                  <.icon name="hero-document-text" class="w-4 h-4" /> Blog
                </a>
              </li>
            </ul>
            <.theme_toggle />
          </div>
        </div>
        
    <!-- Content -->
        {render_slot(@inner_block)}
        
    <!-- Footer -->
        <footer class="footer footer-center p-10 bg-base-200 text-base-content rounded-box shadow-inner mt-20">
          <!--<nav class="grid grid-flow-col gap-6">
            <a href="/blog" class="link link-hover inline-flex items-center gap-2">
              <.icon name="hero-document-text" class="w-4 h-4" />
              Blog
            </a>
            <a
              href="https://github.com/phoenixframework/phoenix"
              class="link link-hover inline-flex items-center gap-2"
            >
              <.icon name="hero-code-bracket" class="w-4 h-4" />
              GitHub
            </a>
            <a href="/users/register" class="link link-hover inline-flex items-center gap-2">
              <.icon name="hero-user-plus" class="w-4 h-4" />
              Get Started
            </a>
          </nav>-->

          <aside class="items-center grid-flow-col">
            <div>
              <p class="font-bold text-lg">CodeMySpec</p>
              <p class="text-sm text-base-content/70">
                Process-guided AI development for Phoenix applications
              </p>
            </div>
          </aside>
        </footer>
      </div>

      <.flash_group flash={@flash} />
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 transition-[left]" />

      <button
        phx-click={JS.dispatch("phx:set-theme", detail: %{theme: "system"})}
        class="flex p-2 cursor-pointer w-1/3"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        phx-click={JS.dispatch("phx:set-theme", detail: %{theme: "light"})}
        class="flex p-2 cursor-pointer w-1/3"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        phx-click={JS.dispatch("phx:set-theme", detail: %{theme: "dark"})}
        class="flex p-2 cursor-pointer w-1/3"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end
end

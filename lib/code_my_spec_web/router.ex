defmodule CodeMySpecWeb.Router do
  use CodeMySpecWeb, :router

  import CodeMySpecWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {CodeMySpecWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :mcp do
    plug :accepts, ["json", "sse"]
  end

  pipeline :mcp_protected do
    plug :accepts, ["json", "sse"]
    plug :require_oauth_token
  end

  scope "/", CodeMySpecWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  # OAuth2 routes
  scope "/oauth", CodeMySpecWeb do
    pipe_through :browser

    get "/authorize", OAuthController, :authorize
    post "/authorize", OAuthController, :create
    delete "/authorize", OAuthController, :delete
  end

  # OAuth2 API endpoints (no CSRF protection)
  scope "/oauth", CodeMySpecWeb do
    pipe_through :api

    post "/token", OAuthController, :token
    post "/revoke", OAuthController, :revoke
    post "/register", OAuthController, :register
  end

  # MCP OAuth discovery endpoints
  scope "/.well-known", CodeMySpecWeb do
    pipe_through :api

    get "/oauth-protected-resource", OAuthController, :protected_resource_metadata
    get "/oauth-authorization-server", OAuthController, :authorization_server_metadata
  end

  # MCP Server routes
  scope "/mcp" do
    pipe_through :mcp_protected

    forward "/stories", Hermes.Server.Transport.StreamableHTTP.Plug,
      server: CodeMySpec.MCPServers.StoriesServer

    forward "/components", Hermes.Server.Transport.StreamableHTTP.Plug,
      server: CodeMySpec.MCPServers.ComponentsServer
  end

  # API routes
  scope "/api", CodeMySpecWeb do
    pipe_through [:api, :require_oauth_token]

    resources "/sessions", SessionsController, except: [:edit, :new, :update, :delete] do
      get "/next-command", SessionsController, :next_command
      post "/submit-result/:interaction_id", SessionsController, :submit_result
    end

    post "/project-coordinator/sync-requirements", ProjectCoordinatorController, :sync_requirements
    get "/project-coordinator/next-actions", ProjectCoordinatorController, :next_actions
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:code_my_spec, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: CodeMySpecWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", CodeMySpecWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [
        {CodeMySpecWeb.UserAuth, :require_authenticated},
        {CodeMySpecWeb.Live.CurrentPathHook, :default}
      ] do
      live "/users/settings", UserLive.Settings, :edit
      live "/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email
      live "/users/preferences", UserPreferenceLive.Form, :edit
      live "/accounts", AccountLive.Index, :index
      live "/accounts/picker", AccountLive.Picker, :index
      live "/accounts/:id", AccountLive.Manage, :show
      live "/accounts/:id/manage", AccountLive.Manage, :show
      live "/accounts/:id/members", AccountLive.Members, :show
      live "/accounts/:id/invitations", AccountLive.Invitations, :show
      live "/projects", ProjectLive.Index, :index
      live "/projects/picker", ProjectLive.Picker, :index
      live "/projects/new", ProjectLive.Form, :new
      live "/projects/:id", ProjectLive.Show, :show
      live "/projects/:id/edit", ProjectLive.Form, :edit

      live "/stories", StoryLive.Index, :index
      live "/stories/new", StoryLive.Form, :new
      live "/stories/import", StoryLive.Import, :import
      live "/stories/:id", StoryLive.Show, :show
      live "/stories/:id/edit", StoryLive.Form, :edit

      live "/components", ComponentLive.Index, :index
      live "/components/scheduler", ComponentLive.Scheduler, :index
      live "/components/new", ComponentLive.Form, :new
      live "/components/:id/edit", ComponentLive.Form, :edit

      live "/rules", RuleLive.Index, :index
      live "/rules/new", RuleLive.Form, :new
      live "/rules/:id", RuleLive.Show, :show
      live "/rules/:id/edit", RuleLive.Form, :edit

      live "/architecture", ArchitectureLive.Index, :index
    end

    post "/users/update-password", UserSessionController, :update_password
  end

  scope "/", CodeMySpecWeb do
    pipe_through [:browser]

    live_session :current_user,
      on_mount: [{CodeMySpecWeb.UserAuth, :mount_current_scope}] do
      live "/users/register", UserLive.Registration, :new
      live "/users/log-in", UserLive.Login, :new
      live "/users/log-in/:token", UserLive.Confirmation, :new
      live "/invitations/accept", InvitationsLive.Accept, :new
      live "/invitations/accept/:token", InvitationsLive.Accept, :new
    end

    post "/users/log-in", UserSessionController, :create
    delete "/users/log-out", UserSessionController, :delete
  end
end

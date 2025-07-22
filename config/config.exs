# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :code_my_spec, :scopes,
  user: [
    default: true,
    module: CodeMySpec.Users.Scope,
    assign_key: :current_scope,
    access_path: [:active_account, :id],
    schema_key: :account_id,
    schema_type: :id,
    schema_table: :accounts,
    test_data_fixture: CodeMySpec.UsersFixtures,
    test_setup_helper: :register_log_in_setup_account
  ]

config :code_my_spec,
  ecto_repos: [CodeMySpec.Repo],
  generators: [timestamp_type: :utc_datetime]

# Configures the endpoint
config :code_my_spec, CodeMySpecWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: CodeMySpecWeb.ErrorHTML, json: CodeMySpecWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: CodeMySpec.PubSub,
  live_view: [signing_salt: "WM19jFVv"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :code_my_spec, CodeMySpec.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  code_my_spec: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.1.7",
  code_my_spec: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :code_my_spec, :agent_implementations, %{
  unit_coder: :claude_code
}


config :code_my_spec, ExOauth2Provider,
  repo: CodeMySpec.Repo,
  access_token: CodeMySpec.Oauth.AccessToken,
  application: CodeMySpec.Oauth.Application,
  access_grant: CodeMySpec.Oauth.AccessGrant,
  resource_owner: CodeMySpec.Users.User

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"

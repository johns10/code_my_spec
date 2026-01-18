import Config

config :code_my_spec, CodeMySpecWeb.Endpoint,
  server: false,
  pubsub_server: CodeMySpec.PubSub

config :code_my_spec, adapter: Ecto.Adapters.SQLite3

config :code_my_spec, CodeMySpec.Repo,
  database: Path.expand("~/.codemyspec/cli.db"),
  pool_size: 5,
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  log: false

# Configure Stories to use remote client for API calls
# Note: api_base_url and oauth_base_url are set in runtime.exs after env files are loaded
config :code_my_spec,
  stories_implementation: CodeMySpec.Stories.RemoteClient

# OAuth token will be configured at runtime or read from environment
# config :code_my_spec, :oauth_token, System.get_env("OAUTH_TOKEN")

# Disable console logging to prevent cluttering the TUI
config :logger, :default_handler, false

# Configure file backend for logging (added at runtime in Application.start/2)
config :logger, :file_log,
  path: Path.expand(".code_my_spec/internal/cli.log"),
  level: :debug,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id, :mfa]

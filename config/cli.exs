import Config

config :code_my_spec, CodeMySpecWeb.Endpoint,
  server: false,
  pubsub_server: CodeMySpec.PubSub

config :code_my_spec, adapter: Ecto.Adapters.SQLite3

config :code_my_spec, CodeMySpec.Repo,
  database: Path.expand("~/.codemyspec/cli.db"),
  pool_size: 5,
  stacktrace: true,
  show_sensitive_data_on_connection_error: true

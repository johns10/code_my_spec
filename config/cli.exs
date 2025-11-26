import Config

config :code_my_spec, CodeMySpecWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "uQsFkBLrXNG5yxrQkMHNLOAi5NcrEzpZut3YYEOlAFiuhpoynMd+/rJBgz6FSWsg",
  server: false

config :code_my_spec, adapter: Ecto.Adapters.SQLite3

config :code_my_spec, CodeMySpec.Repo,
  database: Path.expand("~/.codemyspec/cli.db"),
  pool_size: 5,
  stacktrace: true,
  show_sensitive_data_on_connection_error: true

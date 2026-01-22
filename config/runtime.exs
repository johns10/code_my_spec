import Config
import Dotenvy

# Load environment variables from .env files
env_dir_prefix = System.get_env("RELEASE_ROOT") || Path.expand("./envs")

source!([
  Path.absname(".env", env_dir_prefix),
  Path.absname("#{config_env()}.env", env_dir_prefix),
  System.get_env()
])

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/code_my_spec start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :code_my_spec, CodeMySpecWeb.Endpoint, server: true
end

# Burrito CLI binary configuration
# Detected by __BURRITO_BIN_PATH env var (set by Burrito wrapper at runtime)
is_burrito_binary = System.get_env("__BURRITO_BIN_PATH") != nil

if is_burrito_binary or config_env() == :cli do
  # CLI mode - SQLite, no web server, remote API calls
  config :code_my_spec, CodeMySpecWeb.Endpoint,
    server: false,
    pubsub_server: CodeMySpec.PubSub

  config :code_my_spec, CodeMySpec.Repo,
    database: Path.expand("~/.codemyspec/cli.db"),
    pool_size: 5,
    stacktrace: true,
    show_sensitive_data_on_connection_error: true,
    log: false

  # For Burrito binaries, use production URLs directly since env files aren't shipped
  # For dev CLI (MIX_ENV=cli), allow overriding via env vars
  {api_url, oauth_url} =
    if is_burrito_binary do
      {"https://codemyspec.com", "https://codemyspec.com"}
    else
      {
        env!("API_BASE_URL", :string, "http://localhost:4000"),
        env!("OAUTH_BASE_URL", :string, "http://localhost:4000")
      }
    end

  config :code_my_spec,
    api_base_url: api_url,
    oauth_base_url: oauth_url,
    stories_implementation: CodeMySpec.Stories.RemoteClient

  # Disable console logging for CLI
  config :logger, :default_handler, false

  config :logger, :file_log,
    path: Path.expand("~/.codemyspec/cli.log"),
    level: :debug,
    format: "$time $metadata[$level] $message\n",
    metadata: [:request_id, :mfa]
else
  # Web app mode
  config :code_my_spec,
    github_client_id: env!("GITHUB_CLIENT_ID"),
    github_client_secret: env!("GITHUB_CLIENT_SECRET"),
    google_client_id: env!("GOOGLE_CLIENT_ID"),
    google_client_secret: env!("GOOGLE_CLIENT_SECRET"),
    oauth_base_url: env!("OAUTH_BASE_URL", :string, ""),
    deploy_key: env!("DEPLOY_KEY")

  if config_env() == :prod do
    database_url =
      System.get_env("DATABASE_URL") ||
        raise """
        environment variable DATABASE_URL is missing.
        For example: ecto://USER:PASS@HOST/DATABASE
        """

    maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

    config :code_my_spec, CodeMySpec.Repo,
      url: database_url,
      pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
      socket_options: maybe_ipv6

    secret_key_base =
      System.get_env("SECRET_KEY_BASE") ||
        raise """
        environment variable SECRET_KEY_BASE is missing.
        You can generate one by calling: mix phx.gen.secret
        """

    host = System.get_env("PHX_HOST") || "example.com"
    port = String.to_integer(System.get_env("PORT") || "8080")

    config :code_my_spec, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

    config :code_my_spec, CodeMySpecWeb.Endpoint,
      url: [host: host, port: 443, scheme: "https"],
      http: [ip: {0, 0, 0, 0}, port: port],
      secret_key_base: secret_key_base

    config :code_my_spec, CodeMySpec.Mailer,
      adapter: Swoosh.Adapters.Mailgun,
      api_key: System.get_env("MAILGUN_API_KEY"),
      domain: System.get_env("MAILGUN_DOMAIN")
  end

end

defmodule CodeMySpecCli.Application do
  @moduledoc """
  CLI application.

  CLI args come from either:
  - Application env :cli_args (set by mix task)
  - Burrito.Util.Args (when running as binary)
  """
  use Application

  @impl true
  def start(_type, _start_args) do
    ensure_db_directory()

    args = get_cli_args()

    children = [
      CodeMySpecCli.WebServer.Telemetry,
      CodeMySpec.Repo,
      CodeMySpec.Vault,
      CodeMySpecCli.Migrator,
      {Phoenix.PubSub, name: CodeMySpec.PubSub},
      {Registry, keys: :unique, name: CodeMySpecCli.Registry},
      CodeMySpec.Sessions.InteractionRegistry,
      {CodeMySpecCli.CliRunner, args}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: CodeMySpecCli.Supervisor)
  end

  defp get_cli_args do
    Application.get_env(:code_my_spec, :cli_args) || burrito_args()
  end

  defp burrito_args do
    if System.get_env("__BURRITO_BIN_PATH"), do: Burrito.Util.Args.get_arguments()
  end

  defp ensure_db_directory do
    db_path = Path.expand("~/.codemyspec/cli.db")
    db_path |> Path.dirname() |> File.mkdir_p!()
    unless File.exists?(db_path), do: File.write!(db_path, "")
  end
end

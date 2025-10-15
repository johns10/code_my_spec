defmodule Mix.Tasks.Sync.Data do
  @moduledoc """
  Syncs data between environments safely.

  ## Usage

      # Export account data to JSON
      mix sync.data export --account-id 4 --output /tmp/account_4.json

      # Import account data from JSON
      mix sync.data import --file /tmp/account_4.json

      # Full database sync (DESTRUCTIVE)
      mix sync.data full --from local --to prod

  ## Options

    * `--account-id` - Account ID to export
    * `--output` - Output file path for export
    * `--file` - Input file path for import
    * `--from` - Source environment (local/prod/uat)
    * `--to` - Target environment (local/prod/uat)
    * `--dry-run` - Show what would be synced without doing it

  """

  use Mix.Task
  require Logger

  @shortdoc "Sync data between environments"

  @doc false
  def run(args) do
    Mix.Task.run("app.start")

    {opts, cmd, _} =
      OptionParser.parse(args,
        strict: [
          account_id: :integer,
          output: :string,
          file: :string,
          from: :string,
          to: :string,
          dry_run: :boolean
        ]
      )

    case cmd do
      ["export"] -> export_account(opts)
      ["import"] -> import_account(opts)
      ["full"] -> full_sync(opts)
      _ -> show_help()
    end
  end

  defp export_account(opts) do
    account_id = Keyword.fetch!(opts, :account_id)
    output = Keyword.fetch!(opts, :output)

    CodeMySpec.Utils.Data.export_account(account_id, output)
  end

  defp import_account(opts) do
    file = Keyword.fetch!(opts, :file)
    dry_run = Keyword.get(opts, :dry_run, false)

    CodeMySpec.Utils.Data.import_account(file, dry_run: dry_run)
  end

  defp full_sync(opts) do
    from = Keyword.fetch!(opts, :from)
    to = Keyword.fetch!(opts, :to)

    Logger.error("Full sync from #{from} to #{to} is not yet implemented.")
    Logger.error("Use pg_dump/restore for full database syncs (see docs/devops.md)")
    System.halt(1)
  end

  defp show_help do
    IO.puts("""
    Usage: mix sync.data [command] [options]

    Commands:
      export    Export account data to JSON file
      import    Import account data from JSON file
      full      Full database sync (not recommended)

    Examples:
      mix sync.data export --account-id 4 --output /tmp/account_4.json
      mix sync.data import --file /tmp/account_4.json --dry-run
      mix sync.data import --file /tmp/account_4.json

    For full database sync, use pg_dump/restore (see docs/devops.md)
    """)
  end
end

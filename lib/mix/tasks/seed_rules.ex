defmodule Mix.Tasks.SeedRules do
  @moduledoc """
  Seeds rules from markdown files in the docs/rules directory.

  ## Usage

      mix seed_rules [account_id]

  ## Arguments

      account_id    The account ID to seed rules for (required)

  ## Examples

      mix seed_rules 1
      mix seed_rules abc123

  """

  use Mix.Task
  require Logger

  alias CodeMySpec.Rules.RulesSeeder
  alias CodeMySpec.Users.Scope

  @shortdoc "Seed rules from markdown files"

  def run([]) do
    Mix.shell().error("Account ID is required")
    Mix.shell().info("Usage: mix seed_rules <account_id>")
    System.halt(1)
  end

  def run([account_id | _]) do
    Mix.shell().info("=== Rules Seeder ===")
    Mix.shell().info("Account ID: #{account_id}")

    # Start the application to ensure repos are available
    {:ok, _} = Application.ensure_all_started(:code_my_spec)

    numeric_account_id = String.to_integer(account_id)
    scope = %Scope{active_account: %CodeMySpec.Accounts.Account{id: numeric_account_id}}

    case RulesSeeder.seed_account_rules(scope) do
      {:ok, rules} ->
        Mix.shell().info("✓ Successfully seeded #{length(rules)} rules")

        rules
        |> Enum.each(fn rule ->
          Mix.shell().info("  - #{rule.name} (#{rule.component_type}/#{rule.session_type})")
        end)

      {:error, :rules_directory_not_found} ->
        Mix.shell().error("✗ Rules directory 'docs/rules' not found")
        Mix.shell().info("Please create the directory and add rule files")
    end

    Mix.shell().info("=== Seeding Complete ===")
  end
end

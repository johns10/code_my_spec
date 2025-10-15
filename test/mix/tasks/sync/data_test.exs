defmodule Mix.Tasks.Sync.DataTest do
  use CodeMySpec.DataCase
  alias Mix.Tasks.Sync.Data

  import CodeMySpec.UsersFixtures
  import CodeMySpec.ComponentsFixtures

  describe "export/import" do
    setup do
      scope = full_scope_fixture()

      %{
        account: scope.active_account,
        user: scope.user,
        project: scope.active_project,
        scope: scope
      }
    end

    test "exports and imports account data successfully", %{account: account} do
      temp_file = Path.join(System.tmp_dir!(), "account_export_#{:rand.uniform(100_000)}.json")

      try do
        # Export account data
        Data.run(["export", "--account-id", to_string(account.id), "--output", temp_file])

        assert File.exists?(temp_file)

        # Verify export structure
        exported_data = File.read!(temp_file) |> Jason.decode!(keys: :atoms)
        assert exported_data.account.id == account.id
        assert exported_data.account.name == account.name
        assert is_list(exported_data.users)
        assert is_list(exported_data.projects)
        assert is_list(exported_data.components)

        # Import should work in dry-run mode
        Data.run(["import", "--file", temp_file, "--dry-run"])

        # Actual import (will upsert existing account)
        Data.run(["import", "--file", temp_file])
      after
        File.rm(temp_file)
      end
    end

    test "export includes all related data", %{account: account, scope: scope} do
      # Create component
      component_fixture(scope)

      temp_file =
        Path.join(System.tmp_dir!(), "account_full_export_#{:rand.uniform(100_000)}.json")

      try do
        Data.run(["export", "--account-id", to_string(account.id), "--output", temp_file])

        exported_data = File.read!(temp_file) |> Jason.decode!(keys: :atoms)

        # Verify all data types are exported
        assert length(exported_data.users) > 0
        assert length(exported_data.projects) > 0
        assert length(exported_data.components) > 0
        assert length(exported_data.members) > 0
      after
        File.rm(temp_file)
      end
    end

    test "import handles missing account gracefully" do
      temp_file = Path.join(System.tmp_dir!(), "nonexistent_account.json")

      File.write!(
        temp_file,
        Jason.encode!(%{
          account: %{
            name: "New Account",
            slug: "new-account-#{:rand.uniform(100_000)}",
            type: "personal"
          },
          users: [],
          members: [],
          projects: [],
          components: [],
          content: [],
          tags: [],
          content_tags: [],
          sessions: []
        })
      )

      try do
        # Should create new account
        Data.run(["import", "--file", temp_file])

        # Verify account was created
        assert CodeMySpec.Repo.get_by(CodeMySpec.Accounts.Account, name: "New Account")
      after
        File.rm(temp_file)
      end
    end
  end

  describe "help" do
    test "shows help text when no command given" do
      import ExUnit.CaptureIO

      output =
        capture_io(fn ->
          Data.run([])
        end)

      assert output =~ "Usage: mix sync.data"
      assert output =~ "export"
      assert output =~ "import"
    end
  end
end

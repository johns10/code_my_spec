defmodule CodeMySpec.Utils.Data do
  @moduledoc """
  Data import/export utilities for syncing data between environments.
  Used by both Mix tasks and release commands.
  """

  require Logger

  alias CodeMySpec.Repo
  alias CodeMySpec.Accounts.Account
  alias CodeMySpec.Projects.Project
  alias CodeMySpec.Components.Component
  alias CodeMySpec.Sessions.Session
  alias CodeMySpec.Users.User
  alias CodeMySpec.Accounts.Member

  import Ecto.Query

  def import_account(file_path, opts \\ []) do
    dry_run = Keyword.get(opts, :dry_run, false)

    Logger.info("Importing account from #{file_path}...")

    json = File.read!(file_path)
    data = Jason.decode!(json, keys: :atoms)

    if dry_run do
      Logger.info("[DRY RUN] Would import:")
      Logger.info("  - Account: #{data.account.name}")
      Logger.info("  - #{length(data.users)} users")
      Logger.info("  - #{length(data.projects)} projects")
      Logger.info("  - #{length(data.components)} components")
      Logger.info("  - #{length(data.sessions)} sessions")
    else
      Repo.transaction(fn ->
        account_id = data.account.id

        # Wipe existing data for this account
        Logger.info("Wiping existing data for account #{account_id}...")
        wipe_account_data(account_id)

        # Insert fresh data in dependency order
        Logger.info("Inserting account data...")
        insert_account(data.account)
        insert_users(data.users)
        insert_members(data.members)
        insert_projects(data.projects)
        insert_components(data.components)
        insert_sessions(data.sessions)

        # Reset sequences after manually setting IDs to prevent conflicts
        reset_sequences()

        Logger.info("✓ Imported account #{data.account.name} (ID: #{account_id})")
      end)
    end
  end

  # Reset all table sequences after manual ID insertion
  defp reset_sequences do
    tables = ~w(accounts users members projects components sessions)

    Enum.each(tables, fn table ->
      Repo.query!("""
        SELECT setval(pg_get_serial_sequence('#{table}', 'id'),
                      COALESCE((SELECT MAX(id) FROM #{table}), 1),
                      true)
      """)
    end)
  end

  def export_account(account_id, output_path) do
    Logger.info("Exporting account #{account_id}...")

    account = Repo.get!(Account, account_id) |> Repo.preload([:members, :users])

    data = %{
      account: serialize_account(account),
      users: serialize_users(account),
      members: serialize_members(account),
      projects: serialize_projects(account_id),
      components: serialize_components(account_id),
      sessions: serialize_sessions(account_id)
    }

    json = Jason.encode!(data, pretty: true)
    File.write!(output_path, json)

    Logger.info("✓ Exported account #{account_id} to #{output_path}")
    Logger.info("  - #{length(data.users)} users")
    Logger.info("  - #{length(data.projects)} projects")
    Logger.info("  - #{length(data.components)} components")
    Logger.info("  - #{length(data.sessions)} sessions")
  end

  # Serialization functions

  defp serialize_account(account) do
    Map.take(account, [:id, :name, :slug, :type])
  end

  defp serialize_users(account) do
    Enum.map(account.users, fn user ->
      Map.take(user, [:id, :email, :hashed_password, :confirmed_at, :inserted_at, :updated_at])
    end)
  end

  defp serialize_members(account) do
    Enum.map(account.members, fn member ->
      Map.take(member, [:id, :user_id, :account_id, :role, :inserted_at, :updated_at])
    end)
  end

  defp serialize_projects(account_id) do
    Project
    |> where([p], p.account_id == ^account_id)
    |> Repo.all()
    |> Enum.map(fn project ->
      Map.take(project, [
        :id,
        :name,
        :description,
        :module_name,
        :code_repo,
        :docs_repo,
        :content_repo,
        :client_api_url,
        :account_id,
        :status,
        :inserted_at,
        :updated_at
      ])
    end)
  end

  defp serialize_components(account_id) do
    Component
    |> where([c], c.account_id == ^account_id)
    |> Repo.all()
    |> Enum.map(fn component ->
      Map.take(component, [
        :id,
        :name,
        :type,
        :module_name,
        :description,
        :account_id,
        :project_id,
        :priority,
        :component_status,
        :parent_component_id,
        :inserted_at,
        :updated_at
      ])
    end)
  end

  defp serialize_sessions(account_id) do
    Session
    |> where([s], s.account_id == ^account_id)
    |> Repo.all()
    |> Enum.map(fn session ->
      Map.take(session, [
        :id,
        :type,
        :status,
        :state,
        :account_id,
        :project_id,
        :component_id,
        :user_id,
        :environment,
        :agent,
        :context_id,
        :interactions,
        :execution_mode,
        :session_id,
        :inserted_at,
        :updated_at
      ])
    end)
  end

  # Helper to parse datetime strings from JSON
  defp parse_datetime(nil), do: nil
  defp parse_datetime(%DateTime{} = dt), do: dt
  defp parse_datetime(string) when is_binary(string) do
    case DateTime.from_iso8601(string) do
      {:ok, dt, _} -> dt
      {:error, _} -> nil
    end
  end

  # Wipe all data for an account
  defp wipe_account_data(account_id) do
    # Get user IDs for this account before deleting anything
    user_ids = from(m in Member, where: m.account_id == ^account_id, select: m.user_id) |> Repo.all()

    # Delete in reverse dependency order
    from(s in Session, where: s.account_id == ^account_id) |> Repo.delete_all()
    from(c in Component, where: c.account_id == ^account_id) |> Repo.delete_all()
    from(p in Project, where: p.account_id == ^account_id) |> Repo.delete_all()
    from(m in Member, where: m.account_id == ^account_id) |> Repo.delete_all()
    from(u in User, where: u.id in ^user_ids) |> Repo.delete_all()
    from(a in Account, where: a.id == ^account_id) |> Repo.delete_all()
  end

  # Insert functions - preserve IDs to maintain consistency across environments
  # This is important because account_id=4 should be the same account in all environments
  defp insert_account(account_data) do
    %Account{id: account_data.id}
    |> Account.changeset(account_data)
    |> Repo.insert!()
  end

  defp insert_users(users_data) do
    Enum.each(users_data, fn user_data ->
      confirmed_at = parse_datetime(user_data[:confirmed_at])

      %User{id: user_data.id}
      |> User.email_changeset(user_data, validate_unique: false)
      |> Ecto.Changeset.put_change(:hashed_password, user_data.hashed_password)
      |> Ecto.Changeset.put_change(:confirmed_at, confirmed_at)
      |> Repo.insert!()
    end)
  end

  defp insert_members(members_data) do
    Enum.each(members_data, fn member_data ->
      %Member{id: member_data.id}
      |> Member.changeset(member_data)
      |> Repo.insert!()
    end)
  end

  defp insert_projects(projects_data) do
    Enum.each(projects_data, fn project_data ->
      scope = %{active_account_id: project_data.account_id}

      %Project{id: project_data.id}
      |> Project.changeset(project_data, scope)
      |> Repo.insert!()
    end)
  end

  defp insert_components(components_data) do
    Enum.each(components_data, fn component_data ->
      scope = %CodeMySpec.Users.Scope{
        user: nil,
        active_account_id: component_data.account_id,
        active_account: %{id: component_data.account_id},
        active_project_id: component_data.project_id,
        active_project: %{id: component_data.project_id}
      }

      %Component{id: component_data.id}
      |> Component.changeset(component_data, scope)
      |> Repo.insert!()
    end)
  end

  defp insert_sessions(sessions_data) do
    Enum.each(sessions_data, fn session_data ->
      scope = %CodeMySpec.Users.Scope{
        user: %{id: session_data.user_id},
        active_account_id: session_data.account_id,
        active_account: %{id: session_data.account_id},
        active_project_id: session_data.project_id,
        active_project: %{id: session_data.project_id}
      }

      %Session{id: session_data.id}
      |> Session.changeset(session_data, scope)
      |> Repo.insert!()
    end)
  end
end

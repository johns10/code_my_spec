defmodule CodeMySpecCli.Commands.Init do
  @moduledoc """
  /init command - initialize project in current directory
  """

  use CodeMySpecCli.Commands.CommandBehaviour

  # Init doesn't need scope (it creates the project config)
  def resolve_scope(_args), do: {:ok, nil}

  alias CodeMySpec.Projects
  alias CodeMySpec.Projects.Project
  alias CodeMySpec.Repo
  alias CodeMySpec.Users.Scope
  alias CodeMySpecCli.Auth.OAuthClient
  alias CodeMySpecCli.Config

  @doc """
  Init command - set up project in current directory.

  If logged in:
    - Fetches projects from server
    - Shows selection menu
    - Downloads selected project and saves to DB and config

  If not logged in:
    - Prompts for project details
    - Creates local project and saves to DB and config
  """
  def execute(_scope, _args) do
    if OAuthClient.authenticated?() do
      init_with_server()
    else
      init_local()
    end
  end

  # Initialize with server - fetch and select project
  defp init_with_server do
    Owl.IO.puts(["\n", Owl.Data.tag("Fetching projects from server...", :cyan)])

    case fetch_projects_from_server() do
      {:ok, []} ->
        Owl.IO.puts(["\n", Owl.Data.tag("No projects found on server.", :yellow)])
        Owl.IO.puts("Would you like to create a local project instead? (y/n)")

        case IO.gets("> ") |> String.trim() |> String.downcase() do
          "y" -> init_local()
          _ -> :ok
        end

      {:ok, projects} ->
        case show_project_selector(projects) do
          {:ok, selected_project} ->
            save_project(selected_project)

            # Broadcast project initialization event
            Phoenix.PubSub.broadcast(
              CodeMySpec.PubSub,
              "user:*",
              {:project_initialized, %{project_id: selected_project.id}}
            )

            Owl.IO.puts([
              "\n",
              Owl.Data.tag("✓ Project initialized: #{selected_project.name}", [:green, :bright]),
              "\n"
            ])

          {:error, :cancelled} ->
            Owl.IO.puts(["\n", Owl.Data.tag("Initialization cancelled.", :yellow), "\n"])
        end

      {:error, reason} ->
        Owl.IO.puts([
          "\n",
          Owl.Data.tag("Failed to fetch projects: #{inspect(reason)}", :red),
          "\n"
        ])

        Owl.IO.puts("Would you like to create a local project instead? (y/n)")

        case IO.gets("> ") |> String.trim() |> String.downcase() do
          "y" -> init_local()
          _ -> :ok
        end
    end

    :ok
  end

  # Initialize local project - prompt for details
  defp init_local do
    Owl.IO.puts(["\n", Owl.Data.tag("Create a new local project", [:cyan, :bright]), "\n"])

    # Prompt for project details
    name = prompt("Project name")
    module_name = prompt("Module name (e.g., MyApp)")
    description = prompt("Description (optional)", required: false)
    code_repo = prompt("Code repository URL (optional)", required: false)

    # Generate project ID
    project_id = Ecto.UUID.generate()

    # Create project struct
    project = %Project{
      id: project_id,
      name: name,
      module_name: module_name,
      description: description,
      code_repo: code_repo,
      status: :ready
    }

    save_project(project)

    # Broadcast project initialization event
    Phoenix.PubSub.broadcast(
      CodeMySpec.PubSub,
      "user:*",
      {:project_initialized, %{project_id: project.id}}
    )

    Owl.IO.puts([
      "\n",
      Owl.Data.tag("✓ Project initialized: #{name}", [:green, :bright]),
      "\n"
    ])

    :ok
  end

  defp fetch_projects_from_server do
    case OAuthClient.get_token() do
      {:ok, token} ->
        server_url = Application.get_env(:code_my_spec, :oauth_base_url, "http://localhost:4000")
        url = "#{server_url}/api/projects"

        headers = [{"authorization", "Bearer #{token}"}]

        case Req.get(url, headers: headers) do
          {:ok, %{status: 200, body: %{"projects" => projects}}} ->
            # Convert to Project structs
            project_structs =
              Enum.map(projects, fn p ->
                %Project{
                  id: p["id"],
                  name: p["name"],
                  description: p["description"],
                  module_name: p["module_name"],
                  code_repo: p["code_repo"],
                  docs_repo: p["docs_repo"],
                  client_api_url: p["client_api_url"],
                  status: String.to_existing_atom(p["status"] || "ready")
                }
              end)

            {:ok, project_structs}

          {:ok, %{status: status}} ->
            {:error, "HTTP #{status}"}

          {:error, reason} ->
            {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp show_project_selector(projects) do
    # Create label-to-project mapping
    options = Enum.map(projects, fn project -> {project.name, project} end)

    # Extract just the labels for Owl.IO.select
    labels = Enum.map(options, fn {label, _project} -> label end)

    # Get the selected label
    case Owl.IO.select(labels, label: "Select a project:") do
      nil ->
        {:error, :cancelled}

      selected_label ->
        # Find the project that matches the selected label
        {_label, project} =
          Enum.find(options, fn {label, _project} -> label == selected_label end)

        {:ok, project}
    end
  end

  defp save_project(project) do
    # Build scope for initialization (without project, since we're creating it)
    user = get_cli_user()

    scope = %Scope{
      user: user,
      active_account: nil,
      active_account_id: nil,
      active_project: nil,
      active_project_id: nil
    }

    project_attrs = %{
      "id" => project.id,
      "name" => project.name,
      "description" => project.description,
      "module_name" => project.module_name,
      "code_repo" => project.code_repo,
      "docs_repo" => project.docs_repo,
      "client_api_url" => project.client_api_url,
      "status" => project.status
    }

    with {:ok, saved_project} <- Projects.create_project(scope, project_attrs),
         :ok <-
           Config.write_config(%{
             "project_id" => saved_project.id,
             "name" => saved_project.name,
             "description" => saved_project.description,
             "module_name" => saved_project.module_name,
             "code_repo" => saved_project.code_repo,
             "docs_repo" => saved_project.docs_repo,
             "client_api_url" => saved_project.client_api_url
           }) do
      :ok
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        raise "Failed to save project: #{inspect(changeset.errors)}"

      {:error, reason} ->
        raise "Failed to save project: #{inspect(reason)}"
    end
  end

  defp get_cli_user do
    case Config.get_current_user_email() do
      {:ok, email} ->
        Repo.get_by(CodeMySpec.ClientUsers.ClientUser, email: email) || default_cli_user()

      {:error, _} ->
        default_cli_user()
    end
  end

  defp default_cli_user do
    %CodeMySpec.ClientUsers.ClientUser{
      id: 0,
      email: "cli@localhost",
      oauth_token: nil,
      oauth_refresh_token: nil,
      oauth_expires_at: nil
    }
  end

  defp prompt(label, opts \\ []) do
    required = Keyword.get(opts, :required, true)

    Owl.IO.puts(Owl.Data.tag("#{label}:", :cyan))
    value = IO.gets("> ") |> String.trim()

    if required && value == "" do
      Owl.IO.puts(Owl.Data.tag("This field is required.", :red))
      prompt(label, opts)
    else
      if value == "", do: nil, else: value
    end
  end
end

defmodule CodeMySpecCli.Screens.Init do
  @moduledoc """
  Init screen for project initialization.

  This screen handles:
  - Fetching projects from server (if authenticated)
  - Displaying project selection list
  - Creating local projects (if not authenticated or no server projects)
  """

  import Ratatouille.View
  import Ratatouille.Constants, only: [key: 1]

  alias Ratatouille.Runtime.Command
  alias CodeMySpec.Projects
  alias CodeMySpec.Projects.Project
  alias CodeMySpec.Repo
  alias CodeMySpec.Users.Scope
  alias CodeMySpecCli.Auth.OAuthClient
  alias CodeMySpecCli.Config

  # States: :loading, :select_project, :create_local, :form_input, :success, :error
  defstruct [
    :state,
    :projects,
    :selected_index,
    :error_message,
    :form_data,
    :form_field,
    :success_message
  ]

  @doc """
  Initialize the init screen state.
  Returns {state, command} tuple for async operations.
  """
  def init do
    # Check if authenticated and start appropriate flow
    if OAuthClient.authenticated?() do
      state = %__MODULE__{
        state: :loading,
        projects: [],
        selected_index: 0,
        error_message: nil,
        form_data: %{name: "", module_name: "", description: "", code_repo: ""},
        form_field: :name,
        success_message: nil
      }

      # Start async fetch using Command
      command = Command.new(fn -> fetch_projects_from_server() end, :projects_fetched)
      {state, command}
    else
      # Go straight to local creation
      state = %__MODULE__{
        state: :create_local,
        projects: [],
        selected_index: 0,
        error_message: nil,
        form_data: %{name: "", module_name: "", description: "", code_repo: ""},
        form_field: :name,
        success_message: nil
      }

      {state, nil}
    end
  end

  @doc """
  Update the init screen state based on messages.
  Returns {:ok, new_state} or {:switch_screen, screen_name, new_state}.
  """
  def update(model, msg) do
    result =
      case {model.state, msg} do
        # Handle project fetch results from Command
        {:loading, {:projects_fetched, {:ok, []}}} ->
          {:ok, %{model | state: :create_local}}

        {:loading, {:projects_fetched, {:ok, projects}}} ->
          {:ok, %{model | state: :select_project, projects: projects}}

        {:loading, {:projects_fetched, {:error, reason}}} ->
          {:ok,
           %{model | state: :error, error_message: "Failed to fetch projects: #{inspect(reason)}"}}

        # Project selection navigation
        {:select_project, {:event, %{key: k}}} ->
          cond do
            k == key(:arrow_up) ->
              new_index = max(0, model.selected_index - 1)
              {:ok, %{model | selected_index: new_index}}

            k == key(:arrow_down) ->
              new_index = min(length(model.projects) - 1, model.selected_index + 1)
              {:ok, %{model | selected_index: new_index}}

            k == key(:enter) ->
              selected_project = Enum.at(model.projects, model.selected_index)
              save_project(selected_project)
              broadcast_project_init(selected_project.id)

              {:ok,
               %{
                 model
                 | state: :success,
                   success_message: "✓ Project initialized: #{selected_project.name}"
               }}

            k == key(:esc) ->
              {:switch_screen, :repl, model}

            true ->
              {:ok, model}
          end

        {:select_project, {:event, %{ch: ?c}}} ->
          # 'c' to create local instead
          {:ok, %{model | state: :create_local}}

        # Form input for local project creation
        {:create_local, {:event, %{key: k}}} ->
          cond do
            k == key(:enter) ->
              # Move to next field or submit
              next_field = next_form_field(model.form_field)

              if next_field == :submit do
                case create_local_project(model.form_data) do
                  {:ok, project} ->
                    broadcast_project_init(project.id)

                    {:ok,
                     %{
                       model
                       | state: :success,
                         success_message: "✓ Project initialized: #{project.name}"
                     }}

                  {:error, reason} ->
                    {:ok,
                     %{
                       model
                       | state: :error,
                         error_message: "Failed to create project: #{reason}"
                     }}
                end
              else
                {:ok, %{model | form_field: next_field}}
              end

            k == key(:tab) ->
              # Tab to next field
              {:ok, %{model | form_field: next_form_field(model.form_field)}}

            k == key(:backspace) or k == key(:backspace2) ->
              # Backspace in current field
              field = model.form_field
              current_value = Map.get(model.form_data, field, "")
              new_value = String.slice(current_value, 0..-2//1)
              {:ok, %{model | form_data: Map.put(model.form_data, field, new_value)}}

            k == key(:esc) ->
              # Return to REPL
              {:switch_screen, :repl, model}

            true ->
              {:ok, model}
          end

        {:create_local, {:event, %{ch: ch}}} when ch > 0 ->
          # Regular character input
          field = model.form_field
          current_value = Map.get(model.form_data, field, "")
          new_value = current_value <> <<ch::utf8>>
          {:ok, %{model | form_data: Map.put(model.form_data, field, new_value)}}

        # Error/Success screens - press Enter to return to REPL
        {:error, {:event, %{key: k}}} ->
          if k == key(:enter) do
            {:switch_screen, :repl, model}
          else
            {:ok, model}
          end

        {:success, {:event, %{key: k}}} ->
          if k == key(:enter) do
            {:switch_screen, :repl, model}
          else
            {:ok, model}
          end

        # Escape always returns to REPL
        {_, {:event, %{key: k}}} ->
          if k == key(:esc) do
            {:switch_screen, :repl, model}
          else
            {:ok, model}
          end

        _ ->
          {:ok, model}
      end

    result
  end

  @doc """
  Render the init screen.
  """
  def render(model) do
    case model.state do
      :loading -> render_loading()
      :select_project -> render_project_selector(model)
      :create_local -> render_local_form(model)
      :success -> render_success(model)
      :error -> render_error(model)
    end
  end

  # Rendering functions

  defp render_loading do
    row do
      column(size: 12) do
        panel do
          label(content: "Fetching projects from server...")
          label(content: "")
          label(content: "Please wait...")
        end
      end
    end
  end

  defp render_project_selector(model) do
    row do
      column(size: 12) do
        panel(title: "Select a Project") do
          label(
            content: "Use ↑/↓ to navigate, Enter to select, 'c' to create local project instead"
          )

          label(content: "")

          for {project, index} <- Enum.with_index(model.projects) do
            prefix = if index == model.selected_index, do: "▶ ", else: "  "

            label do
              text(
                content: prefix,
                attributes: if(index == model.selected_index, do: [:bold], else: [])
              )

              text(
                content: project.name,
                attributes: if(index == model.selected_index, do: [:bold], else: [])
              )

              if project.description do
                text(content: " - #{project.description}", color: :cyan)
              end
            end
          end
        end
      end
    end
  end

  defp render_local_form(model) do
    row do
      column(size: 12) do
        panel(title: "Create New Local Project") do
          label(
            content:
              "Fill in the project details. Press Enter to move to next field, Tab to navigate."
          )

          label(content: "Press Esc to cancel.")
          label(content: "")

          render_form_field("Project name (required)", :name, model)
          render_form_field("Module name (required)", :module_name, model)
          render_form_field("Description (optional)", :description, model)
          render_form_field("Code repository URL (optional)", :code_repo, model)

          label(content: "")

          if all_required_fields_filled?(model.form_data) do
            label(content: "Press Enter to create project", color: :green)
          else
            label(content: "Fill in required fields to continue", color: :yellow)
          end
        end
      end
    end
  end

  defp render_form_field(label_text, field, model) do
    is_active = model.form_field == field
    value = Map.get(model.form_data, field, "")
    cursor = if is_active, do: "_", else: ""

    label do
      text(
        content: "#{label_text}: ",
        color: if(is_active, do: :cyan, else: :white),
        attributes: if(is_active, do: [:bold], else: [])
      )

      text(content: value)
      text(content: cursor, attributes: [:bold])
    end
  end

  defp render_success(model) do
    row do
      column(size: 12) do
        panel do
          label(content: model.success_message, color: :green, attributes: [:bold])
          label(content: "")
          label(content: "Press Enter to continue...")
        end
      end
    end
  end

  defp render_error(model) do
    row do
      column(size: 12) do
        panel do
          label(content: "Error:", color: :red, attributes: [:bold])
          label(content: model.error_message, color: :red)
          label(content: "")
          label(content: "Press Enter to continue...")
        end
      end
    end
  end

  # Helper functions

  defp fetch_projects_from_server do
    case OAuthClient.get_token() do
      {:ok, token} ->
        server_url = Application.get_env(:code_my_spec, :oauth_base_url, "http://localhost:4000")
        url = "#{server_url}/api/projects"
        headers = [{"authorization", "Bearer #{token}"}]

        case Req.get(url, headers: headers) do
          {:ok, %{status: 200, body: %{"projects" => projects}}} ->
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

  defp save_project(project) do
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

  defp create_local_project(form_data) do
    if not all_required_fields_filled?(form_data) do
      {:error, "Required fields are missing"}
    else
      project_id = Ecto.UUID.generate()

      project = %Project{
        id: project_id,
        name: form_data.name,
        module_name: form_data.module_name,
        description: if(form_data.description == "", do: nil, else: form_data.description),
        code_repo: if(form_data.code_repo == "", do: nil, else: form_data.code_repo),
        status: :ready
      }

      save_project(project)
      {:ok, project}
    end
  end

  defp broadcast_project_init(project_id) do
    Phoenix.PubSub.broadcast(
      CodeMySpec.PubSub,
      "user:*",
      {:project_initialized, %{project_id: project_id}}
    )
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

  defp next_form_field(:name), do: :module_name
  defp next_form_field(:module_name), do: :description
  defp next_form_field(:description), do: :code_repo
  defp next_form_field(:code_repo), do: :submit

  defp all_required_fields_filled?(form_data) do
    form_data.name != "" and form_data.module_name != ""
  end
end

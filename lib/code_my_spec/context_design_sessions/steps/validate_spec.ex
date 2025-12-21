defmodule CodeMySpec.ContextSpecSessions.Steps.ValidateSpec do
  @behaviour CodeMySpec.Sessions.StepBehaviour
  require Logger

  alias CodeMySpec.Documents
  alias CodeMySpec.Environments
  alias CodeMySpec.Sessions.Command
  alias CodeMySpec.Sessions
  alias CodeMySpec.Utils

  def get_command(_scope, %{component: component, project: project}, _opts \\ []) do
    %{spec_file: spec_file} = Utils.component_files(component, project)
    {:ok, Command.new(__MODULE__, "read_file", metadata: %{path: spec_file})}
  end

  def handle_result(scope, session, result, _opts \\ []) do
    with {:ok, component_design} <- get_component_design(result),
         {:ok, document} <-
           Documents.create_dynamic_document(component_design, :context_spec),
         {:ok, _created} <- create_spec_files(scope, session, document.sections) do
      {:ok, %{}, result}
    else
      {:error, error} ->
        updated_result = update_result_with_error(scope, result, error)
        {:ok, %{}, updated_result}
    end
  end

  defp get_component_design(%{data: %{content: content}}) when is_binary(content) do
    if String.trim(content) == "" do
      {:error, "component design is empty"}
    else
      {:ok, content}
    end
  end

  defp get_component_design(_result) do
    {:error, "component_design not found in result"}
  end

  defp create_spec_files(_scope, session, %{"components" => components})
       when is_list(components) do
    {:ok, environment} = Environments.create(session.environment)

    # Create spec files for each component
    results =
      Enum.map(components, fn %{module_name: module_name, description: description} ->
        %{spec_file: file_path} = Utils.component_files(module_name)
        content = build_spec_content(module_name, description)

        case Environments.write_file(environment, file_path, content) do
          :ok ->
            Logger.info("Created spec file: #{file_path}")
            {:ok, file_path}

          {:error, reason} ->
            Logger.error("Failed to create spec file #{file_path}: #{inspect(reason)}")
            {:error, reason}
        end
      end)

    # Check if all files were created successfully
    case Enum.find(results, fn result -> match?({:error, _}, result) end) do
      nil -> {:ok, Enum.map(results, fn {:ok, path} -> path end)}
      {:error, reason} -> {:error, "Failed to create one or more spec files: #{inspect(reason)}"}
    end
  end

  defp create_spec_files(_scope, _session, _sections) do
    {:error, "components section missing or invalid"}
  end

  defp extract_component_name(module_name) do
    module_name
    |> String.split(".")
    |> List.last()
    |> Macro.underscore()
  end

  defp build_spec_content(module_name, description) do
    """
    # #{module_name}

    #{description}
    """
  end

  defp update_result_with_error(scope, result, error) do
    error_message = format_error(error)
    attrs = %{status: :error, error_message: error_message}

    case Sessions.update_result(scope, result, attrs) do
      {:ok, updated_result} ->
        updated_result

      {:error, changeset} ->
        Logger.error("#{__MODULE__} failed to update result", changeset: changeset)
        result
    end
  end

  defp format_error(%Ecto.Changeset{} = changeset) do
    Utils.changeset_error_to_string(changeset)
  end

  defp format_error(error) when is_binary(error), do: error
end

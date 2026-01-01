defmodule CodeMySpec.ContextSpecSessions.Steps.ValidateSpec do
  @behaviour CodeMySpec.Sessions.StepBehaviour
  require Logger

  alias CodeMySpec.{Documents, Environments, Utils}
  alias CodeMySpec.Sessions.Command

  def get_command(_scope, %{component: component, project: project}, _opts \\ []) do
    %{spec_file: spec_file} = Utils.component_files(component, project)
    {:ok, Command.new(__MODULE__, "read_file", metadata: %{path: spec_file})}
  end

  def handle_result(_scope, session, result, _opts \\ []) do
    with {:ok, component_design} <- get_component_design(result),
         {:ok, document} <- validate_document(component_design),
         {:ok, _created} <- create_spec_files(session, document.sections) do
      {:ok, %{}, Map.put(result, :status, :ok)}
    else
      {:error, error} ->
        error_message = format_error(error)
        updated_result = result
          |> Map.put(:status, :error)
          |> Map.put(:error_message, error_message)
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

  defp validate_document(component_design) do
    Documents.create_dynamic_document(component_design, :context_spec)
  end

  defp create_spec_files(session, %{"components" => components})
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

  defp create_spec_files(_session, _sections) do
    {:error, "components section missing or invalid"}
  end

  defp build_spec_content(module_name, description) do
    """
    # #{module_name}

    #{description}
    """
  end

  defp format_error(%Ecto.Changeset{} = changeset) do
    Utils.changeset_error_to_string(changeset)
  end

  defp format_error(error) when is_binary(error), do: error
end

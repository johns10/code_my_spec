defmodule CodeMySpec.ComponentSpecSessions.Steps.ReviseSpec do
  @behaviour CodeMySpec.Sessions.StepBehaviour

  alias CodeMySpec.Sessions.Steps.Helpers
  alias CodeMySpec.{Documents, Environments, Utils}

  @impl true
  def get_command(_scope, session, opts \\ []) do
    with {:ok, spec_content} <- read_current_spec(session),
         {:ok, validation_errors} <- validate_and_get_errors(spec_content, session.component),
         prompt <- build_revision_prompt(validation_errors),
         {:ok, command} <-
           Helpers.build_agent_command(
             __MODULE__,
             session,
             :component_designer,
             "component-design-reviser",
             prompt,
             opts
           ) do
      {:ok, command}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def handle_result(_scope, session, result, _opts \\ []) do
    revised_design = result.stdout
    updated_state = Map.put(session.state || %{}, "component_design", revised_design)
    {:ok, %{state: updated_state}, result}
  end

  defp read_current_spec(session) do
    %{spec_file: path} = Utils.component_files(session.component, session.project)

    {:ok, environment} =
      Environments.create(session.environment_type, working_dir: session[:working_dir])

    case Environments.read_file(environment, path) do
      {:ok, content} -> {:ok, content}
      {:error, error} -> {:error, "Failed to read file #{path} due to #{error}"}
    end
  end

  defp validate_and_get_errors(spec_content, component) do
    case Documents.create_dynamic_document(spec_content, component.type) do
      {:ok, _} -> {:error, "spec is valid - no revision needed"}
      {:error, error} -> {:ok, error}
    end
  end

  defp build_revision_prompt(validation_errors) do
    """
    The component design failed validation:

    Validation errors:
    #{validation_errors}

    Please revise the component design to address these validation errors while maintaining the overall structure and intent of the design.
    """
  end
end

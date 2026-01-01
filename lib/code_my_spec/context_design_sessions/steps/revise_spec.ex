defmodule CodeMySpec.ContextSpecSessions.Steps.ReviseSpec do
  @behaviour CodeMySpec.Sessions.StepBehaviour

  alias CodeMySpec.Sessions.Steps.Helpers
  alias CodeMySpec.{Documents, Environments, Utils}

  @impl true
  def get_command(_scope, session, opts \\ []) do
    with {:ok, spec_content} <- read_current_spec(session, opts),
         {:ok, validation_errors} <- validate_and_get_errors(spec_content),
         prompt <- build_revision_prompt(validation_errors),
         {:ok, command} <-
           Helpers.build_agent_command(
             __MODULE__,
             session,
             :context_designer,
             "context-design-reviser",
             prompt,
             opts
           ) do
      {:ok, command}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def handle_result(_scope, _session, result, _opts \\ []) do
    {:ok, %{}, result}
  end

  defp read_current_spec(session, opts) do
    %{spec_file: path} = Utils.component_files(session.component, session.project)
    {:ok, environment} = Environments.create(session.environment, opts)

    Environments.read_file(environment, path)
  end

  defp validate_and_get_errors(spec_content) do
    case Documents.create_dynamic_document(spec_content, :context_spec) do
      {:ok, _} -> {:error, "spec is valid - no revision needed"}
      {:error, error} -> {:ok, error}
    end
  end

  defp build_revision_prompt(validation_errors) do
    """
    The context design failed validation:

    Validation errors:
    #{validation_errors}

    Please revise the context design to address these validation errors while maintaining the overall structure and intent of the design.
    """
  end
end

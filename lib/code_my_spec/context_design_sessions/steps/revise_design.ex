defmodule CodeMySpec.ContextDesignSessions.Steps.ReviseDesign do
  @behaviour CodeMySpec.Sessions.StepBehaviour

  alias CodeMySpec.Sessions.Steps.Helpers

  @impl true
  def get_command(scope, session, opts \\ []) do
    with {:ok, context_design} <- get_context_design_from_state(session.state),
         {:ok, validation_errors} <-
           get_validation_errors_from_previous_interaction(scope, session),
         prompt <- build_revision_prompt(context_design, validation_errors),
         opts_with_continue <- Keyword.put(opts, :continue, true),
         {:ok, command} <-
           Helpers.build_agent_command(
             __MODULE__,
             :context_designer,
             "context-design-reviser",
             prompt,
             opts_with_continue
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

  defp get_context_design_from_state(%{"component_design" => context_design})
       when is_binary(context_design) do
    if String.trim(context_design) == "" do
      {:error, "context design is empty"}
    else
      {:ok, context_design}
    end
  end

  defp get_context_design_from_state(_state) do
    {:error, "component_design not found in session state"}
  end

  defp get_validation_errors_from_previous_interaction(_scope, session) do
    # Get the most recent interaction that has an error result
    case Enum.find(session.interactions, fn
           %{result: %{status: :error}} -> true
           _ -> false
         end) do
      %{result: %{error_message: errors}} when is_binary(errors) ->
        {:ok, errors}

      nil ->
        {:error, "no validation errors found in previous interactions"}

      _ ->
        {:error, "validation errors not accessible"}
    end
  end

  defp build_revision_prompt(_context_design, validation_errors) do
    """
    The context design failed validation:

    Validation errors:
    #{validation_errors}

    Please revise the context design to address these validation errors while maintaining the overall structure and intent of the design.
    """
  end
end

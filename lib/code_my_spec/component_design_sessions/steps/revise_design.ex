defmodule CodeMySpec.ComponentDesignSessions.Steps.ReviseDesign do
  @behaviour CodeMySpec.Sessions.StepBehaviour

  alias CodeMySpec.{Agents, Sessions}
  alias CodeMySpec.Sessions.Command

  def get_command(scope, session) do
    with {:ok, component_design} <- get_component_design_from_state(session.state),
         {:ok, validation_errors} <-
           get_validation_errors_from_previous_interaction(scope, session),
         {:ok, agent} <-
           Agents.create_agent(:component_designer, "component-design-reviser", :claude_code),
         prompt <- build_revision_prompt(component_design, validation_errors),
         {:ok, command_args} <- Agents.build_command(agent, prompt, %{"continue" => true}) do
      [prompt | command] = Enum.reverse(command_args)

      {:ok, Command.new(__MODULE__, command |> Enum.reverse() |> Enum.join(" "), prompt)}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def handle_result(scope, session, interaction) do
    revised_design = interaction.result.stdout
    updated_state = Map.put(session.state || %{}, :component_design, revised_design)
    Sessions.update_session(scope, session, %{state: updated_state})
  end

  defp get_component_design_from_state(%{"component_design" => component_design})
       when is_binary(component_design) do
    if String.trim(component_design) == "" do
      {:error, "component design is empty"}
    else
      {:ok, component_design}
    end
  end

  defp get_component_design_from_state(_state) do
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

  defp build_revision_prompt(_component_design, validation_errors) do
    """
    The component design failed validation:

    Validation errors:
    #{validation_errors}

    Please revise the component design to address these validation errors while maintaining the overall structure and intent of the design.
    """
  end
end

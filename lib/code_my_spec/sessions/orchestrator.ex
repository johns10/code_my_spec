defmodule CodeMySpec.Sessions.Orchestrator do
  alias CodeMySpec.Sessions.{Session, SessionsRepository, Interaction}

  def next_command(scope, session_id, opts \\ []) do
    with {:ok, %Session{type: session_module} = session} <- get_session(scope, session_id),
         :ok <- validate_session_status(session),
         {nil, session} <- get_pending_interaction(session),
         {:ok, next_interaction_module} <- session_module.get_next_interaction(session),
         {:ok, command} <-
           next_interaction_module.get_command(scope, session, opts),
         interaction <- Interaction.new_with_command(command),
         {:ok, updated_session} <- SessionsRepository.add_interaction(scope, session, interaction) do
      {:ok, interaction, updated_session}
    else
      {%Interaction{} = pending_interaction, session} ->
        {:ok, pending_interaction, session}

      error ->
        error
    end
  end

  def get_session(scope, session_id) do
    case SessionsRepository.get_session(scope, session_id) do
      nil -> {:error, :session_not_found}
      %Session{} = session -> {:ok, session}
    end
  end

  defp validate_session_status(%Session{status: :complete}), do: {:error, :complete}
  defp validate_session_status(%Session{status: :failed}), do: {:error, :failed}
  defp validate_session_status(%Session{}), do: :ok

  defp get_pending_interaction(%Session{interactions: interactions} = session) do
    case List.last(interactions) do
      %Interaction{result: nil} = pending_interaction ->
        {pending_interaction, session}

      _ ->
        {nil, session}
    end
  end
end

defmodule CodeMySpec.Sessions.Orchestrator do
  alias CodeMySpec.Sessions.{Session, SessionsRepository, Interaction, InteractionsRepository}

  def next_command(scope, session_id, opts \\ []) do
    with {:ok, %Session{type: session_module} = session} <- get_session(scope, session_id),
         :ok <- validate_session_status(session),
         {nil, session} <- get_pending_interaction(session),
         {:ok, next_interaction_module} <- session_module.get_next_interaction(session),
         {:ok, command} <-
           next_interaction_module.get_command(scope, session, opts),
         interaction <- Interaction.new_with_command(command),
         {:ok, _created_interaction} <- InteractionsRepository.create(session.id, interaction),
         refreshed_session <- SessionsRepository.get_session(scope, session.id) do
      {:ok, refreshed_session}
    else
      {%Interaction{} = _pending_interaction, session} ->
        {:ok, session}

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

  defp get_pending_interaction(%Session{interactions: []} = session) do
    {nil, session}
  end

  defp get_pending_interaction(%Session{interactions: [latest | _]} = session) do
    case latest do
      %Interaction{result: nil} = pending_interaction ->
        {pending_interaction, session}

      _ ->
        {nil, session}
    end
  end
end

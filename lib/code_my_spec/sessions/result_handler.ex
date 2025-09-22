defmodule CodeMySpec.Sessions.ResultHandler do
  alias CodeMySpec.Sessions.{Session, SessionsRepository, Interaction}

  def handle_result(scope, session_id, interaction_id, result) do
    with {:ok, session} <- get_session(scope, session_id),
         {:ok, interaction} <- find_interaction(session, interaction_id),
         {:ok, updated_session} <-
           SessionsRepository.complete_interaction(scope, session, interaction_id, result),
         {:ok, updated_interaction} <- find_interaction(updated_session, interaction_id),
         {:ok, final_session} <-
           interaction.command.module.handle_result(scope, session, updated_interaction) do
      {:ok, final_session}
    end
  end

  def get_session(scope, session_id) do
    case SessionsRepository.get_session(scope, session_id) do
      nil -> {:error, :session_not_found}
      %Session{} = session -> {:ok, session}
    end
  end

  def find_interaction(%Session{interactions: interactions}, interaction_id) do
    case Enum.find(interactions, &(&1.id == interaction_id)) do
      nil -> {:error, :interaction_not_found}
      %Interaction{} = interaction -> {:ok, interaction}
    end
  end
end

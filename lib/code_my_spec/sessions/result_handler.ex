defmodule CodeMySpec.Sessions.ResultHandler do
  alias CodeMySpec.Sessions
  alias CodeMySpec.Sessions.{Session, SessionsRepository, Interaction}

  def handle_result(scope, session_id, interaction_id, result_attrs) do
    with {:ok, session} <- get_session(scope, session_id),
         {:ok, result} <- Sessions.create_result(scope, result_attrs),
         {:ok, interaction} <- find_interaction(session, interaction_id),
         {:ok, updated_interaction} <-
           Sessions.add_result_to_interaction(scope, interaction, result),
         {:ok, session_attrs, final_interaction} <-
           interaction.command.module.handle_result(scope, session, updated_interaction),
         {:ok, final_session} <-
           Sessions.complete_session_interaction(
             scope,
             session,
             session_attrs,
             interaction_id,
             final_interaction.result
           ) do
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

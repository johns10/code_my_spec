defmodule CodeMySpec.Sessions.Orchestrator do
  alias CodeMySpec.Sessions.{Session, SessionsRepository, Interaction, Command}

  def next_command(scope, session_id) do
    with {:ok, %Session{type: session_module} = session} <- get_session(scope, session_id),
         last_interaction <- find_last_completed_interaction(scope, session),
         {:ok, next_interaction_module} <- session_module.get_next_interaction(last_interaction),
         {:ok, command} <- next_interaction_module.get_command(scope, session),
         interaction <- Interaction.new_with_command(command),
         {:ok, updated_session} <- SessionsRepository.add_interaction(scope, session, interaction) do
      {:ok, interaction, updated_session}
    end
    |> IO.inspect()
  end

  def get_session(scope, session_id) do
    case SessionsRepository.get_session(scope, session_id) do
      nil -> {:error, :session_not_found}
      %Session{} = session -> {:ok, session}
    end
  end

  def find_last_completed_interaction(_scope, %Session{status: :complete}),
    do: {:error, :complete}

  def find_last_completed_interaction(_scope, %Session{status: :failed}), do: {:error, :failed}

  def find_last_completed_interaction(_scope, %Session{interactions: interactions}) do
    interactions
    |> Enum.filter(&Interaction.completed?/1)
    |> Enum.sort_by(& &1.command.timestamp, {:desc, DateTime})
    |> List.first()
  end
end

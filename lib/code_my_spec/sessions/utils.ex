defmodule CodeMySpec.Sessions.Utils do
  @moduledoc """
  Utility functions for working with sessions and interactions.
  """

  alias CodeMySpec.Sessions.{Session, Interaction}

  @doc """
  Finds the last completed interaction in a session.

  Returns nil if:
  - Session has no interactions
  - Session has no completed interactions
  - Session status is :complete or :failed
  """
  @spec find_last_completed_interaction(Session.t()) :: Interaction.t() | nil
  def find_last_completed_interaction(%Session{status: :complete}), do: nil
  def find_last_completed_interaction(%Session{status: :failed}), do: nil

  def find_last_completed_interaction(%Session{interactions: interactions}) do
    interactions
    |> Enum.filter(&Interaction.completed?/1)
    |> Enum.sort_by(& &1.command.timestamp, {:desc, DateTime})
    |> List.first()
  end
end

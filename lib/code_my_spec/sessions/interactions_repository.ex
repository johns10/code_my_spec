defmodule CodeMySpec.Sessions.InteractionsRepository do
  @moduledoc """
  Repository for managing Interaction records.
  """

  import Ecto.Query, warn: false
  alias CodeMySpec.Repo
  alias CodeMySpec.Sessions.Interaction
  alias CodeMySpec.Sessions.Result

  @doc """
  Creates a new interaction for a session.
  """
  def create(session_id, %Interaction{} = interaction) do
    interaction
    |> Interaction.changeset(%{session_id: session_id})
    |> Repo.insert()
  end

  @doc """
  Gets an interaction by ID.
  """
  def get(interaction_id) do
    Repo.get(Interaction, interaction_id)
  end

  @doc """
  Gets an interaction by ID, raises if not found.
  """
  def get!(interaction_id) do
    Repo.get!(Interaction, interaction_id)
  end

  @doc """
  Updates an interaction with a result.
  """
  def complete(%Interaction{} = interaction, %Result{} = result) do
    result_attrs = Map.from_struct(result)

    interaction
    |> Interaction.changeset(%{result: result_attrs})
    |> Repo.update()
  end

  @doc """
  Deletes an interaction.
  """
  def delete(%Interaction{} = interaction) do
    Repo.delete(interaction)
  end

  @doc """
  Lists all interactions for a session, ordered by most recent first.
  """
  def list_for_session(session_id) do
    Interaction
    |> where([i], i.session_id == ^session_id)
    |> order_by([i], desc: i.inserted_at)
    |> Repo.all()
  end
end
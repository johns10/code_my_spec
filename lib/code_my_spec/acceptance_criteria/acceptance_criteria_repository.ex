defmodule CodeMySpec.AcceptanceCriteria.AcceptanceCriteriaRepository do
  @moduledoc """
  Repository for acceptance criteria CRUD operations with direct database access.
  Provides query composables for filtering by story and verification status filtering.
  """

  import Ecto.Query, warn: false

  alias CodeMySpec.AcceptanceCriteria.Criterion
  alias CodeMySpec.Repo
  alias CodeMySpec.Users.Scope

  @doc """
  Returns all acceptance criteria for a given story.
  """
  @spec list_story_criteria(Scope.t(), integer()) :: [Criterion.t()]
  def list_story_criteria(%Scope{} = scope, story_id) do
    from(c in Criterion,
      where: c.story_id == ^story_id and c.project_id == ^scope.active_project.id,
      order_by: [asc: c.inserted_at]
    )
    |> Repo.all()
  end

  @doc """
  Gets a single acceptance criterion by ID within scope. Raises if not found.
  """
  @spec get_criterion!(Scope.t(), integer()) :: Criterion.t()
  def get_criterion!(%Scope{} = scope, id) do
    Repo.get_by!(Criterion, id: id, project_id: scope.active_project.id)
  end

  @doc """
  Gets a single acceptance criterion by ID within scope. Returns nil if not found.
  """
  @spec get_criterion(Scope.t(), integer()) :: Criterion.t() | nil
  def get_criterion(%Scope{} = scope, id) do
    Repo.get_by(Criterion, id: id, project_id: scope.active_project.id)
  end

  @doc """
  Creates a new acceptance criterion.
  """
  @spec create_criterion(map()) :: {:ok, Criterion.t()} | {:error, Ecto.Changeset.t()}
  def create_criterion(attrs) do
    %Criterion{}
    |> Criterion.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates an existing acceptance criterion.
  """
  @spec update_criterion(Criterion.t(), map()) ::
          {:ok, Criterion.t()} | {:error, Ecto.Changeset.t()}
  def update_criterion(%Criterion{} = criterion, attrs) do
    criterion
    |> Criterion.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes an acceptance criterion.
  """
  @spec delete_criterion(Criterion.t()) :: {:ok, Criterion.t()} | {:error, Ecto.Changeset.t()}
  def delete_criterion(%Criterion{} = criterion) do
    Repo.delete(criterion)
  end
end

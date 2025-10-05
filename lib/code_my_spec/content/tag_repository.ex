defmodule CodeMySpec.Content.TagRepository do
  @moduledoc """
  Query builder module for tag upsert and lookup with account_id and project_id scoping.
  Handles tag normalization and conflict resolution on unique constraints.
  """

  import Ecto.Query, warn: false

  alias CodeMySpec.Repo
  alias CodeMySpec.Content.Tag
  alias CodeMySpec.Users.Scope

  @type scope :: Scope.t()

  @spec upsert_tag(scope(), String.t()) :: {:ok, Tag.t()} | {:error, Ecto.Changeset.t()}
  def upsert_tag(%Scope{} = scope, name) do
    attrs = %{
      name: name,
      account_id: scope.active_account_id,
      project_id: scope.active_project_id
    }

    changeset = Tag.changeset(%Tag{}, attrs)

    case changeset.valid? do
      true ->
        slug = Ecto.Changeset.get_field(changeset, :slug)

        case Repo.insert(changeset, on_conflict: :nothing) do
          {:ok, %Tag{id: nil}} ->
            {:ok, get_tag_by_slug!(scope, slug)}

          result ->
            result
        end

      false ->
        {:error, changeset}
    end
  end

  @spec list_tags(scope()) :: [Tag.t()]
  def list_tags(%Scope{} = scope) do
    from(t in Tag)
    |> by_account_and_project(scope)
    |> order_by([t], asc: t.name)
    |> Repo.all()
  end

  @spec get_tag_by_slug(scope(), String.t()) :: Tag.t() | nil
  def get_tag_by_slug(%Scope{} = scope, slug) do
    from(t in Tag)
    |> by_account_and_project(scope)
    |> by_slug(slug)
    |> Repo.one()
  end

  @spec get_tag_by_slug!(scope(), String.t()) :: Tag.t()
  def get_tag_by_slug!(%Scope{} = scope, slug) do
    from(t in Tag)
    |> by_account_and_project(scope)
    |> by_slug(slug)
    |> Repo.one!()
  end

  @spec by_account_and_project(Ecto.Query.t(), scope()) :: Ecto.Query.t()
  def by_account_and_project(query, %Scope{} = scope) do
    query
    |> where([t], t.account_id == ^scope.active_account_id)
    |> where([t], t.project_id == ^scope.active_project_id)
  end

  @spec by_slug(Ecto.Query.t(), String.t()) :: Ecto.Query.t()
  def by_slug(query, slug) do
    where(query, [t], t.slug == ^slug)
  end
end

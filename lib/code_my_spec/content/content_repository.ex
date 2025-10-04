defmodule CodeMySpec.Content.ContentRepository do
  @moduledoc """
  Query builder module providing scoped query functions for content filtering by publish_at,
  expires_at, sync_status, content_type, and protected flag. All queries enforce account_id
  and project_id scoping.
  """

  import Ecto.Query, warn: false

  alias CodeMySpec.Repo
  alias CodeMySpec.Content.Content
  alias CodeMySpec.Users.Scope

  @type scope :: Scope.t()

  @spec list_content(scope()) :: [Content.t()]
  def list_content(%Scope{} = scope) do
    Content
    |> by_account_and_project(scope)
    |> Repo.all()
  end

  @spec list_published_content(scope(), String.t()) :: [Content.t()]
  def list_published_content(%Scope{} = scope, content_type) do
    now = DateTime.utc_now()

    Content
    |> by_account_and_project(scope)
    |> by_content_type(content_type)
    |> where([c], c.parse_status == :success)
    |> where([c], c.publish_at <= ^now)
    |> where([c], is_nil(c.expires_at) or c.expires_at > ^now)
    |> Repo.all()
  end

  @spec list_scheduled_content(scope()) :: [Content.t()]
  def list_scheduled_content(%Scope{} = scope) do
    now = DateTime.utc_now()

    Content
    |> by_account_and_project(scope)
    |> where([c], c.publish_at > ^now)
    |> Repo.all()
  end

  @spec list_expired_content(scope()) :: [Content.t()]
  def list_expired_content(%Scope{} = scope) do
    now = DateTime.utc_now()

    Content
    |> by_account_and_project(scope)
    |> where([c], not is_nil(c.expires_at) and c.expires_at <= ^now)
    |> Repo.all()
  end

  @spec list_content_by_type(scope(), String.t()) :: [Content.t()]
  def list_content_by_type(%Scope{} = scope, content_type) do
    Content
    |> by_account_and_project(scope)
    |> by_content_type(content_type)
    |> Repo.all()
  end

  @spec list_content_by_parse_status(scope(), String.t()) :: [Content.t()]
  def list_content_by_parse_status(%Scope{} = scope, parse_status) do
    parse_status_atom = String.to_existing_atom(parse_status)

    Content
    |> by_account_and_project(scope)
    |> where([c], c.parse_status == ^parse_status_atom)
    |> Repo.all()
  end

  @spec get_content(scope(), integer()) :: Content.t() | nil
  def get_content(%Scope{} = scope, id) do
    Content
    |> by_account_and_project(scope)
    |> where([c], c.id == ^id)
    |> Repo.one()
  end

  @spec get_content!(scope(), integer()) :: Content.t()
  def get_content!(%Scope{} = scope, id) do
    Content
    |> by_account_and_project(scope)
    |> where([c], c.id == ^id)
    |> Repo.one!()
  end

  @spec get_content_by_slug(scope(), String.t(), String.t()) :: Content.t() | nil
  def get_content_by_slug(%Scope{} = scope, slug, content_type) do
    Content
    |> by_account_and_project(scope)
    |> by_slug(slug)
    |> by_content_type(content_type)
    |> Repo.one()
  end

  @spec get_content_by_slug!(scope(), String.t(), String.t()) :: Content.t()
  def get_content_by_slug!(%Scope{} = scope, slug, content_type) do
    Content
    |> by_account_and_project(scope)
    |> by_slug(slug)
    |> by_content_type(content_type)
    |> Repo.one!()
  end

  @spec preload_tags(Content.t() | [Content.t()]) :: Content.t() | [Content.t()]
  def preload_tags(content_or_list) do
    Repo.preload(content_or_list, :tags)
  end

  defp by_account_and_project(query, %Scope{} = scope) do
    query
    |> where([c], c.account_id == ^scope.active_account_id)
    |> where([c], c.project_id == ^scope.active_project_id)
  end

  defp by_content_type(query, content_type) do
    content_type_atom = String.to_existing_atom(content_type)
    where(query, [c], c.content_type == ^content_type_atom)
  end

  defp by_slug(query, slug) do
    where(query, [c], c.slug == ^slug)
  end
end
defmodule CodeMySpec.Content.ContentRepository do
  @moduledoc """
  Provides data access functions for Content entities (published content). Handles content
  retrieval with optional scope filtering - passing a Scope allows access to protected content
  for authenticated users, while nil scope only returns public content. NO multi-tenant filtering
  by account_id/project_id.

  Note: This repository is for published content access. ContentAdminRepository handles
  validation/preview with multi-tenant scoping.
  """

  import Ecto.Query, warn: false

  alias CodeMySpec.Repo
  alias CodeMySpec.Content.Content
  alias CodeMySpec.Users.Scope

  @type scope :: Scope.t()

  @doc """
  Returns published content filtered by content_type.

  With Scope: Returns published content (publish_at <= now, expires_at > now or null)
  including both public AND protected content.

  With nil: Returns ONLY public published content (protected = false).
  """
  @spec list_published_content(scope() | nil, String.t()) :: [Content.t()]
  def list_published_content(%Scope{} = _scope, content_type) do
    now = DateTime.utc_now()

    Content
    |> by_content_type(content_type)
    |> where([c], is_nil(c.publish_at) or c.publish_at <= ^now)
    |> where([c], is_nil(c.expires_at) or c.expires_at > ^now)
    |> Repo.all()
  end

  def list_published_content(nil, content_type) do
    now = DateTime.utc_now()

    Content
    |> by_content_type(content_type)
    |> where([c], is_nil(c.publish_at) or c.publish_at <= ^now)
    |> where([c], is_nil(c.expires_at) or c.expires_at > ^now)
    |> where([c], c.protected == false)
    |> Repo.all()
  end

  @doc """
  Fetches content by slug and content_type.

  With Scope: Returns both public and protected content if published.

  With nil: Returns ONLY public content (protected = false) if published.
  """
  @spec get_content_by_slug(scope() | nil, String.t(), String.t()) :: Content.t() | nil
  def get_content_by_slug(%Scope{} = _scope, slug, content_type) do
    now = DateTime.utc_now()

    Content
    |> by_slug(slug)
    |> by_content_type(content_type)
    |> where([c], is_nil(c.publish_at) or c.publish_at <= ^now)
    |> where([c], is_nil(c.expires_at) or c.expires_at > ^now)
    |> Repo.one()
  end

  def get_content_by_slug(nil, slug, content_type) do
    now = DateTime.utc_now()

    Content
    |> by_slug(slug)
    |> by_content_type(content_type)
    |> where([c], is_nil(c.publish_at) or c.publish_at <= ^now)
    |> where([c], is_nil(c.expires_at) or c.expires_at > ^now)
    |> where([c], c.protected == false)
    |> Repo.one()
  end

  @doc """
  Bang version of get_content_by_slug.

  With Scope: Raises Ecto.NoResultsError if not found.

  With nil: Returns nil if not found (non-raising).
  """
  @spec get_content_by_slug!(scope() | nil, String.t(), String.t()) :: Content.t() | nil
  def get_content_by_slug!(%Scope{} = _scope, slug, content_type) do
    now = DateTime.utc_now()

    Content
    |> by_slug(slug)
    |> by_content_type(content_type)
    |> where([c], is_nil(c.publish_at) or c.publish_at <= ^now)
    |> where([c], is_nil(c.expires_at) or c.expires_at > ^now)
    |> Repo.one!()
  end

  def get_content_by_slug!(nil, slug, content_type) do
    get_content_by_slug(nil, slug, content_type)
  end

  @doc """
  Preloads the tags association for a single content struct or list of content structs.
  Use to avoid N+1 queries when displaying tags.
  """
  @spec preload_tags(Content.t() | [Content.t()]) :: Content.t() | [Content.t()]
  def preload_tags(content_or_list) do
    Repo.preload(content_or_list, :tags)
  end

  defp by_content_type(query, content_type) do
    where(query, [c], c.content_type == ^content_type)
  end

  defp by_slug(query, slug) do
    where(query, [c], c.slug == ^slug)
  end
end

defmodule CodeMySpec.Content do
  @moduledoc """
  The Content Context manages all content entities (blog posts, pages, landing pages),
  their lifecycle (scheduling, expiration), SEO metadata, and tag associations.
  """

  import Ecto.Query, warn: false

  alias CodeMySpec.Repo
  alias CodeMySpec.Content.{Content, Tag, ContentTag, ContentRepository, TagRepository}
  alias CodeMySpec.Users.Scope

  # Content Queries

  @doc """
  Returns all published content for a given content type.

  Content is considered published when:
  - parse_status is 'success'
  - publish_at is in the past or nil
  - expires_at is in the future or nil
  """
  @spec list_published_content(Scope.t(), String.t()) :: [Content.t()]
  def list_published_content(%Scope{} = scope, content_type) do
    ContentRepository.list_published_content(scope, content_type)
  end

  @doc """
  Returns content scheduled for future publication.
  """
  @spec list_scheduled_content(Scope.t()) :: [Content.t()]
  def list_scheduled_content(%Scope{} = scope) do
    ContentRepository.list_scheduled_content(scope)
  end

  @doc """
  Returns content that has expired.
  """
  @spec list_expired_content(Scope.t()) :: [Content.t()]
  def list_expired_content(%Scope{} = scope) do
    ContentRepository.list_expired_content(scope)
  end

  @doc """
  Returns all content regardless of publish or expiration status.
  """
  @spec list_all_content(Scope.t()) :: [Content.t()]
  def list_all_content(%Scope{} = scope) do
    ContentRepository.list_content(scope)
  end

  @doc """
  Gets content by slug and content type. Raises if not found.
  """
  @spec get_content_by_slug!(Scope.t(), String.t(), String.t()) :: Content.t()
  def get_content_by_slug!(%Scope{} = scope, slug, content_type) do
    ContentRepository.get_content_by_slug!(scope, slug, content_type)
  end

  @doc """
  Gets content by id. Raises if not found.
  """
  @spec get_content!(Scope.t(), integer()) :: Content.t()
  def get_content!(%Scope{} = scope, id) do
    ContentRepository.get_content!(scope, id)
  end

  # Content CRUD

  @doc """
  Creates content with the given attributes.
  """
  @spec create_content(Scope.t(), map()) :: {:ok, Content.t()} | {:error, Ecto.Changeset.t()}
  def create_content(%Scope{} = scope, attrs) do
    attrs = add_scope_to_attrs(scope, attrs)

    %Content{}
    |> Content.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, content} = result ->
        broadcast_content_change(scope, {:created, content})
        result

      error ->
        error
    end
  end

  @doc """
  Creates multiple content records in a transaction.
  """
  @spec create_many(Scope.t(), [map()]) :: {:ok, [Content.t()]} | {:error, term()}
  def create_many(%Scope{} = scope, content_list) do
    Repo.transaction(fn ->
      Enum.map(content_list, fn attrs ->
        attrs = add_scope_to_attrs(scope, attrs)

        %Content{}
        |> Content.changeset(attrs)
        |> Repo.insert!()
      end)
    end)
    |> case do
      {:ok, content_list} = result ->
        Enum.each(content_list, fn content ->
          broadcast_content_change(scope, {:created, content})
        end)

        result

      error ->
        error
    end
  end

  @doc """
  Updates content with the given attributes.
  """
  @spec update_content(Scope.t(), Content.t(), map()) ::
          {:ok, Content.t()} | {:error, Ecto.Changeset.t()}
  def update_content(%Scope{} = scope, %Content{} = content, attrs) do
    verify_content_belongs_to_scope!(content, scope)

    content
    |> Content.changeset(attrs)
    |> Repo.update()
    |> case do
      {:ok, updated} = result ->
        broadcast_content_change(scope, {:updated, updated})
        result

      error ->
        error
    end
  end

  @doc """
  Deletes content.
  """
  @spec delete_content(Scope.t(), Content.t()) :: {:ok, Content.t()} | {:error, Ecto.Changeset.t()}
  def delete_content(%Scope{} = scope, %Content{} = content) do
    verify_content_belongs_to_scope!(content, scope)

    Repo.delete(content)
    |> case do
      {:ok, deleted} = result ->
        broadcast_content_change(scope, {:deleted, deleted})
        result

      error ->
        error
    end
  end

  @doc """
  Deletes all content for the given scope.
  """
  @spec delete_all_content(Scope.t()) :: {:ok, integer()}
  def delete_all_content(%Scope{} = scope) do
    {count, _} =
      Content
      |> where([c], c.account_id == ^scope.active_account_id)
      |> where([c], c.project_id == ^scope.active_project_id)
      |> Repo.delete_all()

    broadcast_content_change(scope, :bulk_delete)
    {:ok, count}
  end

  # Bulk Operations

  @doc """
  Deletes all expired content for the given scope.
  """
  @spec purge_expired_content(Scope.t()) :: {:ok, integer()}
  def purge_expired_content(%Scope{} = scope) do
    now = DateTime.utc_now()

    {count, _} =
      Content
      |> where([c], c.account_id == ^scope.active_account_id)
      |> where([c], c.project_id == ^scope.active_project_id)
      |> where([c], not is_nil(c.expires_at) and c.expires_at <= ^now)
      |> Repo.delete_all()

    if count > 0 do
      broadcast_content_change(scope, :purge_expired)
    end

    {:ok, count}
  end

  # Tag Management

  @doc """
  Returns all tags for the given scope.
  """
  @spec list_tags(Scope.t()) :: [Tag.t()]
  def list_tags(%Scope{} = scope) do
    TagRepository.list_tags(scope)
  end

  @doc """
  Creates a tag or returns existing tag with the same slug.
  """
  @spec upsert_tag(Scope.t(), String.t()) :: {:ok, Tag.t()} | {:error, Ecto.Changeset.t()}
  def upsert_tag(%Scope{} = scope, name) do
    TagRepository.upsert_tag(scope, name)
  end

  @doc """
  Returns all tags associated with the given content.
  """
  @spec get_content_tags(Scope.t(), Content.t()) :: [Tag.t()]
  def get_content_tags(%Scope{} = scope, %Content{} = content) do
    verify_content_belongs_to_scope!(content, scope)

    content
    |> ContentRepository.preload_tags()
    |> Map.get(:tags)
  end

  @doc """
  Synchronizes tags for content. Removes old associations and creates new ones.
  """
  @spec sync_content_tags(Scope.t(), Content.t(), [String.t()]) ::
          {:ok, Content.t()} | {:error, term()}
  def sync_content_tags(%Scope{} = scope, %Content{} = content, tag_names) do
    verify_content_belongs_to_scope!(content, scope)

    Repo.transaction(fn ->
      # Delete existing associations
      ContentTag
      |> where([ct], ct.content_id == ^content.id)
      |> Repo.delete_all()

      # Upsert tags and create new associations
      tag_names
      |> Enum.map(fn name ->
        {:ok, tag} = upsert_tag(scope, name)
        tag
      end)
      |> Enum.each(fn tag ->
        %ContentTag{}
        |> ContentTag.changeset(%{content_id: content.id, tag_id: tag.id})
        |> Repo.insert!()
      end)

      # Reload content with tags
      ContentRepository.get_content!(scope, content.id)
      |> ContentRepository.preload_tags()
    end)
  end

  # Status Queries

  @doc """
  Returns content filtered by the given criteria.

  Supported filters:
  - parse_status: "success", "error", "pending"
  - content_type: "blog", "page", "landing"
  """
  @spec list_content_with_status(Scope.t(), map()) :: [Content.t()]
  def list_content_with_status(%Scope{} = scope, filters) do
    query = Content

    query =
      query
      |> where([c], c.account_id == ^scope.active_account_id)
      |> where([c], c.project_id == ^scope.active_project_id)

    query =
      case Map.get(filters, :parse_status) do
        nil ->
          query

        status when is_binary(status) ->
          status_atom = String.to_existing_atom(status)
          where(query, [c], c.parse_status == ^status_atom)
      end

    query =
      case Map.get(filters, :content_type) do
        nil ->
          query

        type when is_binary(type) ->
          type_atom = String.to_existing_atom(type)
          where(query, [c], c.content_type == ^type_atom)
      end

    Repo.all(query)
  end

  @doc """
  Returns counts of content by parse status.
  """
  @spec count_by_parse_status(Scope.t()) :: %{success: integer(), error: integer()}
  def count_by_parse_status(%Scope{} = scope) do
    success_count =
      Content
      |> where([c], c.account_id == ^scope.active_account_id)
      |> where([c], c.project_id == ^scope.active_project_id)
      |> where([c], c.parse_status == :success)
      |> Repo.aggregate(:count)

    error_count =
      Content
      |> where([c], c.account_id == ^scope.active_account_id)
      |> where([c], c.project_id == ^scope.active_project_id)
      |> where([c], c.parse_status == :error)
      |> Repo.aggregate(:count)

    %{success: success_count, error: error_count}
  end

  # Private Helpers

  defp add_scope_to_attrs(%Scope{} = scope, attrs) do
    attrs
    |> Map.put(:account_id, scope.active_account_id)
    |> Map.put(:project_id, scope.active_project_id)
  end

  defp verify_content_belongs_to_scope!(%Content{} = content, %Scope{} = scope) do
    unless content.account_id == scope.active_account_id and
             content.project_id == scope.active_project_id do
      raise ArgumentError, "Content does not belong to the given scope"
    end

    :ok
  end

  defp broadcast_content_change(%Scope{} = scope, message) do
    Phoenix.PubSub.broadcast(
      CodeMySpec.PubSub,
      content_topic(scope),
      message
    )
  end

  defp content_topic(%Scope{} = scope) do
    "account:#{scope.active_account_id}:project:#{scope.active_project_id}:content"
  end
end
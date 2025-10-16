defmodule CodeMySpec.Content do
  @moduledoc """
  The Content Context manages published content for public and authenticated viewing.

  This is the production-ready content system that serves blog posts, pages, landing pages,
  and documentation to end users. Content is single-tenant (no account_id/project_id), and
  access control is based on authentication (scope vs nil) rather than multi-tenancy.

  ## Architectural Note

  Content is distinct from ContentAdmin:
  - **ContentAdmin**: Multi-tenant validation/preview layer where developers test content synced from Git
  - **Content**: Single-tenant published content layer where end users view finalized content

  Content is NOT copied from ContentAdmin. Publishing triggers a fresh Git pull, processes
  content, and POSTs to the Content sync endpoint.

  ## Scope Integration

  **Scope is for authentication, NOT multi-tenancy**:
  - **With %Scope{}**: User is authenticated → can access both public and protected content
  - **With nil**: Anonymous visitor → can only access public content (protected = false)

  NO account_id or project_id filtering. All queries are unscoped from a multi-tenant perspective.
  """

  import Ecto.Query, warn: false

  alias CodeMySpec.Repo
  alias CodeMySpec.Content.{Content, Tag, ContentTag, ContentRepository}
  alias CodeMySpec.Users.Scope

  # Content Retrieval

  @doc """
  Returns all published content for a given content type.

  Content is considered published when:
  - publish_at is in the past or nil
  - expires_at is in the future or nil

  ## Parameters
    - scope_or_nil: %Scope{} for authenticated users (access to protected content), nil for anonymous (public only)
    - content_type: String "blog", "page", "landing", or "documentation"

  ## Examples

      # Anonymous user - only public content
      Content.list_published_content(nil, "blog")

      # Authenticated user - public AND protected content
      Content.list_published_content(scope, "blog")
  """
  @spec list_published_content(Scope.t() | nil, String.t()) :: [Content.t()]
  def list_published_content(scope_or_nil, content_type) do
    ContentRepository.list_published_content(scope_or_nil, content_type)
  end

  @doc """
  Gets content by slug and content type.

  Returns nil if not found or if content is protected and scope is nil.

  ## Parameters
    - scope_or_nil: %Scope{} for authenticated users, nil for anonymous
    - slug: String slug identifier
    - content_type: String "blog", "page", "landing", or "documentation"

  ## Examples

      # Try to get public content (anonymous)
      Content.get_content_by_slug(nil, "my-post", "blog")

      # Get any published content (authenticated)
      Content.get_content_by_slug(scope, "my-post", "blog")
  """
  @spec get_content_by_slug(Scope.t() | nil, String.t(), String.t()) :: Content.t() | nil
  def get_content_by_slug(scope_or_nil, slug, content_type) do
    ContentRepository.get_content_by_slug(scope_or_nil, slug, content_type)
  end

  @doc """
  Gets content by slug and content type. Raises if not found.

  With %Scope{}: Raises Ecto.NoResultsError if not found.
  With nil: Returns nil if not found (non-raising for anonymous users).

  ## Parameters
    - scope_or_nil: %Scope{} for authenticated users, nil for anonymous
    - slug: String slug identifier
    - content_type: String "blog", "page", "landing", or "documentation"

  ## Examples

      # Authenticated - raises if not found
      Content.get_content_by_slug!(scope, "my-post", "blog")

      # Anonymous - returns nil if not found (non-raising)
      Content.get_content_by_slug!(nil, "my-post", "blog")
  """
  @spec get_content_by_slug!(Scope.t() | nil, String.t(), String.t()) :: Content.t() | nil
  def get_content_by_slug!(scope_or_nil, slug, content_type) do
    ContentRepository.get_content_by_slug!(scope_or_nil, slug, content_type)
  end

  # Content Sync (Publishing Flow)

  @doc """
  Synchronizes content from publishing flow.

  Deletes all existing content and creates new content records in a transaction.
  This ensures Content always reflects the GitHub source of truth.

  ## Publishing Flow

  1. Developer clicks "Publish" in ContentAdmin UI
  2. Server pulls latest from GitHub repository
  3. Server processes content files (markdown → HTML, parse frontmatter)
  4. Server extracts/generates tags
  5. Server POSTs processed content to `/api/content/sync` endpoint
  6. This function handles the sync

  ## Parameters
    - content_list: List of content maps with all fields (slug, title, content_type, processed_content, etc.)

  ## Examples

      Content.sync_content([
        %{slug: "post-1", title: "Post 1", content_type: "blog", processed_content: "<h1>Post 1</h1>", ...},
        %{slug: "post-2", title: "Post 2", content_type: "blog", processed_content: "<h1>Post 2</h1>", ...}
      ])
  """
  @spec sync_content([map()]) :: {:ok, [Content.t()]} | {:error, term()}
  def sync_content(content_list) do
    require Logger

    Repo.transaction(fn ->
      # Delete all existing content
      {deleted_count, _} = Repo.delete_all(Content)
      Logger.info("Deleted #{deleted_count} existing content records")

      # Build changesets
      changesets =
        Enum.with_index(content_list, fn attrs, index ->
          changeset = Content.changeset(%Content{}, attrs)
          {changeset, index}
        end)

      # Log validation errors
      changesets
      |> Enum.filter(fn {cs, _index} -> not cs.valid? end)
      |> Enum.each(fn {cs, index} ->
        errors =
          Ecto.Changeset.traverse_errors(cs, fn {msg, opts} ->
            Enum.reduce(opts, msg, fn {key, value}, acc ->
              String.replace(acc, "%{#{key}}", to_string(value))
            end)
          end)

        title = Map.get(cs.changes, :title, "untitled")
        error_string = CodeMySpec.Utils.changeset_error_to_string(cs)

        Logger.error(
          "Content validation failed at index #{index}: #{title} - #{error_string}",
          changeset_errors: errors,
          changeset_changes: cs.changes,
          index: index
        )
      end)

      # Check for invalid changesets
      case Enum.find(changesets, fn {cs, _index} -> not cs.valid? end) do
        nil ->
          # All valid, insert content
          content_records =
            Enum.map(changesets, fn {changeset, _index} ->
              Repo.insert!(changeset)
            end)

          Logger.info("Created #{length(content_records)} new content records")
          content_records

        {invalid_changeset, index} ->
          Logger.error("Aborting sync_content due to validation failure at index #{index}")
          Repo.rollback(invalid_changeset)
      end
    end)
  end

  @doc """
  Deletes all content.

  Used during sync to clear existing content before inserting new content.

  ## Examples

      Content.delete_all_content()
      # => {:ok, 42}
  """
  @spec delete_all_content() :: {:ok, integer()}
  def delete_all_content do
    {count, _} = Repo.delete_all(Content)
    {:ok, count}
  end

  # Tag Management

  @doc """
  Returns all tags.

  No scoping - returns all tags in the system.

  ## Examples

      Content.list_all_tags()
      # => [%Tag{name: "elixir", slug: "elixir"}, ...]
  """
  @spec list_all_tags() :: [Tag.t()]
  def list_all_tags do
    Repo.all(Tag)
  end

  @doc """
  Returns all tags associated with the given content.

  ## Parameters
    - content: Content struct

  ## Examples

      content = Content.get_content_by_slug(scope, "my-post", "blog")
      Content.get_content_tags(content)
      # => [%Tag{name: "elixir", slug: "elixir"}, ...]
  """
  @spec get_content_tags(Content.t()) :: [Tag.t()]
  def get_content_tags(%Content{} = content) do
    content
    |> ContentRepository.preload_tags()
    |> Map.get(:tags)
  end

  @doc """
  Creates or returns existing tag with the given name.

  Generates slug from name automatically.

  ## Parameters
    - name: String tag name

  ## Examples

      Content.upsert_tag("Elixir")
      # => {:ok, %Tag{name: "Elixir", slug: "elixir"}}
  """
  @spec upsert_tag(String.t()) :: {:ok, Tag.t()} | {:error, Ecto.Changeset.t()}
  def upsert_tag(name) do
    slug = slugify(name)

    case Repo.get_by(Tag, slug: slug) do
      nil ->
        %Tag{}
        |> Tag.changeset(%{name: name, slug: slug})
        |> Repo.insert()

      tag ->
        {:ok, tag}
    end
  end

  # Helper to generate slug from name
  defp slugify(string) do
    string
    |> String.downcase()
    |> String.replace(~r/[^\w\s-]/, "")
    |> String.replace(~r/\s+/, "-")
    |> String.replace(~r/-+/, "-")
    |> String.trim("-")
  end

  @doc """
  Synchronizes tags for content.

  Removes old tag associations and creates new ones.

  ## Parameters
    - content: Content struct
    - tag_names: List of tag name strings

  ## Examples

      content = Content.get_content_by_slug(scope, "my-post", "blog")
      Content.sync_content_tags(content, ["elixir", "phoenix", "liveview"])
      # => {:ok, %Content{tags: [...]}}
  """
  @spec sync_content_tags(Content.t(), [String.t()]) :: {:ok, Content.t()} | {:error, term()}
  def sync_content_tags(%Content{} = content, tag_names) do
    Repo.transaction(fn ->
      # Delete existing associations
      ContentTag
      |> where([ct], ct.content_id == ^content.id)
      |> Repo.delete_all()

      # Upsert tags and create new associations
      tag_names
      |> Enum.map(fn name ->
        {:ok, tag} = upsert_tag(name)
        tag
      end)
      |> Enum.each(fn tag ->
        %ContentTag{}
        |> ContentTag.changeset(%{content_id: content.id, tag_id: tag.id})
        |> Repo.insert!()
      end)

      # Reload content with tags
      content
      |> Repo.reload!()
      |> ContentRepository.preload_tags()
    end)
  end
end

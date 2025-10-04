defmodule CodeMySpec.Content.ContentRepositoryTest do
  use CodeMySpec.DataCase, async: true

  import CodeMySpec.UsersFixtures
  import CodeMySpec.ContentFixtures
  import CodeMySpec.TagFixtures
  import CodeMySpec.ContentTagFixtures

  alias CodeMySpec.Content.ContentRepository

  describe "list_content/1" do
    test "returns all content for scope without filtering" do
      scope = full_scope_fixture()

      published = published_content_fixture(scope.active_project, scope.active_account)
      scheduled = scheduled_content_fixture(scope.active_project, scope.active_account)
      expired = expired_content_fixture(scope.active_project, scope.active_account)

      content_list = ContentRepository.list_content(scope)

      assert length(content_list) == 3
      content_ids = Enum.map(content_list, & &1.id)
      assert published.id in content_ids
      assert scheduled.id in content_ids
      assert expired.id in content_ids
    end

    test "returns content regardless of parse status" do
      scope = full_scope_fixture()

      pending = content_fixture(scope.active_project, scope.active_account, %{parse_status: "pending"})
      success = content_fixture(scope.active_project, scope.active_account, %{parse_status: "success"})
      failed = failed_content_fixture(scope.active_project, scope.active_account)

      content_list = ContentRepository.list_content(scope)

      assert length(content_list) == 3
      content_ids = Enum.map(content_list, & &1.id)
      assert pending.id in content_ids
      assert success.id in content_ids
      assert failed.id in content_ids
    end

    test "returns empty list when no content exists in scope" do
      scope = full_scope_fixture()

      content_list = ContentRepository.list_content(scope)

      assert content_list == []
    end

    test "only returns content from scoped project" do
      scope1 = full_scope_fixture()
      scope2 = full_scope_fixture()

      content1 = content_fixture(scope1.active_project, scope1.active_account)
      _content2 = content_fixture(scope2.active_project, scope2.active_account)

      content_list = ContentRepository.list_content(scope1)

      assert length(content_list) == 1
      assert List.first(content_list).id == content1.id
    end

    test "only returns content from scoped account" do
      scope1 = full_scope_fixture()
      scope2 = full_scope_fixture()

      _content1 = content_fixture(scope1.active_project, scope1.active_account)
      _content2 = content_fixture(scope2.active_project, scope2.active_account)

      content_list = ContentRepository.list_content(scope1)

      assert length(content_list) == 1
      assert List.first(content_list).account_id == scope1.active_account_id
    end

    test "enforces multi-tenant isolation" do
      scope1 = full_scope_fixture()
      scope2 = full_scope_fixture()

      _content1 = content_fixture(scope1.active_project, scope1.active_account)
      _content2 = content_fixture(scope1.active_project, scope1.active_account)
      _content3 = content_fixture(scope2.active_project, scope2.active_account)

      content_list1 = ContentRepository.list_content(scope1)
      content_list2 = ContentRepository.list_content(scope2)

      assert length(content_list1) == 2
      assert length(content_list2) == 1

      assert Enum.all?(content_list1, &(&1.account_id == scope1.active_account_id))
      assert Enum.all?(content_list1, &(&1.project_id == scope1.active_project_id))
    end
  end

  describe "list_published_content/2" do
    test "returns only published content with success parse status" do
      scope = full_scope_fixture()

      published = published_content_fixture(scope.active_project, scope.active_account, %{content_type: "blog"})
      _scheduled = scheduled_content_fixture(scope.active_project, scope.active_account, %{content_type: "blog"})
      _expired = expired_content_fixture(scope.active_project, scope.active_account, %{content_type: "blog"})

      content_list = ContentRepository.list_published_content(scope, "blog")

      assert length(content_list) == 1
      assert List.first(content_list).id == published.id
    end

    test "filters by content_type" do
      scope = full_scope_fixture()

      blog = published_content_fixture(scope.active_project, scope.active_account, %{content_type: "blog"})
      _page = published_content_fixture(scope.active_project, scope.active_account, %{content_type: "page"})

      blog_list = ContentRepository.list_published_content(scope, "blog")
      page_list = ContentRepository.list_published_content(scope, "page")

      assert length(blog_list) == 1
      assert length(page_list) == 1
      assert List.first(blog_list).id == blog.id
    end

    test "excludes content with parse_status other than success" do
      scope = full_scope_fixture()

      now = DateTime.utc_now()
      yesterday = DateTime.add(now, -1, :day)

      _pending = content_fixture(scope.active_project, scope.active_account, %{
        content_type: "blog",
        publish_at: yesterday,
        parse_status: "pending"
      })

      _failed = content_fixture(scope.active_project, scope.active_account, %{
        content_type: "blog",
        publish_at: yesterday,
        parse_status: "error",
        parse_errors: %{"error" => "test"}
      })

      content_list = ContentRepository.list_published_content(scope, "blog")

      assert content_list == []
    end

    test "includes content with publish_at in past and no expires_at" do
      scope = full_scope_fixture()

      yesterday = DateTime.utc_now() |> DateTime.add(-1, :day)

      content = content_fixture(scope.active_project, scope.active_account, %{
        content_type: "blog",
        publish_at: yesterday,
        expires_at: nil,
        parse_status: "success"
      })

      content_list = ContentRepository.list_published_content(scope, "blog")

      assert length(content_list) == 1
      assert List.first(content_list).id == content.id
    end

    test "includes content with expires_at in future" do
      scope = full_scope_fixture()

      yesterday = DateTime.utc_now() |> DateTime.add(-1, :day)
      tomorrow = DateTime.utc_now() |> DateTime.add(1, :day)

      content = content_fixture(scope.active_project, scope.active_account, %{
        content_type: "blog",
        publish_at: yesterday,
        expires_at: tomorrow,
        parse_status: "success"
      })

      content_list = ContentRepository.list_published_content(scope, "blog")

      assert length(content_list) == 1
      assert List.first(content_list).id == content.id
    end

    test "respects multi-tenant scope" do
      scope1 = full_scope_fixture()
      scope2 = full_scope_fixture()

      content1 = published_content_fixture(scope1.active_project, scope1.active_account, %{content_type: "blog"})
      _content2 = published_content_fixture(scope2.active_project, scope2.active_account, %{content_type: "blog"})

      content_list = ContentRepository.list_published_content(scope1, "blog")

      assert length(content_list) == 1
      assert List.first(content_list).id == content1.id
    end
  end

  describe "list_scheduled_content/1" do
    test "returns content scheduled for future publication" do
      scope = full_scope_fixture()

      scheduled = scheduled_content_fixture(scope.active_project, scope.active_account)
      _published = published_content_fixture(scope.active_project, scope.active_account)

      content_list = ContentRepository.list_scheduled_content(scope)

      assert length(content_list) == 1
      assert List.first(content_list).id == scheduled.id
    end

    test "excludes content with publish_at in past or present" do
      scope = full_scope_fixture()

      now = DateTime.utc_now()
      yesterday = DateTime.add(now, -1, :day)

      _past = content_fixture(scope.active_project, scope.active_account, %{publish_at: yesterday})
      _present = content_fixture(scope.active_project, scope.active_account, %{publish_at: now})

      content_list = ContentRepository.list_scheduled_content(scope)

      assert content_list == []
    end

    test "includes scheduled content regardless of parse status" do
      scope = full_scope_fixture()

      tomorrow = DateTime.utc_now() |> DateTime.add(1, :day)

      pending = content_fixture(scope.active_project, scope.active_account, %{
        publish_at: tomorrow,
        parse_status: "pending"
      })

      content_list = ContentRepository.list_scheduled_content(scope)

      assert length(content_list) == 1
      assert List.first(content_list).id == pending.id
    end

    test "respects multi-tenant scope" do
      scope1 = full_scope_fixture()
      scope2 = full_scope_fixture()

      scheduled1 = scheduled_content_fixture(scope1.active_project, scope1.active_account)
      _scheduled2 = scheduled_content_fixture(scope2.active_project, scope2.active_account)

      content_list = ContentRepository.list_scheduled_content(scope1)

      assert length(content_list) == 1
      assert List.first(content_list).id == scheduled1.id
    end
  end

  describe "list_expired_content/1" do
    test "returns content that has passed expiration date" do
      scope = full_scope_fixture()

      expired = expired_content_fixture(scope.active_project, scope.active_account)
      _published = published_content_fixture(scope.active_project, scope.active_account)

      content_list = ContentRepository.list_expired_content(scope)

      assert length(content_list) == 1
      assert List.first(content_list).id == expired.id
    end

    test "excludes content with expires_at in future or nil" do
      scope = full_scope_fixture()

      tomorrow = DateTime.utc_now() |> DateTime.add(1, :day)

      _future = content_fixture(scope.active_project, scope.active_account, %{
        publish_at: DateTime.utc_now(),
        expires_at: tomorrow
      })

      _no_expiry = content_fixture(scope.active_project, scope.active_account, %{
        publish_at: DateTime.utc_now(),
        expires_at: nil
      })

      content_list = ContentRepository.list_expired_content(scope)

      assert content_list == []
    end

    test "respects multi-tenant scope" do
      scope1 = full_scope_fixture()
      scope2 = full_scope_fixture()

      expired1 = expired_content_fixture(scope1.active_project, scope1.active_account)
      _expired2 = expired_content_fixture(scope2.active_project, scope2.active_account)

      content_list = ContentRepository.list_expired_content(scope1)

      assert length(content_list) == 1
      assert List.first(content_list).id == expired1.id
    end
  end

  describe "list_content_by_type/2" do
    test "returns all content for specific content_type" do
      scope = full_scope_fixture()

      blog1 = blog_post_fixture(scope.active_project, scope.active_account)
      blog2 = blog_post_fixture(scope.active_project, scope.active_account)
      _page = page_fixture(scope.active_project, scope.active_account)

      blog_list = ContentRepository.list_content_by_type(scope, "blog")

      assert length(blog_list) == 2
      blog_ids = Enum.map(blog_list, & &1.id)
      assert blog1.id in blog_ids
      assert blog2.id in blog_ids
    end

    test "returns content regardless of publication status" do
      scope = full_scope_fixture()

      published = published_content_fixture(scope.active_project, scope.active_account, %{content_type: "page"})
      scheduled = scheduled_content_fixture(scope.active_project, scope.active_account, %{content_type: "page"})
      expired = expired_content_fixture(scope.active_project, scope.active_account, %{content_type: "page"})

      page_list = ContentRepository.list_content_by_type(scope, "page")

      assert length(page_list) == 3
      page_ids = Enum.map(page_list, & &1.id)
      assert published.id in page_ids
      assert scheduled.id in page_ids
      assert expired.id in page_ids
    end

    test "returns content regardless of parse status" do
      scope = full_scope_fixture()

      pending = content_fixture(scope.active_project, scope.active_account, %{
        content_type: "landing",
        parse_status: "pending"
      })

      success = content_fixture(scope.active_project, scope.active_account, %{
        content_type: "landing",
        parse_status: "success"
      })

      failed = content_fixture(scope.active_project, scope.active_account, %{
        content_type: "landing",
        parse_status: "error",
        parse_errors: %{"error" => "test"}
      })

      landing_list = ContentRepository.list_content_by_type(scope, "landing")

      assert length(landing_list) == 3
      landing_ids = Enum.map(landing_list, & &1.id)
      assert pending.id in landing_ids
      assert success.id in landing_ids
      assert failed.id in landing_ids
    end

    test "respects multi-tenant scope" do
      scope1 = full_scope_fixture()
      scope2 = full_scope_fixture()

      blog1 = blog_post_fixture(scope1.active_project, scope1.active_account)
      _blog2 = blog_post_fixture(scope2.active_project, scope2.active_account)

      blog_list = ContentRepository.list_content_by_type(scope1, "blog")

      assert length(blog_list) == 1
      assert List.first(blog_list).id == blog1.id
    end
  end

  describe "list_content_by_parse_status/2" do
    test "returns content filtered by parse_status" do
      scope = full_scope_fixture()

      pending = content_fixture(scope.active_project, scope.active_account, %{parse_status: "pending"})
      _success = content_fixture(scope.active_project, scope.active_account, %{parse_status: "success"})

      pending_list = ContentRepository.list_content_by_parse_status(scope, "pending")

      assert length(pending_list) == 1
      assert List.first(pending_list).id == pending.id
    end

    test "returns error status content with parse_errors" do
      scope = full_scope_fixture()

      failed1 = failed_content_fixture(scope.active_project, scope.active_account)
      failed2 = failed_content_fixture(scope.active_project, scope.active_account)
      _success = content_fixture(scope.active_project, scope.active_account, %{parse_status: "success"})

      error_list = ContentRepository.list_content_by_parse_status(scope, "error")

      assert length(error_list) == 2
      error_ids = Enum.map(error_list, & &1.id)
      assert failed1.id in error_ids
      assert failed2.id in error_ids
    end

    test "returns success status content" do
      scope = full_scope_fixture()

      success1 = content_fixture(scope.active_project, scope.active_account, %{parse_status: "success"})
      success2 = content_fixture(scope.active_project, scope.active_account, %{parse_status: "success"})
      _pending = content_fixture(scope.active_project, scope.active_account, %{parse_status: "pending"})

      success_list = ContentRepository.list_content_by_parse_status(scope, "success")

      assert length(success_list) == 2
      success_ids = Enum.map(success_list, & &1.id)
      assert success1.id in success_ids
      assert success2.id in success_ids
    end

    test "respects multi-tenant scope" do
      scope1 = full_scope_fixture()
      scope2 = full_scope_fixture()

      pending1 = content_fixture(scope1.active_project, scope1.active_account, %{parse_status: "pending"})
      _pending2 = content_fixture(scope2.active_project, scope2.active_account, %{parse_status: "pending"})

      pending_list = ContentRepository.list_content_by_parse_status(scope1, "pending")

      assert length(pending_list) == 1
      assert List.first(pending_list).id == pending1.id
    end
  end

  describe "get_content/2" do
    test "returns content when id exists in scope" do
      scope = full_scope_fixture()

      created = content_fixture(scope.active_project, scope.active_account)

      content = ContentRepository.get_content(scope, created.id)

      assert content.id == created.id
      assert content.slug == created.slug
    end

    test "returns nil when content does not exist" do
      scope = full_scope_fixture()

      content = ContentRepository.get_content(scope, 999_999)

      assert content == nil
    end

    test "returns nil when content exists in different project" do
      scope1 = full_scope_fixture()
      scope2 = full_scope_fixture()

      created = content_fixture(scope1.active_project, scope1.active_account)

      content = ContentRepository.get_content(scope2, created.id)

      assert content == nil
    end

    test "returns nil when content exists in different account" do
      scope1 = full_scope_fixture()
      scope2 = full_scope_fixture()

      created = content_fixture(scope1.active_project, scope1.active_account)

      content = ContentRepository.get_content(scope2, created.id)

      assert content == nil
    end

    test "enforces multi-tenant isolation" do
      scope1 = full_scope_fixture()
      scope2 = full_scope_fixture()

      content1 = content_fixture(scope1.active_project, scope1.active_account)
      content2 = content_fixture(scope2.active_project, scope2.active_account)

      result1 = ContentRepository.get_content(scope1, content1.id)
      result2 = ContentRepository.get_content(scope2, content2.id)

      assert result1.id == content1.id
      assert result2.id == content2.id

      # Cross-scope access returns nil
      assert ContentRepository.get_content(scope1, content2.id) == nil
      assert ContentRepository.get_content(scope2, content1.id) == nil
    end
  end

  describe "get_content!/2" do
    test "returns content when id exists in scope" do
      scope = full_scope_fixture()

      created = content_fixture(scope.active_project, scope.active_account)

      content = ContentRepository.get_content!(scope, created.id)

      assert content.id == created.id
      assert content.slug == created.slug
    end

    test "raises Ecto.NoResultsError when content does not exist" do
      scope = full_scope_fixture()

      assert_raise Ecto.NoResultsError, fn ->
        ContentRepository.get_content!(scope, 999_999)
      end
    end

    test "raises Ecto.NoResultsError when content exists in different project" do
      scope1 = full_scope_fixture()
      scope2 = full_scope_fixture()

      created = content_fixture(scope1.active_project, scope1.active_account)

      assert_raise Ecto.NoResultsError, fn ->
        ContentRepository.get_content!(scope2, created.id)
      end
    end

    test "raises Ecto.NoResultsError when content exists in different account" do
      scope1 = full_scope_fixture()
      scope2 = full_scope_fixture()

      created = content_fixture(scope1.active_project, scope1.active_account)

      assert_raise Ecto.NoResultsError, fn ->
        ContentRepository.get_content!(scope2, created.id)
      end
    end
  end

  describe "get_content_by_slug/3" do
    test "returns content when slug and content_type exist in scope" do
      scope = full_scope_fixture()

      created = blog_post_fixture(scope.active_project, scope.active_account, %{slug: "test-post"})

      content = ContentRepository.get_content_by_slug(scope, "test-post", "blog")

      assert content.id == created.id
      assert content.slug == "test-post"
      assert content.content_type == :blog
    end

    test "returns nil when slug does not exist" do
      scope = full_scope_fixture()

      content = ContentRepository.get_content_by_slug(scope, "nonexistent", "blog")

      assert content == nil
    end

    test "returns nil when content_type does not match" do
      scope = full_scope_fixture()

      _blog = blog_post_fixture(scope.active_project, scope.active_account, %{slug: "test-slug"})

      content = ContentRepository.get_content_by_slug(scope, "test-slug", "page")

      assert content == nil
    end

    test "enforces slug uniqueness per content_type" do
      scope = full_scope_fixture()

      blog = blog_post_fixture(scope.active_project, scope.active_account, %{slug: "shared-slug"})
      page = page_fixture(scope.active_project, scope.active_account, %{slug: "shared-slug"})

      blog_result = ContentRepository.get_content_by_slug(scope, "shared-slug", "blog")
      page_result = ContentRepository.get_content_by_slug(scope, "shared-slug", "page")

      assert blog_result.id == blog.id
      assert page_result.id == page.id
      assert blog_result.id != page_result.id
    end

    test "returns nil when slug exists in different project" do
      scope1 = full_scope_fixture()
      scope2 = full_scope_fixture()

      _blog = blog_post_fixture(scope1.active_project, scope1.active_account, %{slug: "project-post"})

      content = ContentRepository.get_content_by_slug(scope2, "project-post", "blog")

      assert content == nil
    end

    test "returns nil when slug exists in different account" do
      scope1 = full_scope_fixture()
      scope2 = full_scope_fixture()

      _blog = blog_post_fixture(scope1.active_project, scope1.active_account, %{slug: "account-post"})

      content = ContentRepository.get_content_by_slug(scope2, "account-post", "blog")

      assert content == nil
    end

    test "enforces multi-tenant isolation" do
      scope1 = full_scope_fixture()
      scope2 = full_scope_fixture()

      blog1 = blog_post_fixture(scope1.active_project, scope1.active_account, %{slug: "shared-slug"})
      blog2 = blog_post_fixture(scope2.active_project, scope2.active_account, %{slug: "shared-slug"})

      result1 = ContentRepository.get_content_by_slug(scope1, "shared-slug", "blog")
      result2 = ContentRepository.get_content_by_slug(scope2, "shared-slug", "blog")

      assert result1.id == blog1.id
      assert result2.id == blog2.id
      assert result1.id != result2.id
    end
  end

  describe "get_content_by_slug!/3" do
    test "returns content when slug and content_type exist in scope" do
      scope = full_scope_fixture()

      created = blog_post_fixture(scope.active_project, scope.active_account, %{slug: "test-post"})

      content = ContentRepository.get_content_by_slug!(scope, "test-post", "blog")

      assert content.id == created.id
      assert content.slug == "test-post"
    end

    test "raises Ecto.NoResultsError when slug does not exist" do
      scope = full_scope_fixture()

      assert_raise Ecto.NoResultsError, fn ->
        ContentRepository.get_content_by_slug!(scope, "nonexistent", "blog")
      end
    end

    test "raises Ecto.NoResultsError when content_type does not match" do
      scope = full_scope_fixture()

      _blog = blog_post_fixture(scope.active_project, scope.active_account, %{slug: "test-slug"})

      assert_raise Ecto.NoResultsError, fn ->
        ContentRepository.get_content_by_slug!(scope, "test-slug", "page")
      end
    end

    test "raises Ecto.NoResultsError when slug exists in different project" do
      scope1 = full_scope_fixture()
      scope2 = full_scope_fixture()

      _blog = blog_post_fixture(scope1.active_project, scope1.active_account, %{slug: "project-post"})

      assert_raise Ecto.NoResultsError, fn ->
        ContentRepository.get_content_by_slug!(scope2, "project-post", "blog")
      end
    end

    test "raises Ecto.NoResultsError when slug exists in different account" do
      scope1 = full_scope_fixture()
      scope2 = full_scope_fixture()

      _blog = blog_post_fixture(scope1.active_project, scope1.active_account, %{slug: "account-post"})

      assert_raise Ecto.NoResultsError, fn ->
        ContentRepository.get_content_by_slug!(scope2, "account-post", "blog")
      end
    end
  end

  describe "preload_tags/1" do
    test "preloads tags for single content" do
      scope = full_scope_fixture()

      content = content_fixture(scope.active_project, scope.active_account)
      tag1 = tag_fixture(scope.active_project, scope.active_account, %{name: "tag1"})
      tag2 = tag_fixture(scope.active_project, scope.active_account, %{name: "tag2"})

      _ct1 = content_tag_fixture(content, tag1)
      _ct2 = content_tag_fixture(content, tag2)

      loaded_content = ContentRepository.preload_tags(content)

      assert Ecto.assoc_loaded?(loaded_content.tags)
      assert length(loaded_content.tags) == 2
      tag_names = Enum.map(loaded_content.tags, & &1.name)
      assert "tag1" in tag_names
      assert "tag2" in tag_names
    end

    test "preloads tags for list of content" do
      scope = full_scope_fixture()

      content1 = content_fixture(scope.active_project, scope.active_account)
      content2 = content_fixture(scope.active_project, scope.active_account)

      tag1 = tag_fixture(scope.active_project, scope.active_account, %{name: "tag1"})
      tag2 = tag_fixture(scope.active_project, scope.active_account, %{name: "tag2"})

      _ct1 = content_tag_fixture(content1, tag1)
      _ct2 = content_tag_fixture(content2, tag2)

      loaded_content_list = ContentRepository.preload_tags([content1, content2])

      assert length(loaded_content_list) == 2
      assert Enum.all?(loaded_content_list, &Ecto.assoc_loaded?(&1.tags))

      [first, second] = loaded_content_list
      assert length(first.tags) == 1
      assert length(second.tags) == 1
    end

    test "handles content with no tags" do
      scope = full_scope_fixture()

      content = content_fixture(scope.active_project, scope.active_account)

      loaded_content = ContentRepository.preload_tags(content)

      assert Ecto.assoc_loaded?(loaded_content.tags)
      assert loaded_content.tags == []
    end

    test "handles empty list" do
      loaded_content_list = ContentRepository.preload_tags([])

      assert loaded_content_list == []
    end

    test "avoids N+1 queries when loading tags" do
      scope = full_scope_fixture()

      content1 = content_fixture(scope.active_project, scope.active_account)
      content2 = content_fixture(scope.active_project, scope.active_account)
      content3 = content_fixture(scope.active_project, scope.active_account)

      tag = tag_fixture(scope.active_project, scope.active_account)

      _ct1 = content_tag_fixture(content1, tag)
      _ct2 = content_tag_fixture(content2, tag)
      _ct3 = content_tag_fixture(content3, tag)

      # Load without preloading first
      content_list = [content1, content2, content3]

      # Preload in single operation
      loaded_list = ContentRepository.preload_tags(content_list)

      assert length(loaded_list) == 3
      assert Enum.all?(loaded_list, &Ecto.assoc_loaded?(&1.tags))
      assert Enum.all?(loaded_list, &(length(&1.tags) == 1))
    end
  end
end
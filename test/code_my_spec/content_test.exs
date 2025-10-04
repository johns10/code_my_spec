defmodule CodeMySpec.ContentTest do
  use CodeMySpec.DataCase, async: true

  import CodeMySpec.UsersFixtures
  import CodeMySpec.ContentFixtures
  import CodeMySpec.TagFixtures

  alias CodeMySpec.Content

  describe "list_published_content/2" do
    test "returns only published content with success parse status" do
      scope = full_scope_fixture()

      published = published_content_fixture(scope.active_project, scope.active_account, %{content_type: "blog"})
      _scheduled = scheduled_content_fixture(scope.active_project, scope.active_account, %{content_type: "blog"})
      _expired = expired_content_fixture(scope.active_project, scope.active_account, %{content_type: "blog"})

      result = Content.list_published_content(scope, "blog")

      assert length(result) == 1
      assert List.first(result).id == published.id
    end
  end

  describe "list_scheduled_content/1" do
    test "returns content scheduled for future publication" do
      scope = full_scope_fixture()

      scheduled = scheduled_content_fixture(scope.active_project, scope.active_account)
      _published = published_content_fixture(scope.active_project, scope.active_account)

      result = Content.list_scheduled_content(scope)

      assert length(result) == 1
      assert List.first(result).id == scheduled.id
    end
  end

  describe "list_expired_content/1" do
    test "returns content past expiration date" do
      scope = full_scope_fixture()

      expired = expired_content_fixture(scope.active_project, scope.active_account)
      _published = published_content_fixture(scope.active_project, scope.active_account)

      result = Content.list_expired_content(scope)

      assert length(result) == 1
      assert List.first(result).id == expired.id
    end
  end

  describe "list_all_content/1" do
    test "returns all content regardless of status" do
      scope = full_scope_fixture()

      _published = published_content_fixture(scope.active_project, scope.active_account)
      _scheduled = scheduled_content_fixture(scope.active_project, scope.active_account)
      _expired = expired_content_fixture(scope.active_project, scope.active_account)

      result = Content.list_all_content(scope)

      assert length(result) == 3
    end
  end

  describe "get_content_by_slug!/3" do
    test "returns content by slug and type" do
      scope = full_scope_fixture()

      created = published_content_fixture(scope.active_project, scope.active_account, %{
        slug: "test-post",
        content_type: "blog"
      })

      result = Content.get_content_by_slug!(scope, "test-post", "blog")

      assert result.id == created.id
    end

    test "raises when content not found" do
      scope = full_scope_fixture()

      assert_raise Ecto.NoResultsError, fn ->
        Content.get_content_by_slug!(scope, "nonexistent", "blog")
      end
    end
  end

  describe "get_content!/2" do
    test "returns content by id" do
      scope = full_scope_fixture()

      created = content_fixture(scope.active_project, scope.active_account)

      result = Content.get_content!(scope, created.id)

      assert result.id == created.id
    end

    test "raises when content not found" do
      scope = full_scope_fixture()

      assert_raise Ecto.NoResultsError, fn ->
        Content.get_content!(scope, 999_999)
      end
    end
  end

  describe "create_content/2" do
    test "creates content with valid attributes" do
      scope = full_scope_fixture()

      attrs = %{
        slug: "new-post",
        content_type: :blog,
        raw_content: "# Hello World",
        processed_content: "<h1>Hello World</h1>",
        parse_status: "success"
      }

      {:ok, content} = Content.create_content(scope, attrs)

      assert content.slug == "new-post"
      assert content.content_type == :blog
      assert content.account_id == scope.active_account_id
      assert content.project_id == scope.active_project_id
    end

    test "returns error with invalid attributes" do
      scope = full_scope_fixture()

      {:error, changeset} = Content.create_content(scope, %{})

      assert changeset.errors[:slug]
      assert changeset.errors[:content_type]
    end
  end

  describe "create_many/2" do
    test "creates multiple content records in transaction" do
      scope = full_scope_fixture()

      content_list = [
        %{slug: "post-1", content_type: :blog, raw_content: "Content 1", parse_status: "success"},
        %{slug: "post-2", content_type: :blog, raw_content: "Content 2", parse_status: "success"}
      ]

      {:ok, results} = Content.create_many(scope, content_list)

      assert length(results) == 2
      assert Enum.all?(results, &(&1.account_id == scope.active_account_id))
      assert Enum.all?(results, &(&1.project_id == scope.active_project_id))
    end
  end

  describe "update_content/3" do
    test "updates content with valid attributes" do
      scope = full_scope_fixture()

      content = content_fixture(scope.active_project, scope.active_account)

      {:ok, updated} = Content.update_content(scope, content, %{slug: "updated-slug"})

      assert updated.slug == "updated-slug"
    end

    test "returns error with invalid attributes" do
      scope = full_scope_fixture()

      content = content_fixture(scope.active_project, scope.active_account)

      {:error, changeset} = Content.update_content(scope, content, %{slug: nil})

      assert changeset.errors[:slug]
    end
  end

  describe "delete_content/2" do
    test "deletes content" do
      scope = full_scope_fixture()

      content = content_fixture(scope.active_project, scope.active_account)

      {:ok, deleted} = Content.delete_content(scope, content)

      assert deleted.id == content.id

      assert_raise Ecto.NoResultsError, fn ->
        Content.get_content!(scope, content.id)
      end
    end
  end

  describe "delete_all_content/1" do
    test "deletes all content for scope" do
      scope = full_scope_fixture()

      _content1 = content_fixture(scope.active_project, scope.active_account)
      _content2 = content_fixture(scope.active_project, scope.active_account)

      {:ok, count} = Content.delete_all_content(scope)

      assert count == 2
      assert Content.list_all_content(scope) == []
    end

    test "only deletes content in scope" do
      scope1 = full_scope_fixture()
      scope2 = full_scope_fixture()

      _content1 = content_fixture(scope1.active_project, scope1.active_account)
      content2 = content_fixture(scope2.active_project, scope2.active_account)

      {:ok, _count} = Content.delete_all_content(scope1)

      assert Content.list_all_content(scope1) == []
      assert length(Content.list_all_content(scope2)) == 1
      assert List.first(Content.list_all_content(scope2)).id == content2.id
    end
  end

  describe "purge_expired_content/1" do
    test "deletes only expired content" do
      scope = full_scope_fixture()

      expired = expired_content_fixture(scope.active_project, scope.active_account)
      published = published_content_fixture(scope.active_project, scope.active_account)

      {:ok, count} = Content.purge_expired_content(scope)

      assert count == 1
      remaining = Content.list_all_content(scope)
      assert length(remaining) == 1
      assert List.first(remaining).id == published.id
      refute Enum.any?(remaining, &(&1.id == expired.id))
    end
  end

  describe "list_tags/1" do
    test "returns all tags for scope" do
      scope = full_scope_fixture()

      tag1 = tag_fixture(scope.active_project, scope.active_account, %{name: "tag1"})
      tag2 = tag_fixture(scope.active_project, scope.active_account, %{name: "tag2"})

      result = Content.list_tags(scope)

      assert length(result) == 2
      tag_ids = Enum.map(result, & &1.id)
      assert tag1.id in tag_ids
      assert tag2.id in tag_ids
    end
  end

  describe "upsert_tag/2" do
    test "creates new tag" do
      scope = full_scope_fixture()

      {:ok, tag} = Content.upsert_tag(scope, "newtag")

      assert tag.name == "newtag"
      assert tag.account_id == scope.active_account_id
      assert tag.project_id == scope.active_project_id
    end

    test "returns existing tag on duplicate" do
      scope = full_scope_fixture()

      {:ok, tag1} = Content.upsert_tag(scope, "duplicate")
      {:ok, tag2} = Content.upsert_tag(scope, "duplicate")

      assert tag1.id == tag2.id
    end
  end

  describe "get_content_tags/2" do
    test "returns tags associated with content" do
      scope = full_scope_fixture()

      content = content_fixture(scope.active_project, scope.active_account)
      _tag1 = tag_fixture(scope.active_project, scope.active_account, %{name: "tag1"})
      _tag2 = tag_fixture(scope.active_project, scope.active_account, %{name: "tag2"})

      {:ok, _} = Content.sync_content_tags(scope, content, ["tag1", "tag2"])

      result = Content.get_content_tags(scope, content)

      assert length(result) == 2
      tag_names = Enum.map(result, & &1.name)
      assert "tag1" in tag_names
      assert "tag2" in tag_names
    end
  end

  describe "sync_content_tags/3" do
    test "associates tags with content" do
      scope = full_scope_fixture()

      content = content_fixture(scope.active_project, scope.active_account)

      {:ok, updated} = Content.sync_content_tags(scope, content, ["elixir", "phoenix"])

      tags = Content.get_content_tags(scope, updated)
      assert length(tags) == 2
      tag_names = Enum.map(tags, & &1.name)
      assert "elixir" in tag_names
      assert "phoenix" in tag_names
    end

    test "removes old tags and adds new tags" do
      scope = full_scope_fixture()

      content = content_fixture(scope.active_project, scope.active_account)

      {:ok, _} = Content.sync_content_tags(scope, content, ["old-tag"])
      {:ok, updated} = Content.sync_content_tags(scope, content, ["new-tag"])

      tags = Content.get_content_tags(scope, updated)
      assert length(tags) == 1
      assert List.first(tags).name == "new-tag"
    end

    test "removes all tags when empty list provided" do
      scope = full_scope_fixture()

      content = content_fixture(scope.active_project, scope.active_account)

      {:ok, _} = Content.sync_content_tags(scope, content, ["tag1", "tag2"])
      {:ok, updated} = Content.sync_content_tags(scope, content, [])

      tags = Content.get_content_tags(scope, updated)
      assert tags == []
    end
  end

  describe "list_content_with_status/2" do
    test "filters content by parse_status" do
      scope = full_scope_fixture()

      success = content_fixture(scope.active_project, scope.active_account, %{parse_status: "success"})
      _failed = failed_content_fixture(scope.active_project, scope.active_account)

      result = Content.list_content_with_status(scope, %{parse_status: "success"})

      assert length(result) == 1
      assert List.first(result).id == success.id
    end

    test "filters content by content_type" do
      scope = full_scope_fixture()

      blog = published_content_fixture(scope.active_project, scope.active_account, %{content_type: "blog"})
      _page = published_content_fixture(scope.active_project, scope.active_account, %{content_type: "page"})

      result = Content.list_content_with_status(scope, %{content_type: "blog"})

      assert length(result) == 1
      assert List.first(result).id == blog.id
    end
  end

  describe "count_by_parse_status/1" do
    test "returns count of success and error statuses" do
      scope = full_scope_fixture()

      _success1 = content_fixture(scope.active_project, scope.active_account, %{parse_status: "success"})
      _success2 = content_fixture(scope.active_project, scope.active_account, %{parse_status: "success"})
      _failed = failed_content_fixture(scope.active_project, scope.active_account)

      result = Content.count_by_parse_status(scope)

      assert result.success == 2
      assert result.error == 1
    end
  end
end

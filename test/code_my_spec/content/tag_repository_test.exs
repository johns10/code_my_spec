defmodule CodeMySpec.Content.TagRepositoryTest do
  use CodeMySpec.DataCase, async: true

  import CodeMySpec.UsersFixtures

  alias CodeMySpec.Content.{TagRepository, Tag}
  alias CodeMySpec.Repo

  describe "upsert_tag/2" do
    test "creates new tag with normalized name and slug" do
      scope = full_scope_fixture()

      assert {:ok, tag} = TagRepository.upsert_tag(scope, "New Tag")

      assert tag.name == "new tag"
      assert tag.slug == "new-tag"
      assert tag.account_id == scope.active_account_id
      assert tag.project_id == scope.active_project_id

      persisted = Repo.get!(Tag, tag.id)
      assert persisted.name == "new tag"
      assert persisted.slug == "new-tag"
    end

    test "normalizes uppercase names to lowercase" do
      scope = full_scope_fixture()

      assert {:ok, tag} = TagRepository.upsert_tag(scope, "UPPERCASE TAG")

      assert tag.name == "uppercase tag"
      assert tag.slug == "uppercase-tag"
    end

    test "normalizes mixed case names to lowercase" do
      scope = full_scope_fixture()

      assert {:ok, tag} = TagRepository.upsert_tag(scope, "MiXeD CaSe TaG")

      assert tag.name == "mixed case tag"
      assert tag.slug == "mixed-case-tag"
    end

    test "generates URL-safe slug from special characters" do
      scope = full_scope_fixture()

      assert {:ok, tag} = TagRepository.upsert_tag(scope, "Tag with Special-Chars & Symbols!")

      assert tag.name == "tag with special-chars & symbols!"
      assert tag.slug == "tag-with-special-chars-symbols"
    end

    test "returns existing tag when slug already exists in scope" do
      scope = full_scope_fixture()

      {:ok, original_tag} = TagRepository.upsert_tag(scope, "Existing Tag")
      {:ok, returned_tag} = TagRepository.upsert_tag(scope, "Existing Tag")

      assert returned_tag.id == original_tag.id
      assert returned_tag.name == original_tag.name
      assert returned_tag.slug == original_tag.slug
    end

    test "returns existing tag when different case matches existing slug" do
      scope = full_scope_fixture()

      {:ok, original_tag} = TagRepository.upsert_tag(scope, "duplicate")
      {:ok, returned_tag} = TagRepository.upsert_tag(scope, "DUPLICATE")

      assert returned_tag.id == original_tag.id
      assert returned_tag.name == "duplicate"
    end

    test "allows same tag name in different projects" do
      scope1 = full_scope_fixture()
      scope2 = full_scope_fixture()

      {:ok, tag1} = TagRepository.upsert_tag(scope1, "Shared Tag")
      {:ok, tag2} = TagRepository.upsert_tag(scope2, "Shared Tag")

      assert tag1.id != tag2.id
      assert tag1.name == tag2.name
      assert tag1.slug == tag2.slug
      assert tag1.project_id != tag2.project_id
    end

    test "allows same tag name in different accounts" do
      scope1 = full_scope_fixture()
      scope2 = full_scope_fixture()

      {:ok, tag1} = TagRepository.upsert_tag(scope1, "Shared Tag")
      {:ok, tag2} = TagRepository.upsert_tag(scope2, "Shared Tag")

      assert tag1.id != tag2.id
      assert tag1.account_id != tag2.account_id
    end

    test "returns error for invalid tag name" do
      scope = full_scope_fixture()

      assert {:error, changeset} = TagRepository.upsert_tag(scope, "")
      assert "can't be blank" in errors_on(changeset).name
    end

    test "returns error for tag name exceeding max length" do
      scope = full_scope_fixture()
      long_name = String.duplicate("a", 51)

      assert {:error, changeset} = TagRepository.upsert_tag(scope, long_name)
      assert "should be at most 50 character(s)" in errors_on(changeset).name
    end

    test "handles tag name at max length boundary" do
      scope = full_scope_fixture()
      max_length_name = String.duplicate("a", 50)

      assert {:ok, tag} = TagRepository.upsert_tag(scope, max_length_name)
      assert String.length(tag.name) == 50
    end
  end

  describe "list_tags/1" do
    test "returns all tags in scope ordered alphabetically" do
      scope = full_scope_fixture()

      {:ok, tag_c} = TagRepository.upsert_tag(scope, "charlie")
      {:ok, tag_a} = TagRepository.upsert_tag(scope, "alpha")
      {:ok, tag_b} = TagRepository.upsert_tag(scope, "bravo")

      tags = TagRepository.list_tags(scope)

      assert length(tags) == 3
      assert Enum.map(tags, & &1.name) == ["alpha", "bravo", "charlie"]
      assert Enum.map(tags, & &1.id) == [tag_a.id, tag_b.id, tag_c.id]
    end

    test "returns empty list when no tags exist in scope" do
      scope = full_scope_fixture()

      tags = TagRepository.list_tags(scope)

      assert tags == []
    end

    test "only returns tags from scoped project" do
      scope1 = full_scope_fixture()
      scope2 = full_scope_fixture()

      {:ok, tag1} = TagRepository.upsert_tag(scope1, "Tag One")
      {:ok, _tag2} = TagRepository.upsert_tag(scope2, "Tag Two")

      tags = TagRepository.list_tags(scope1)

      assert length(tags) == 1
      assert List.first(tags).id == tag1.id
    end

    test "only returns tags from scoped account" do
      scope1 = full_scope_fixture()
      scope2 = full_scope_fixture()

      {:ok, _tag1} = TagRepository.upsert_tag(scope1, "Tag One")
      {:ok, _tag2} = TagRepository.upsert_tag(scope2, "Tag Two")

      tags = TagRepository.list_tags(scope1)

      assert length(tags) == 1
      assert List.first(tags).account_id == scope1.active_account_id
    end

    test "returns tags with correct multi-tenant isolation" do
      scope1 = full_scope_fixture()
      scope2 = full_scope_fixture()

      {:ok, _tag1} = TagRepository.upsert_tag(scope1, "Isolated One")
      {:ok, _tag2} = TagRepository.upsert_tag(scope1, "Isolated Two")
      {:ok, _tag3} = TagRepository.upsert_tag(scope2, "Isolated Three")

      tags_scope1 = TagRepository.list_tags(scope1)
      tags_scope2 = TagRepository.list_tags(scope2)

      assert length(tags_scope1) == 2
      assert length(tags_scope2) == 1

      assert Enum.all?(tags_scope1, &(&1.account_id == scope1.active_account_id))
      assert Enum.all?(tags_scope1, &(&1.project_id == scope1.active_project_id))
    end
  end

  describe "get_tag_by_slug/2" do
    test "returns tag when slug exists in scope" do
      scope = full_scope_fixture()

      {:ok, created_tag} = TagRepository.upsert_tag(scope, "Test Tag")

      tag = TagRepository.get_tag_by_slug(scope, "test-tag")

      assert tag.id == created_tag.id
      assert tag.name == "test tag"
      assert tag.slug == "test-tag"
    end

    test "returns nil when slug does not exist in scope" do
      scope = full_scope_fixture()

      tag = TagRepository.get_tag_by_slug(scope, "nonexistent")

      assert tag == nil
    end

    test "returns nil when slug exists in different project" do
      scope1 = full_scope_fixture()
      scope2 = full_scope_fixture()

      {:ok, _tag} = TagRepository.upsert_tag(scope1, "Project Tag")

      tag = TagRepository.get_tag_by_slug(scope2, "project-tag")

      assert tag == nil
    end

    test "returns nil when slug exists in different account" do
      scope1 = full_scope_fixture()
      scope2 = full_scope_fixture()

      {:ok, _tag} = TagRepository.upsert_tag(scope1, "Account Tag")

      tag = TagRepository.get_tag_by_slug(scope2, "account-tag")

      assert tag == nil
    end

    test "enforces multi-tenant isolation" do
      scope1 = full_scope_fixture()
      scope2 = full_scope_fixture()

      {:ok, tag1} = TagRepository.upsert_tag(scope1, "Shared Name")
      {:ok, tag2} = TagRepository.upsert_tag(scope2, "Shared Name")

      result1 = TagRepository.get_tag_by_slug(scope1, "shared-name")
      result2 = TagRepository.get_tag_by_slug(scope2, "shared-name")

      assert result1.id == tag1.id
      assert result2.id == tag2.id
      assert result1.id != result2.id
    end
  end

  describe "get_tag_by_slug!/2" do
    test "returns tag when slug exists in scope" do
      scope = full_scope_fixture()

      {:ok, created_tag} = TagRepository.upsert_tag(scope, "Test Tag")

      tag = TagRepository.get_tag_by_slug!(scope, "test-tag")

      assert tag.id == created_tag.id
      assert tag.name == "test tag"
    end

    test "raises Ecto.NoResultsError when slug does not exist" do
      scope = full_scope_fixture()

      assert_raise Ecto.NoResultsError, fn ->
        TagRepository.get_tag_by_slug!(scope, "nonexistent")
      end
    end

    test "raises Ecto.NoResultsError when slug exists in different project" do
      scope1 = full_scope_fixture()
      scope2 = full_scope_fixture()

      {:ok, _tag} = TagRepository.upsert_tag(scope1, "Project Tag")

      assert_raise Ecto.NoResultsError, fn ->
        TagRepository.get_tag_by_slug!(scope2, "project-tag")
      end
    end

    test "raises Ecto.NoResultsError when slug exists in different account" do
      scope1 = full_scope_fixture()
      scope2 = full_scope_fixture()

      {:ok, _tag} = TagRepository.upsert_tag(scope1, "Account Tag")

      assert_raise Ecto.NoResultsError, fn ->
        TagRepository.get_tag_by_slug!(scope2, "account-tag")
      end
    end
  end

  describe "by_account_and_project/2" do
    test "filters query by account and project from scope" do
      scope = full_scope_fixture()

      {:ok, tag1} = TagRepository.upsert_tag(scope, "Scoped Tag")

      other_scope = full_scope_fixture()
      {:ok, _tag2} = TagRepository.upsert_tag(other_scope, "Other Tag")

      query = Tag |> TagRepository.by_account_and_project(scope)
      results = Repo.all(query)

      assert length(results) == 1
      assert List.first(results).id == tag1.id
    end

    test "returns empty result when no tags match scope" do
      scope = full_scope_fixture()
      other_scope = full_scope_fixture()

      {:ok, _tag} = TagRepository.upsert_tag(other_scope, "Other Tag")

      query = Tag |> TagRepository.by_account_and_project(scope)
      results = Repo.all(query)

      assert results == []
    end

    test "can be composed with other query functions" do
      scope = full_scope_fixture()

      {:ok, tag1} = TagRepository.upsert_tag(scope, "Alpha")
      {:ok, _tag2} = TagRepository.upsert_tag(scope, "Bravo")

      query =
        Tag
        |> TagRepository.by_account_and_project(scope)
        |> TagRepository.by_slug("alpha")

      results = Repo.all(query)

      assert length(results) == 1
      assert List.first(results).id == tag1.id
    end
  end

  describe "by_slug/2" do
    test "filters query by slug" do
      scope = full_scope_fixture()

      {:ok, tag1} = TagRepository.upsert_tag(scope, "Target Tag")
      {:ok, _tag2} = TagRepository.upsert_tag(scope, "Other Tag")

      query = Tag |> TagRepository.by_slug("target-tag")
      results = Repo.all(query)

      assert length(results) == 1
      assert List.first(results).id == tag1.id
    end

    test "returns empty result when slug does not exist" do
      scope = full_scope_fixture()

      {:ok, _tag} = TagRepository.upsert_tag(scope, "Existing Tag")

      query = Tag |> TagRepository.by_slug("nonexistent")
      results = Repo.all(query)

      assert results == []
    end

    test "can be composed with scope query functions" do
      scope = full_scope_fixture()
      other_scope = full_scope_fixture()

      {:ok, tag1} = TagRepository.upsert_tag(scope, "Shared")
      {:ok, tag2} = TagRepository.upsert_tag(other_scope, "Shared")

      query =
        Tag
        |> TagRepository.by_slug("shared")
        |> TagRepository.by_account_and_project(scope)

      results = Repo.all(query)

      assert length(results) == 1
      assert List.first(results).id == tag1.id
      refute List.first(results).id == tag2.id
    end
  end
end

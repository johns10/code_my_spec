defmodule CodeMySpec.Stories.StoriesRepositoryTest do
  use CodeMySpec.DataCase

  alias CodeMySpec.Stories.StoriesRepository

  describe "stories" do
    alias CodeMySpec.Stories.Story

    import CodeMySpec.UsersFixtures, only: [user_fixture: 0, user_scope_fixture: 2]
    import CodeMySpec.AccountsFixtures, only: [account_with_owner_fixture: 1]
    import CodeMySpec.StoriesFixtures

    @invalid_attrs %{
      priority: nil,
      status: nil,
      description: nil,
      title: nil,
      acceptance_criteria: nil,
      locked_at: nil,
      lock_expires_at: nil
    }

    test "list_stories/1 returns all scoped stories" do
      user = user_fixture()
      other_user = user_fixture()
      account = account_with_owner_fixture(user)
      other_account = account_with_owner_fixture(other_user)
      scope = user_scope_fixture(user, account)
      other_scope = user_scope_fixture(other_user, other_account)
      story = story_fixture(scope)
      other_story = story_fixture(other_scope)
      assert StoriesRepository.list_stories(scope) == [story]
      assert StoriesRepository.list_stories(other_scope) == [other_story]
    end

    test "get_story!/2 returns the story with given id" do
      user = user_fixture()
      other_user = user_fixture()
      account = account_with_owner_fixture(user)
      other_account = account_with_owner_fixture(other_user)
      scope = user_scope_fixture(user, account)
      other_scope = user_scope_fixture(other_user, other_account)
      story = story_fixture(scope)
      assert StoriesRepository.get_story!(scope, story.id) == story

      assert_raise Ecto.NoResultsError, fn ->
        StoriesRepository.get_story!(other_scope, story.id)
      end
    end

    test "create_story/2 with valid data creates a story" do
      valid_attrs = %{
        priority: 42,
        status: :in_progress,
        description: "some description",
        title: "some title",
        acceptance_criteria: ["option1", "option2"],
        locked_at: ~U[2025-07-17 12:48:00Z],
        lock_expires_at: ~U[2025-07-17 12:48:00Z]
      }

      user = user_fixture()
      account = account_with_owner_fixture(user)
      scope = user_scope_fixture(user, account)

      assert {:ok, %Story{} = story} = StoriesRepository.create_story(scope, valid_attrs)
      assert story.priority == 42
      assert story.status == :in_progress
      assert story.description == "some description"
      assert story.title == "some title"
      assert story.acceptance_criteria == ["option1", "option2"]
      assert story.locked_at == ~U[2025-07-17 12:48:00Z]
      assert story.lock_expires_at == ~U[2025-07-17 12:48:00Z]
      assert story.account_id == scope.active_account.id
    end

    test "create_story/2 with invalid data returns error changeset" do
      user = user_fixture()
      account = account_with_owner_fixture(user)
      scope = user_scope_fixture(user, account)
      assert {:error, %Ecto.Changeset{}} = StoriesRepository.create_story(scope, @invalid_attrs)
    end

    test "update_story/3 with valid data updates the story" do
      user = user_fixture()
      account = account_with_owner_fixture(user)
      scope = user_scope_fixture(user, account)
      story = story_fixture(scope)

      update_attrs = %{
        priority: 43,
        status: :completed,
        description: "some updated description",
        title: "some updated title",
        acceptance_criteria: ["option1"],
        locked_at: ~U[2025-07-18 12:48:00Z],
        lock_expires_at: ~U[2025-07-18 12:48:00Z]
      }

      assert {:ok, %Story{} = story} = StoriesRepository.update_story(scope, story, update_attrs)
      assert story.priority == 43
      assert story.status == :completed
      assert story.description == "some updated description"
      assert story.title == "some updated title"
      assert story.acceptance_criteria == ["option1"]
      assert story.locked_at == ~U[2025-07-18 12:48:00Z]
      assert story.lock_expires_at == ~U[2025-07-18 12:48:00Z]
    end

    test "update_story/3 with invalid data returns error changeset" do
      user = user_fixture()
      account = account_with_owner_fixture(user)
      scope = user_scope_fixture(user, account)
      story = story_fixture(scope)

      assert {:error, %Ecto.Changeset{}} =
               StoriesRepository.update_story(scope, story, @invalid_attrs)

      assert story == StoriesRepository.get_story!(scope, story.id)
    end

    test "delete_story/2 deletes the story" do
      user = user_fixture()
      account = account_with_owner_fixture(user)
      scope = user_scope_fixture(user, account)
      story = story_fixture(scope)
      assert {:ok, %Story{}} = StoriesRepository.delete_story(scope, story)
      assert_raise Ecto.NoResultsError, fn -> StoriesRepository.get_story!(scope, story.id) end
    end
  end

  describe "query functions" do
    alias CodeMySpec.Stories.Story

    import CodeMySpec.UsersFixtures, only: [user_fixture: 0, user_scope_fixture: 2]
    import CodeMySpec.AccountsFixtures, only: [account_with_owner_fixture: 1]
    import CodeMySpec.StoriesFixtures
    import CodeMySpec.ProjectsFixtures
    import Ecto.Query

    test "by_project/2 filters stories by project" do
      user = user_fixture()
      account = account_with_owner_fixture(user)
      scope = user_scope_fixture(user, account)
      project = project_fixture(scope)
      other_project = project_fixture(scope)

      story1 = story_fixture(scope, %{project_id: project.id})
      _story2 = story_fixture(scope, %{project_id: other_project.id})

      results =
        Story
        |> StoriesRepository.by_project(project.id)
        |> Repo.all()

      assert length(results) == 1
      assert Enum.any?(results, fn s -> s.id == story1.id end)
    end

    test "by_status/2 filters stories by status" do
      user = user_fixture()
      account = account_with_owner_fixture(user)
      scope = user_scope_fixture(user, account)

      story1 = story_fixture(scope, %{status: :in_progress})
      _story2 = story_fixture(scope, %{status: :completed})

      results =
        StoriesRepository.by_status(:in_progress)
        |> where([s], s.account_id == ^scope.active_account.id)
        |> Repo.all()

      assert length(results) == 1
      assert hd(results).id == story1.id
    end

    test "by_priority/2 filters stories by minimum priority" do
      user = user_fixture()
      account = account_with_owner_fixture(user)
      scope = user_scope_fixture(user, account)

      _story1 = story_fixture(scope, %{priority: 10})
      _story2 = story_fixture(scope, %{priority: 50})
      _story3 = story_fixture(scope, %{priority: 100})

      results =
        StoriesRepository.by_priority(50)
        |> where([s], s.account_id == ^scope.active_account.id)
        |> Repo.all()

      assert length(results) == 2
      assert Enum.all?(results, fn s -> s.priority >= 50 end)
    end

    test "search_text/2 searches title and description" do
      user = user_fixture()
      account = account_with_owner_fixture(user)
      scope = user_scope_fixture(user, account)

      story1 = story_fixture(scope, %{title: "User Login Feature"})
      story2 = story_fixture(scope, %{description: "Feature for user authentication"})
      _story3 = story_fixture(scope, %{title: "Bug Fix", description: "Fix payment issues"})

      results =
        StoriesRepository.search_text("Feature")
        |> where([s], s.account_id == ^scope.active_account.id)
        |> Repo.all()

      assert length(results) == 2
      assert Enum.any?(results, fn s -> s.id == story1.id end)
      assert Enum.any?(results, fn s -> s.id == story2.id end)
    end

    test "locked_by/2 filters stories by lock owner" do
      user = user_fixture()
      other_user = user_fixture()
      account = account_with_owner_fixture(user)
      scope = user_scope_fixture(user, account)

      story1 = story_fixture(scope, %{locked_by: user.id})
      _story2 = story_fixture(scope, %{locked_by: other_user.id})

      results =
        StoriesRepository.locked_by(user.id)
        |> where([s], s.account_id == ^scope.active_account.id)
        |> Repo.all()

      assert length(results) == 1
      assert hd(results).id == story1.id
    end

    test "lock_expired/1 filters expired locks" do
      user = user_fixture()
      account = account_with_owner_fixture(user)
      scope = user_scope_fixture(user, account)

      past_time = DateTime.utc_now() |> DateTime.add(-1, :hour)
      future_time = DateTime.utc_now() |> DateTime.add(1, :hour)

      story1 = story_fixture(scope, %{locked_by: user.id, lock_expires_at: past_time})
      _story2 = story_fixture(scope, %{locked_by: user.id, lock_expires_at: future_time})

      results =
        StoriesRepository.lock_expired()
        |> where([s], s.account_id == ^scope.active_account.id)
        |> Repo.all()

      assert length(results) == 1
      assert hd(results).id == story1.id
    end

    test "ordered_by_priority/1 orders by priority desc then inserted_at asc" do
      user = user_fixture()
      account = account_with_owner_fixture(user)
      scope = user_scope_fixture(user, account)

      _story1 = story_fixture(scope, %{priority: 10})
      _story2 = story_fixture(scope, %{priority: 50})
      _story3 = story_fixture(scope, %{priority: 50})

      results =
        StoriesRepository.ordered_by_priority()
        |> where([s], s.account_id == ^scope.active_account.id)
        |> Repo.all()

      assert length(results) == 3
      assert Enum.at(results, 0).priority == 50
      assert Enum.at(results, 1).priority == 50
      assert Enum.at(results, 2).priority == 10
    end

    test "ordered_by_status/1 orders by status asc then inserted_at asc" do
      user = user_fixture()
      account = account_with_owner_fixture(user)
      scope = user_scope_fixture(user, account)

      _story1 = story_fixture(scope, %{status: :completed})
      _story2 = story_fixture(scope, %{status: :in_progress})
      _story3 = story_fixture(scope, %{status: :dirty})

      results =
        StoriesRepository.ordered_by_status()
        |> where([s], s.account_id == ^scope.active_account.id)
        |> Repo.all()

      assert length(results) == 3
      assert Enum.at(results, 0).status == :completed
      assert Enum.at(results, 1).status == :dirty
      assert Enum.at(results, 2).status == :in_progress
    end

    test "paginate/3 limits and offsets results" do
      user = user_fixture()
      account = account_with_owner_fixture(user)
      scope = user_scope_fixture(user, account)

      for _ <- 1..10 do
        story_fixture(scope)
      end

      page1 =
        Story
        |> StoriesRepository.paginate(1, 3)
        |> where([s], s.account_id == ^scope.active_account.id)
        |> Repo.all()

      page2 =
        Story
        |> StoriesRepository.paginate(2, 3)
        |> where([s], s.account_id == ^scope.active_account.id)
        |> Repo.all()

      assert length(page1) == 3
      assert length(page2) == 3
      assert page1 != page2
    end

    test "with_preloads/2 preloads associations" do
      user = user_fixture()
      account = account_with_owner_fixture(user)
      scope = user_scope_fixture(user, account)
      project = project_fixture(scope)

      _story = story_fixture(scope, %{project_id: project.id})

      [result] =
        Story
        |> where([s], s.account_id == ^scope.active_account.id)
        |> StoriesRepository.with_preloads([:first_version])
        |> Repo.all()

      assert not is_nil(result.first_version)
    end
  end

  describe "lock management" do
    import CodeMySpec.UsersFixtures, only: [user_fixture: 0, user_scope_fixture: 2]
    import CodeMySpec.AccountsFixtures, only: [account_with_owner_fixture: 1]
    import CodeMySpec.StoriesFixtures

    test "acquire_lock/3 successfully locks unlocked story" do
      user = user_fixture()
      account = account_with_owner_fixture(user)
      scope = user_scope_fixture(user, account)
      story = story_fixture(scope)

      assert {:ok, locked_story} = StoriesRepository.acquire_lock(scope, story, 30)
      assert locked_story.locked_by == user.id
      assert not is_nil(locked_story.locked_at)
      assert not is_nil(locked_story.lock_expires_at)
      assert StoriesRepository.is_locked?(locked_story)
    end

    test "acquire_lock/3 fails when story already locked" do
      user = user_fixture()
      other_user = user_fixture()
      account = account_with_owner_fixture(user)
      scope = user_scope_fixture(user, account)
      other_scope = user_scope_fixture(other_user, account)

      story = story_fixture(scope)
      {:ok, locked_story} = StoriesRepository.acquire_lock(scope, story, 30)

      assert {:error, :already_locked} =
               StoriesRepository.acquire_lock(other_scope, locked_story, 30)
    end

    test "release_lock/2 successfully releases lock" do
      user = user_fixture()
      account = account_with_owner_fixture(user)
      scope = user_scope_fixture(user, account)
      story = story_fixture(scope)

      {:ok, locked_story} = StoriesRepository.acquire_lock(scope, story, 30)
      assert StoriesRepository.is_locked?(locked_story)

      assert {:ok, released_story} = StoriesRepository.release_lock(scope, locked_story)
      assert is_nil(released_story.locked_by)
      assert is_nil(released_story.locked_at)
      assert is_nil(released_story.lock_expires_at)
      refute StoriesRepository.is_locked?(released_story)
    end

    test "extend_lock/3 successfully extends lock for owner" do
      user = user_fixture()
      account = account_with_owner_fixture(user)
      scope = user_scope_fixture(user, account)
      story = story_fixture(scope)

      {:ok, locked_story} = StoriesRepository.acquire_lock(scope, story, 30)
      original_expires_at = locked_story.lock_expires_at

      assert {:ok, extended_story} = StoriesRepository.extend_lock(scope, locked_story, 60)
      assert DateTime.compare(extended_story.lock_expires_at, original_expires_at) == :gt
    end

    test "extend_lock/3 fails when not lock owner" do
      user = user_fixture()
      other_user = user_fixture()
      account = account_with_owner_fixture(user)
      scope = user_scope_fixture(user, account)
      other_scope = user_scope_fixture(other_user, account)

      story = story_fixture(scope)
      {:ok, locked_story} = StoriesRepository.acquire_lock(scope, story, 30)

      assert {:error, :not_lock_owner} =
               StoriesRepository.extend_lock(other_scope, locked_story, 60)
    end

    test "is_locked?/1 returns true for valid lock" do
      user = user_fixture()
      account = account_with_owner_fixture(user)
      scope = user_scope_fixture(user, account)
      story = story_fixture(scope)

      refute StoriesRepository.is_locked?(story)
      {:ok, locked_story} = StoriesRepository.acquire_lock(scope, story, 30)
      assert StoriesRepository.is_locked?(locked_story)
    end

    test "is_locked?/1 returns false for expired lock" do
      user = user_fixture()
      account = account_with_owner_fixture(user)
      scope = user_scope_fixture(user, account)

      past_time = DateTime.utc_now() |> DateTime.add(-1, :hour)

      story =
        story_fixture(scope, %{
          locked_by: user.id,
          locked_at: past_time,
          lock_expires_at: past_time
        })

      refute StoriesRepository.is_locked?(story)
    end

    test "lock_owner/1 returns lock owner user id" do
      user = user_fixture()
      account = account_with_owner_fixture(user)
      scope = user_scope_fixture(user, account)
      story = story_fixture(scope)

      assert is_nil(StoriesRepository.lock_owner(story))
      {:ok, locked_story} = StoriesRepository.acquire_lock(scope, story, 30)
      assert StoriesRepository.lock_owner(locked_story) == user.id
    end
  end
end

defmodule CodeMySpec.StoriesTest do
  use CodeMySpec.DataCase

  alias CodeMySpec.Stories

  describe "stories" do
    import CodeMySpec.UsersFixtures, only: [user_fixture: 0, user_scope_fixture: 2]
    import CodeMySpec.AccountsFixtures, only: [account_with_owner_fixture: 1]
    import CodeMySpec.StoriesFixtures

    test "update_story/3 with invalid scope raises" do
      user = user_fixture()
      other_user = user_fixture()
      account = account_with_owner_fixture(user)
      other_account = account_with_owner_fixture(other_user)
      scope = user_scope_fixture(user, account)
      other_scope = user_scope_fixture(other_user, other_account)
      story = story_fixture(scope)

      assert_raise MatchError, fn ->
        Stories.update_story(other_scope, story, %{})
      end
    end

    test "delete_story/2 with invalid scope raises" do
      user = user_fixture()
      other_user = user_fixture()
      account = account_with_owner_fixture(user)
      other_account = account_with_owner_fixture(other_user)
      scope = user_scope_fixture(user, account)
      other_scope = user_scope_fixture(other_user, other_account)
      story = story_fixture(scope)
      assert_raise MatchError, fn -> Stories.delete_story(other_scope, story) end
    end

    test "change_story/2 returns a story changeset" do
      user = user_fixture()
      account = account_with_owner_fixture(user)
      scope = user_scope_fixture(user, account)
      story = story_fixture(scope)
      assert %Ecto.Changeset{} = Stories.change_story(scope, story)
    end
  end
end

defmodule CodeMySpec.StoriesTest do
  use CodeMySpec.DataCase

  alias CodeMySpec.Stories

  describe "stories" do
    import CodeMySpec.UsersFixtures
    import CodeMySpec.StoriesFixtures
    import CodeMySpec.ComponentsFixtures

    test "update_story/3 with invalid scope raises" do
      scope = full_scope_fixture()
      other_scope = full_scope_fixture()
      story = story_fixture(scope)

      assert_raise MatchError, fn ->
        Stories.update_story(other_scope, story, %{})
      end
    end

    test "delete_story/2 with invalid scope raises" do
      scope = full_scope_fixture()
      other_scope = full_scope_fixture()
      story = story_fixture(scope)
      assert_raise MatchError, fn -> Stories.delete_story(other_scope, story) end
    end

    test "change_story/2 returns a story changeset" do
      scope = full_scope_fixture()
      story = story_fixture(scope)
      assert %Ecto.Changeset{} = Stories.change_story(scope, story)
    end

    test "set_story_component/3 updates story with component" do
      scope = full_scope_fixture()
      story = story_fixture(scope)
      component = component_fixture(scope)

      assert {:ok, updated_story} = Stories.set_story_component(scope, story, component.id)
      assert updated_story.component_id == component.id
    end

    test "clear_story_component/2 removes component from story" do
      scope = full_scope_fixture()
      component = component_fixture(scope)
      story = story_fixture(scope, %{component_id: component.id})

      assert {:ok, updated_story} = Stories.clear_story_component(scope, story)
      assert is_nil(updated_story.component_id)
    end

    test "set_story_component/3 with invalid scope raises" do
      scope = full_scope_fixture()
      other_scope = full_scope_fixture()
      story = story_fixture(scope)
      component = component_fixture(scope)

      assert_raise MatchError, fn ->
        Stories.set_story_component(other_scope, story, component.id)
      end
    end

    test "clear_story_component/2 with invalid scope raises" do
      scope = full_scope_fixture()
      other_scope = full_scope_fixture()
      component = component_fixture(scope)
      story = story_fixture(scope, %{component_id: component.id})

      assert_raise MatchError, fn ->
        Stories.clear_story_component(other_scope, story)
      end
    end
  end
end

defmodule CodeMySpecWeb.StoryLiveTest do
  use CodeMySpecWeb.ConnCase

  import Phoenix.LiveViewTest
  import CodeMySpec.StoriesFixtures

  @create_attrs %{
    status: :in_progress,
    description: "some description",
    title: "some title"
  }
  @update_attrs %{
    status: :completed,
    description: "some updated description",
    title: "some updated title"
  }
  @invalid_attrs %{
    status: nil,
    description: nil,
    title: nil
  }

  setup [:register_log_in_setup_account, :setup_active_account, :setup_active_project]

  defp create_story(%{scope: scope}) do
    story = story_fixture(scope)

    %{story: story}
  end

  describe "Index" do
    setup [:create_story]

    test "lists all stories", %{conn: conn, story: story} do
      {:ok, _index_live, html} = live(conn, ~p"/stories")

      assert html =~ "Listing Stories"
      assert html =~ story.title
    end

    test "saves new story", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/stories")

      assert {:ok, form_live, _} =
               index_live
               |> element("a", "New Story")
               |> render_click()
               |> follow_redirect(conn, ~p"/stories/new")

      assert render(form_live) =~ "New Story"

      assert form_live
             |> form("#story-form", story: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, index_live, _html} =
               form_live
               |> form("#story-form", story: @create_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/stories")

      html = render(index_live)
      assert html =~ "Story created successfully"
      assert html =~ "some title"
    end

    test "updates story in listing", %{conn: conn, story: story} do
      {:ok, index_live, _html} = live(conn, ~p"/stories")

      assert {:ok, form_live, _html} =
               index_live
               |> element("#stories-#{story.id} a", "Edit")
               |> render_click()
               |> follow_redirect(conn, ~p"/stories/#{story}/edit")

      assert render(form_live) =~ "Edit Story"

      assert form_live
             |> form("#story-form", story: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, index_live, _html} =
               form_live
               |> form("#story-form", story: @update_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/stories")

      html = render(index_live)
      assert html =~ "Story updated successfully"
      assert html =~ "some updated title"
    end

    test "deletes story in listing", %{conn: conn, story: story} do
      {:ok, index_live, _html} = live(conn, ~p"/stories")

      assert index_live |> element("#stories-#{story.id} a", "Delete") |> render_click()
      refute has_element?(index_live, "#stories-#{story.id}")
    end
  end

  describe "Show" do
    setup [:create_story]

    test "displays story", %{conn: conn, story: story} do
      {:ok, _show_live, html} = live(conn, ~p"/stories/#{story}")

      assert html =~ "Show Story"
      assert html =~ story.title
    end

    test "updates story and returns to show", %{conn: conn, story: story} do
      {:ok, show_live, _html} = live(conn, ~p"/stories/#{story}")

      assert {:ok, form_live, _} =
               show_live
               |> element("a", "Edit")
               |> render_click()
               |> follow_redirect(conn, ~p"/stories/#{story}/edit?return_to=show")

      assert render(form_live) =~ "Edit Story"

      assert form_live
             |> form("#story-form", story: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, show_live, _html} =
               form_live
               |> form("#story-form", story: @update_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/stories/#{story}")

      html = render(show_live)
      assert html =~ "Story updated successfully"
      assert html =~ "some updated title"
    end
  end
end

defmodule CodeMySpec.McpServers.Stories.Tools.ListStoriesTest do
  use ExUnit.Case, async: true
  import CodeMySpec.UsersFixtures
  import CodeMySpec.StoriesFixtures

  alias CodeMySpec.McpServers.Stories.Tools.ListStories
  alias Hermes.Server.Frame
  alias Hermes.Server.Response

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(CodeMySpec.Repo)
  end

  describe "ListStories tool" do
    test "returns paginated results with default limit" do
      scope = full_scope_fixture()
      # Create 25 stories to test pagination
      for i <- 1..25, do: story_fixture(scope, %{title: "Story #{i}"})

      frame = %Frame{assigns: %{current_scope: scope}}

      assert {:reply, response, ^frame} = ListStories.execute(%{}, frame)
      assert response.type == :tool

      # Check response contains pagination info
      protocol = Response.to_protocol(response)
      content = hd(protocol["content"])["text"]

      assert content =~ "Showing 1-20 of 25 stories"
      assert content =~ "Use offset: 20 to see more"
      assert content =~ "Data:"
    end

    test "respects limit parameter" do
      scope = full_scope_fixture()
      for i <- 1..10, do: story_fixture(scope, %{title: "Story #{i}"})

      frame = %Frame{assigns: %{current_scope: scope}}

      assert {:reply, response, ^frame} = ListStories.execute(%{limit: 3}, frame)

      protocol = Response.to_protocol(response)
      content = hd(protocol["content"])["text"]

      assert content =~ "Showing 1-3 of 10 stories"
    end

    test "respects offset parameter" do
      scope = full_scope_fixture()
      for i <- 1..10, do: story_fixture(scope, %{title: "Story #{i}"})

      frame = %Frame{assigns: %{current_scope: scope}}

      assert {:reply, response, ^frame} = ListStories.execute(%{limit: 3, offset: 5}, frame)

      protocol = Response.to_protocol(response)
      content = hd(protocol["content"])["text"]

      assert content =~ "Showing 6-8 of 10 stories"
    end

    test "filters by search term" do
      scope = full_scope_fixture()
      story_fixture(scope, %{title: "User Login Feature"})
      story_fixture(scope, %{title: "User Registration"})
      story_fixture(scope, %{title: "Admin Dashboard"})

      frame = %Frame{assigns: %{current_scope: scope}}

      assert {:reply, response, ^frame} = ListStories.execute(%{search: "User"}, frame)

      protocol = Response.to_protocol(response)
      content = hd(protocol["content"])["text"]

      assert content =~ "Showing 1-2 of 2 stories"
      assert content =~ "User Login Feature"
      assert content =~ "User Registration"
      refute content =~ "Admin Dashboard"
    end

    test "enforces max limit of 100" do
      scope = full_scope_fixture()
      frame = %Frame{assigns: %{current_scope: scope}}

      assert {:reply, response, ^frame} = ListStories.execute(%{limit: 500}, frame)

      protocol = Response.to_protocol(response)
      data = protocol["content"] |> hd() |> Map.get("text") |> extract_json_data()

      assert data["limit"] == 100
    end

    test "returns empty state message when no stories" do
      scope = full_scope_fixture()
      frame = %Frame{assigns: %{current_scope: scope}}

      assert {:reply, response, ^frame} = ListStories.execute(%{}, frame)

      protocol = Response.to_protocol(response)
      content = hd(protocol["content"])["text"]

      assert content =~ "No stories found"
    end
  end

  defp extract_json_data(text) do
    [_, json] = String.split(text, "Data: ", parts: 2)
    Jason.decode!(json)
  end
end

defmodule CodeMySpec.ProjectCoordinatorTest do
  use CodeMySpec.DataCase

  import CodeMySpec.UsersFixtures

  alias CodeMySpec.ProjectCoordinator
  alias CodeMySpec.Components

  @test_repo_url "https://github.com/johns10/test_phoenix_project.git"

  describe "sync_project_requirements/4" do
    setup do
      scope = full_scope_fixture()

      # Create test components matching the docs structure
      {:ok, blog_context} =
        Components.create_component(scope, %{
          name: "Blog",
          type: :context,
          module_name: "TestPhoenixProject.Blog",
          description: "Blog context"
        })

      {:ok, post_schema} =
        Components.create_component(scope, %{
          name: "Post",
          type: :schema,
          module_name: "TestPhoenixProject.Blog.Post",
          description: "Post schema"
        })

      Components.create_dependency(scope, %{
        source_component_id: blog_context.id,
        target_component_id: post_schema.id
      })

      {:ok, post_repository} =
        Components.create_component(scope, %{
          name: "PostRepository",
          type: :repository,
          module_name: "TestPhoenixProject.Blog.PostRepository",
          description: "Post repository"
        })

      Components.create_dependency(scope, %{
        source_component_id: blog_context.id,
        target_component_id: post_repository.id
      })

      {:ok, post_cache} =
        Components.create_component(scope, %{
          name: "PostCache",
          type: :genserver,
          module_name: "TestPhoenixProject.Blog.PostCache",
          description: "Post cache"
        })

      Components.create_dependency(scope, %{
        source_component_id: blog_context.id,
        target_component_id: post_cache.id
      })

      %{
        scope: scope,
        components: [blog_context, post_schema, post_repository, post_cache]
      }
    end

    @tag :integration
    test "syncs project requirements with real test project", %{scope: scope} do
      temp_dir = System.tmp_dir!()
      project_dir = Path.join(temp_dir, "test_phoenix_project")

      # Clone repositories
      System.cmd("git", [
        "clone",
        "--recurse-submodules",
        @test_repo_url,
        project_dir
      ])

      # Install dependencies
      System.cmd("mix", ["deps.get"], cd: project_dir)

      file_list =
        DirWalker.stream(project_dir)
        |> Enum.map(&Path.relative_to(&1, project_dir))
        |> Enum.to_list()

      # Run tests and collect results
      {test_output, _} =
        System.cmd("mix", ["test", "--formatter", "ExUnitJsonFormatter"], cd: project_dir)

      test_results = parse_test_results(test_output)

      # Sync project requirements
      result = ProjectCoordinator.sync_project_requirements(scope, file_list, test_results)

      post_cache = Enum.find(result, &(&1.name == "PostCache"))
      assert post_cache.requirements |> Enum.any?(&(&1.satisfied == false))

      post = Enum.find(result, &(&1.name == "Post"))
      assert post.requirements |> Enum.all?(&(&1.satisfied == true))

      post_repository = Enum.find(result, &(&1.name == "PostRepository"))
      assert post_repository.requirements |> Enum.all?(&(&1.satisfied == true))

      blog_context = Enum.find(result, &(&1.name == "Blog"))
      assert blog_context.requirements |> Enum.any?(&(&1.satisfied == false))

      blog_context
      |> Map.drop([:dependencies])

      assert is_list(result)
      assert length(result) > 0

      File.rm_rf(temp_dir)
    end
  end

  defp parse_test_results(output) do
    json_regex = ~r/\{.*\}/s
    [json_part] = Regex.run(json_regex, output)
    {:ok, data} = Jason.decode(json_part)

    # Use the TestRun changeset to parse the JSON
    changeset = CodeMySpec.Tests.TestRun.changeset(data)

    Ecto.Changeset.apply_changes(changeset)
  end
end

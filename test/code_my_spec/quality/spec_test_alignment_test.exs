defmodule CodeMySpec.QualityTest do
  use ExUnit.Case, async: true

  alias CodeMySpec.Quality
  alias CodeMySpec.Components.Component
  alias CodeMySpec.Projects.Project

  describe "spec_test_alignment/2" do
    test "detects partial alignment in Blog context" do
      # Test against the Blog context with intentional misalignment
      component = %Component{
        module_name: "Blog",
        type: :context
      }

      project = %Project{
        module_name: "TestPhoenixProject"
      }

      result =
        Quality.SpecTestAlignment.spec_test_alignment(component, project,
          cwd: "test_phoenix_project"
        )

      # Should have partial alignment (around 37-40%)
      # Missing: all subscribe_posts/1 tests, some broadcast tests, some error tests
      # Extra: 2 tests not in spec
      assert result.score > 0.0 and result.score < 0.5
      assert length(result.errors) > 5

      # Should have both missing and extra test errors
      assert Enum.any?(result.errors, fn error ->
               String.contains?(error, "Missing test assertions")
             end)

      assert Enum.any?(result.errors, fn error ->
               String.contains?(error, "Extra tests found")
             end)
    end

    test "validates PostRepository fixture with perfect alignment" do
      # Test against the test_phoenix_project fixture
      # The PostRepository tests are organized exactly according to the spec
      component = %Component{
        module_name: "Blog.PostRepository",
        type: :repository
      }

      project = %Project{
        module_name: "TestPhoenixProject"
      }

      result =
        Quality.SpecTestAlignment.spec_test_alignment(component, project,
          cwd: "test_phoenix_project"
        )

      # Should have perfect alignment - tests are in function-specific describe blocks
      # with test names matching the spec assertions exactly
      assert result.score == 1.0
      assert result.errors == []
    end
  end
end

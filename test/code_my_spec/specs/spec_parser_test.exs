defmodule CodeMySpec.Specs.SpecParserTest do
  use ExUnit.Case, async: true

  alias CodeMySpec.Specs.SpecParser
  alias CodeMySpec.Specs.Spec

  describe "parse/1" do
    test "reads file and parses to Spec" do
      # Use an actual spec file from the project
      file_path = "docs/spec/code_my_spec/contexts/dependency_tree.spec.md"

      assert {:ok, %Spec{} = spec} = SpecParser.parse(file_path)
      assert spec.module_name == "CodeMySpec.Contexts.DependencyTree"
    end

    test "returns error for missing file" do
      assert {:error, :enoent} = SpecParser.parse("nonexistent.md")
    end

    test "returns error for invalid markdown" do
      # Create a temp file with invalid content
      file_path = "test/fixtures/invalid.md"
      File.mkdir_p!("test/fixtures")
      File.write!(file_path, "```\nunclosed code block")

      result = SpecParser.parse(file_path)
      assert match?({:error, _, _}, result)

      File.rm!(file_path)
    end
  end

  describe "from_ast/1" do
    test "extracts module name from H1 header" do
      ast = [
        {"h1", [], ["MyModule.Test"], %{}}
      ]

      assert {:ok, %Spec{module_name: "MyModule.Test"}} = SpecParser.from_ast(ast)
    end

    test "returns error for missing H1 header" do
      ast = [
        {"p", [], ["Some text"], %{}}
      ]

      assert {:error, :missing_h1_header} = SpecParser.from_ast(ast)
    end

    test "extracts type from **Type** field" do
      ast = [
        {"h1", [], ["MyModule"], %{}},
        {"p", [], ["**Type**: logic"], %{}}
      ]

      assert {:ok, %Spec{type: "logic"}} = SpecParser.from_ast(ast)
    end

    test "extracts description from body text" do
      ast = [
        {"h1", [], ["MyModule"], %{}},
        {"p", [], ["**Type**: logic"], %{}},
        {"p", [], ["This is the description."], %{}},
        {"h2", [], ["Functions"], %{}}
      ]

      assert {:ok, %Spec{description: "This is the description."}} = SpecParser.from_ast(ast)
    end

    test "parses Delegates section into list of strings" do
      ast = [
        {"h1", [], ["MyModule"], %{}},
        {"h2", [], ["Delegates"], %{}},
        {"ul", [],
         [
           {"li", [], ["func1/1: OtherModule.func1/1"], %{}},
           {"li", [], ["func2/2: OtherModule.func2/2"], %{}}
         ], %{}}
      ]

      assert {:ok, %Spec{delegates: delegates}} = SpecParser.from_ast(ast)
      assert delegates == ["func1/1: OtherModule.func1/1", "func2/2: OtherModule.func2/2"]
    end

    test "parses Dependencies section into list of strings" do
      ast = [
        {"h1", [], ["MyModule"], %{}},
        {"h2", [], ["Dependencies"], %{}},
        {"ul", [],
         [
           {"li", [], ["dependency1.spec.md"], %{}},
           {"li", [], ["dependency2.spec.md"], %{}}
         ], %{}}
      ]

      assert {:ok, %Spec{dependencies: deps}} = SpecParser.from_ast(ast)
      assert deps == ["dependency1.spec.md", "dependency2.spec.md"]
    end

    test "handles missing optional sections gracefully" do
      ast = [
        {"h1", [], ["MyModule"], %{}}
      ]

      assert {:ok, %Spec{} = spec} = SpecParser.from_ast(ast)
      assert spec.delegates == []
      assert spec.dependencies == []
      assert spec.functions == []
      assert spec.fields == []
    end

    test "builds valid Spec struct" do
      ast = [
        {"h1", [], ["MyModule.Test"], %{}},
        {"p", [], ["**Type**: context"], %{}},
        {"p", [], ["Module description here."], %{}}
      ]

      assert {:ok, %Spec{} = spec} = SpecParser.from_ast(ast)
      assert spec.module_name == "MyModule.Test"
      assert spec.type == "context"
      assert spec.description == "Module description here."
    end
  end
end

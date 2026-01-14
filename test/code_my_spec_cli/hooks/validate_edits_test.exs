defmodule CodeMySpecCli.Hooks.ValidateEditsTest do
  use ExUnit.Case, async: true

  alias CodeMySpecCli.Hooks.ValidateEdits
  alias CodeMySpec.TranscriptFixtures

  @moduletag :tmp_dir

  # ============================================================================
  # Fixtures - Valid Spec Content
  # ============================================================================

  defp valid_spec_content do
    """
    # MyModule.Spec

    ## Delegates
    - func/1: Other.func/1

    ## Dependencies
    - Other.Module
    """
  end

  defp valid_context_spec_content do
    """
    # MyContext

    ## Functions

    ### my_func/1
    Does something.

    ```elixir
    @spec my_func(any()) :: :ok
    ```

    **Process**:
    1. Do the thing

    **Test Assertions**:
    - returns :ok

    ## Dependencies
    - Other.Module

    ## Components

    ### MyContext.SubModule
    A submodule that does things.
    """
  end

  defp valid_spec_with_functions_content do
    """
    # MyModule.WithFunctions

    ## Functions

    ### create/1
    Creates a thing.

    ```elixir
    @spec create(map()) :: {:ok, term()} | {:error, term()}
    ```

    **Process**:
    1. Validate input
    2. Create record

    **Test Assertions**:
    - returns {:ok, record} on success
    - returns {:error, reason} on failure

    ## Dependencies
    - Ecto
    """
  end

  # ============================================================================
  # Fixtures - Invalid Spec Content
  # ============================================================================

  defp spec_missing_required_sections do
    """
    # IncompleteSpec

    ## Purpose
    Only has purpose section.
    """
  end

  defp spec_with_disallowed_sections do
    """
    # MyModule.Spec

    ## Delegates
    - func/1: Other.func/1

    ## Dependencies
    - Other.Module

    ## Custom Section
    This section is not allowed in specs.
    """
  end

  defp empty_content do
    ""
  end

  # ============================================================================
  # Fixtures - Transcript Creation
  # ============================================================================

  defp create_transcript_file(tmp_dir, entries) do
    content = TranscriptFixtures.to_jsonl_content(entries)
    path = Path.join(tmp_dir, "transcript.jsonl")
    File.write!(path, content)
    path
  end

  defp create_spec_file(tmp_dir, relative_path, content) do
    full_path = Path.join(tmp_dir, relative_path)
    full_path |> Path.dirname() |> File.mkdir_p!()
    File.write!(full_path, content)
    full_path
  end

  defp transcript_with_spec_edit(spec_path) do
    [
      TranscriptFixtures.user_entry_json(),
      TranscriptFixtures.assistant_entry_with_tools([
        TranscriptFixtures.edit_tool_json(%{
          "input" => %{
            "file_path" => spec_path,
            "old_string" => "foo",
            "new_string" => "bar"
          }
        })
      ])
    ]
  end

  defp transcript_with_multiple_spec_edits(spec_paths) do
    tool_blocks =
      Enum.map(spec_paths, fn path ->
        TranscriptFixtures.edit_tool_json(%{
          "id" => "edit_#{:erlang.phash2(path)}",
          "input" => %{"file_path" => path, "old_string" => "a", "new_string" => "b"}
        })
      end)

    [
      TranscriptFixtures.user_entry_json(),
      TranscriptFixtures.assistant_entry_with_tools(tool_blocks)
    ]
  end

  defp transcript_with_non_spec_edit(file_path) do
    [
      TranscriptFixtures.user_entry_json(),
      TranscriptFixtures.assistant_entry_with_tools([
        TranscriptFixtures.edit_tool_json(%{
          "input" => %{
            "file_path" => file_path,
            "old_string" => "foo",
            "new_string" => "bar"
          }
        })
      ])
    ]
  end

  defp empty_transcript do
    [TranscriptFixtures.user_entry_json(), TranscriptFixtures.assistant_entry_json()]
  end

  defp malformed_transcript_content do
    """
    {"type": "user", "uuid": "123"}
    {invalid json here
    {"type": "assistant", "uuid": "456"}
    """
  end

  # ============================================================================
  # run/1 Tests
  # ============================================================================

  describe "run/1" do
    test "returns {:ok, :valid} when transcript has no file edits", %{tmp_dir: tmp_dir} do
      transcript_path = create_transcript_file(tmp_dir, empty_transcript())

      assert {:ok, :valid} = ValidateEdits.run(transcript_path)
    end

    test "returns {:ok, :valid} when transcript has only non-spec file edits", %{tmp_dir: tmp_dir} do
      ex_file = Path.join(tmp_dir, "lib/my_module.ex")
      File.mkdir_p!(Path.dirname(ex_file))
      File.write!(ex_file, "defmodule MyModule do\nend")

      entries = transcript_with_non_spec_edit(ex_file)
      transcript_path = create_transcript_file(tmp_dir, entries)

      assert {:ok, :valid} = ValidateEdits.run(transcript_path)
    end

    test "returns {:ok, :valid} when single valid spec file was edited", %{tmp_dir: tmp_dir} do
      spec_path = create_spec_file(tmp_dir, "docs/spec/my_module.spec.md", valid_spec_content())

      entries = transcript_with_spec_edit(spec_path)
      transcript_path = create_transcript_file(tmp_dir, entries)

      assert {:ok, :valid} = ValidateEdits.run(transcript_path)
    end

    test "returns {:ok, :valid} when multiple valid spec files were edited", %{tmp_dir: tmp_dir} do
      spec1 = create_spec_file(tmp_dir, "docs/spec/module_a.spec.md", valid_spec_content())

      spec2 =
        create_spec_file(
          tmp_dir,
          "docs/spec/module_b.spec.md",
          valid_spec_with_functions_content()
        )

      entries = transcript_with_multiple_spec_edits([spec1, spec2])
      transcript_path = create_transcript_file(tmp_dir, entries)

      assert {:ok, :valid} = ValidateEdits.run(transcript_path)
    end

    test "returns {:error, [errors]} when spec file is missing required sections", %{
      tmp_dir: tmp_dir
    } do
      spec_path =
        create_spec_file(
          tmp_dir,
          "docs/spec/incomplete.spec.md",
          spec_missing_required_sections()
        )

      entries = transcript_with_spec_edit(spec_path)
      transcript_path = create_transcript_file(tmp_dir, entries)

      assert {:error, errors} = ValidateEdits.run(transcript_path)
      assert is_list(errors)
      assert length(errors) > 0
    end

    test "returns {:error, [errors]} when spec file has disallowed sections", %{tmp_dir: tmp_dir} do
      spec_path =
        create_spec_file(tmp_dir, "docs/spec/bad.spec.md", spec_with_disallowed_sections())

      entries = transcript_with_spec_edit(spec_path)
      transcript_path = create_transcript_file(tmp_dir, entries)

      assert {:error, errors} = ValidateEdits.run(transcript_path)
      assert is_list(errors)
      assert Enum.any?(errors, &String.contains?(&1, "Disallowed"))
    end

    test "includes file path in error message for identification", %{tmp_dir: tmp_dir} do
      spec_path =
        create_spec_file(tmp_dir, "docs/spec/invalid.spec.md", spec_missing_required_sections())

      entries = transcript_with_spec_edit(spec_path)
      transcript_path = create_transcript_file(tmp_dir, entries)

      assert {:error, errors} = ValidateEdits.run(transcript_path)
      assert Enum.any?(errors, &String.contains?(&1, spec_path))
    end

    test "validates all spec files before returning collected errors", %{tmp_dir: tmp_dir} do
      spec1 =
        create_spec_file(tmp_dir, "docs/spec/bad_one.spec.md", spec_missing_required_sections())

      spec2 =
        create_spec_file(tmp_dir, "docs/spec/bad_two.spec.md", spec_with_disallowed_sections())

      entries = transcript_with_multiple_spec_edits([spec1, spec2])
      transcript_path = create_transcript_file(tmp_dir, entries)

      assert {:error, errors} = ValidateEdits.run(transcript_path)
      assert length(errors) >= 2
      assert Enum.any?(errors, &String.contains?(&1, "bad_one.spec.md"))
      assert Enum.any?(errors, &String.contains?(&1, "bad_two.spec.md"))
    end

    test "handles transcript parse failure gracefully", %{tmp_dir: tmp_dir} do
      malformed_path = Path.join(tmp_dir, "malformed.jsonl")
      File.write!(malformed_path, malformed_transcript_content())

      assert {:error, _reason} = ValidateEdits.run(malformed_path)
    end

    test "handles file read failure gracefully (file deleted after edit)", %{tmp_dir: tmp_dir} do
      # Create transcript referencing a spec file that doesn't exist
      nonexistent_spec = Path.join(tmp_dir, "docs/spec/deleted.spec.md")

      entries = transcript_with_spec_edit(nonexistent_spec)
      transcript_path = create_transcript_file(tmp_dir, entries)

      assert {:error, errors} = ValidateEdits.run(transcript_path)
      assert is_list(errors)
    end

    test "returns {:error, [:file_not_found]} when transcript path does not exist", %{
      tmp_dir: tmp_dir
    } do
      nonexistent_path = Path.join(tmp_dir, "nonexistent.jsonl")

      assert {:error, [:file_not_found]} = ValidateEdits.run(nonexistent_path)
    end
  end

  # ============================================================================
  # validate_spec_file/1 Tests
  # ============================================================================

  describe "validate_spec_file/1" do
    test "returns :ok for valid spec document", %{tmp_dir: tmp_dir} do
      spec_path = create_spec_file(tmp_dir, "docs/spec/valid.spec.md", valid_spec_content())

      assert :ok = ValidateEdits.validate_spec_file(spec_path)
    end

    test "returns {:error, reason} for spec missing required sections", %{tmp_dir: tmp_dir} do
      spec_path =
        create_spec_file(tmp_dir, "docs/spec/missing.spec.md", spec_missing_required_sections())

      assert {:error, reason} = ValidateEdits.validate_spec_file(spec_path)
      assert is_binary(reason)
      assert reason =~ "Missing required sections"
    end

    test "returns {:error, reason} for spec with invalid sections", %{tmp_dir: tmp_dir} do
      spec_path =
        create_spec_file(tmp_dir, "docs/spec/invalid.spec.md", spec_with_disallowed_sections())

      assert {:error, reason} = ValidateEdits.validate_spec_file(spec_path)
      assert is_binary(reason)
      assert reason =~ "Disallowed"
    end

    test "returns {:error, reason} when file does not exist", %{tmp_dir: tmp_dir} do
      nonexistent_path = Path.join(tmp_dir, "does_not_exist.spec.md")

      assert {:error, reason} = ValidateEdits.validate_spec_file(nonexistent_path)
      assert is_binary(reason)
    end

    test "returns {:error, reason} when file is empty", %{tmp_dir: tmp_dir} do
      spec_path = create_spec_file(tmp_dir, "docs/spec/empty.spec.md", empty_content())

      assert {:error, reason} = ValidateEdits.validate_spec_file(spec_path)
      assert is_binary(reason)
    end

    test "determines document type correctly from path", %{tmp_dir: tmp_dir} do
      # Context spec should be validated as context_spec type
      context_spec_path =
        create_spec_file(
          tmp_dir,
          "docs/spec/my_context/my_context.spec.md",
          valid_context_spec_content()
        )

      assert :ok = ValidateEdits.validate_spec_file(context_spec_path)
    end
  end

  # ============================================================================
  # document_type_from_path/1 Tests
  # ============================================================================

  describe "document_type_from_path/1" do
    test "returns \"context_spec\" for top-level context spec files" do
      # Context specs have file name matching directory name pattern
      # e.g., docs/spec/code_my_spec/documents.spec.md (documents is both dir and file base)
      path = "/project/docs/spec/code_my_spec/documents.spec.md"

      assert "context_spec" = ValidateEdits.document_type_from_path(path)
    end

    test "returns \"spec\" for component-level spec files" do
      # Component specs are nested within a context directory
      # e.g., docs/spec/code_my_spec/documents/registry.spec.md
      path = "/project/docs/spec/code_my_spec/documents/registry.spec.md"

      assert "spec" = ValidateEdits.document_type_from_path(path)
    end

    test "returns \"spec\" for nested component spec files" do
      # Deeply nested component specs
      path = "/project/docs/spec/code_my_spec/documents/parsers/function_parser.spec.md"

      assert "spec" = ValidateEdits.document_type_from_path(path)
    end

    test "handles various path depths correctly" do
      # Shallow path
      shallow_path = "/docs/spec/module.spec.md"
      assert "spec" = ValidateEdits.document_type_from_path(shallow_path)

      # Deep path that is a context spec
      deep_context = "/a/b/c/d/my_context.spec.md"
      assert "spec" = ValidateEdits.document_type_from_path(deep_context)

      # Path with matching directory name pattern
      matching_dir = "/project/docs/spec/my_app/accounts.spec.md"
      assert "context_spec" = ValidateEdits.document_type_from_path(matching_dir)
    end
  end

  # ============================================================================
  # spec_file?/1 Tests
  # ============================================================================

  describe "spec_file?/1" do
    test "returns true for paths ending in .spec.md" do
      assert ValidateEdits.spec_file?("/path/to/module.spec.md")
      assert ValidateEdits.spec_file?("module.spec.md")
      assert ValidateEdits.spec_file?("/deep/nested/path/to/module.spec.md")
    end

    test "returns false for paths ending in .md (non-spec markdown)" do
      refute ValidateEdits.spec_file?("/path/to/README.md")
      refute ValidateEdits.spec_file?("/path/to/CHANGELOG.md")
      refute ValidateEdits.spec_file?("/docs/guide.md")
    end

    test "returns false for paths ending in .ex" do
      refute ValidateEdits.spec_file?("/lib/my_module.ex")
      refute ValidateEdits.spec_file?("/test/my_module_test.exs")
    end

    test "returns false for paths without extension" do
      refute ValidateEdits.spec_file?("/path/to/Makefile")
      refute ValidateEdits.spec_file?("/path/to/Dockerfile")
      refute ValidateEdits.spec_file?("README")
    end
  end

  # ============================================================================
  # format_output/1 Tests
  # ============================================================================

  describe "format_output/1" do
    test "returns empty map for valid result (allows stop)" do
      result = ValidateEdits.format_output({:ok, :valid})

      assert result == %{}
    end

    test "returns decision block with reason for errors" do
      result = ValidateEdits.format_output({:error, ["Error one", "Error two"]})

      assert %{"decision" => "block", "reason" => reason} = result
      assert is_binary(reason)
    end

    test "formats multiple errors as readable list in reason" do
      errors = [
        "docs/spec/a.spec.md: Missing required sections",
        "docs/spec/b.spec.md: Disallowed sections found"
      ]

      result = ValidateEdits.format_output({:error, errors})

      assert %{"reason" => reason} = result
      assert reason =~ "a.spec.md"
      assert reason =~ "b.spec.md"
    end

    test "single error returns concise message" do
      result = ValidateEdits.format_output({:error, ["Single validation error"]})

      assert %{"reason" => reason} = result
      assert reason =~ "Single validation error"
    end
  end
end

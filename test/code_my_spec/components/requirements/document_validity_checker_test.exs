defmodule CodeMySpec.Components.Requirements.DocumentValidityCheckerTest do
  use ExUnit.Case, async: true
  doctest CodeMySpec.Components.Requirements.DocumentValidityChecker

  alias CodeMySpec.Components.Requirements.DocumentValidityChecker
  alias CodeMySpec.Components.Component

  @valid_context_spec_content """
  # TestContext

  ## Delegates
  - func/1: Other.func/1

  ## Dependencies
  - Some.Module

  ## Components
  ### ComponentOne
  Description of component.
  """

  @valid_spec_content """
  # TestModule

  ## Delegates
  - func/1: Other.func/1

  ## Dependencies
  - Some.Module
  """

  @valid_schema_content """
  # User Schema
  Represents user entities.

  ## Fields
  | Field | Type | Required | Description | Constraints |
  |-------|------|----------|-------------|-------------|
  | email | string | Yes | User email | Unique |
  """

  @invalid_spec_content """
  # Incomplete

  ## Purpose
  Only has purpose.
  """

  describe "check/2 with valid documents" do
    test "validates a valid context_spec document" do
      module_name = "TestApp.TestContextSpec"
      spec_path = create_spec_file(module_name, @valid_context_spec_content)

      component = %Component{module_name: module_name}

      requirement_spec = %{
        name: :spec_valid,
        checker: DocumentValidityChecker,
        satisfied_by: "ContextSpecSessions",
        document_type: "context_spec"
      }

      result = DocumentValidityChecker.check(requirement_spec, component)

      assert result.satisfied == true
      assert result.name == "spec_valid"
      assert result.type == :document_validity
      assert result.details.status == "Document is valid"
      assert result.details.document_type == "context_spec"

      cleanup_spec_file(spec_path)
    end

    test "validates a valid spec document" do
      module_name = "TestApp.TestSpec"
      spec_path = create_spec_file(module_name, @valid_spec_content)

      component = %Component{module_name: module_name}

      requirement_spec = %{
        name: :spec_valid,
        checker: DocumentValidityChecker,
        satisfied_by: "ComponentSpecSessions",
        document_type: "spec"
      }

      result = DocumentValidityChecker.check(requirement_spec, component)

      assert result.satisfied == true
      assert result.details.document_type == "spec"

      cleanup_spec_file(spec_path)
    end

    test "validates a valid schema document" do
      module_name = "TestApp.TestSchema"
      spec_path = create_spec_file(module_name, @valid_schema_content)

      component = %Component{module_name: module_name}

      requirement_spec = %{
        name: :spec_valid,
        checker: DocumentValidityChecker,
        satisfied_by: "ComponentSpecSessions",
        document_type: "schema"
      }

      result = DocumentValidityChecker.check(requirement_spec, component)
      assert result.satisfied == true
      assert result.details.document_type == "schema"

      cleanup_spec_file(spec_path)
    end
  end

  describe "check/2 with invalid documents" do
    test "returns error for document missing required sections" do
      module_name = "TestApp.InvalidSpec"
      spec_path = create_spec_file(module_name, @invalid_spec_content)

      component = %Component{module_name: module_name}

      requirement_spec = %{
        name: :spec_valid,
        checker: DocumentValidityChecker,
        satisfied_by: "ComponentSpecSessions",
        document_type: "spec"
      }

      result = DocumentValidityChecker.check(requirement_spec, component)

      assert result.satisfied == false
      assert result.details.reason == "Document validation failed"
      assert result.details.error =~ "Missing required sections"
      assert result.details.document_type == "spec"

      cleanup_spec_file(spec_path)
    end

    test "returns error for document with disallowed sections" do
      content = """
      # TestModule

      ## Delegates
      - func/1: Other.func/1

      ## Dependencies
      - Some.Module

      ## Custom Section
      Not allowed for specs!
      """

      module_name = "TestApp.DisallowedSpec"
      spec_path = create_spec_file(module_name, content)

      component = %Component{module_name: module_name}

      requirement_spec = %{
        name: :spec_valid,
        checker: DocumentValidityChecker,
        satisfied_by: "ComponentSpecSessions",
        document_type: "spec"
      }

      result = DocumentValidityChecker.check(requirement_spec, component)

      assert result.satisfied == false
      assert result.details.reason == "Document validation failed"
      assert result.details.error =~ "Disallowed sections found"

      cleanup_spec_file(spec_path)
    end
  end

  describe "check/2 with missing files" do
    test "returns error when file does not exist" do
      component = %Component{module_name: "TestApp.NonexistentModule"}

      requirement_spec = %{
        name: :spec_valid,
        checker: DocumentValidityChecker,
        satisfied_by: "ComponentSpecSessions",
        document_type: "spec"
      }

      result = DocumentValidityChecker.check(requirement_spec, component)

      assert result.satisfied == false
      assert result.details.reason =~ "Failed to read spec file"
    end
  end

  describe "check/2 with missing document_type" do
    test "returns error when document_type is not specified" do
      component = %Component{module_name: "TestApp.SomeModule"}

      requirement_spec = %{
        name: :spec_valid,
        checker: DocumentValidityChecker,
        satisfied_by: "ComponentSpecSessions"
        # document_type is missing
      }

      result = DocumentValidityChecker.check(requirement_spec, component)

      assert result.satisfied == false
      assert result.details.reason == "document_type not specified in requirement"
    end
  end

  describe "result structure" do
    test "includes all required fields" do
      module_name = "TestApp.ResultStructureTest"
      spec_path = create_spec_file(module_name, @valid_spec_content)

      component = %Component{module_name: module_name}

      requirement_spec = %{
        name: :spec_valid,
        checker: DocumentValidityChecker,
        satisfied_by: "ComponentSpecSessions",
        document_type: "spec"
      }

      result = DocumentValidityChecker.check(requirement_spec, component)

      assert Map.has_key?(result, :name)
      assert Map.has_key?(result, :type)
      assert Map.has_key?(result, :description)
      assert Map.has_key?(result, :checker_module)
      assert Map.has_key?(result, :satisfied_by)
      assert Map.has_key?(result, :satisfied)
      assert Map.has_key?(result, :checked_at)
      assert Map.has_key?(result, :details)

      assert result.type == :document_validity
      assert result.checker_module =~ "DocumentValidityChecker"

      cleanup_spec_file(spec_path)
    end
  end

  # Helper functions
  defp create_spec_file(module_name, content) do
    files = CodeMySpec.Utils.component_files(module_name)
    spec_path = files.spec_file

    # Ensure directory exists
    spec_path |> Path.dirname() |> File.mkdir_p!()

    # Write the spec file
    File.write!(spec_path, content)

    spec_path
  end

  defp cleanup_spec_file(spec_path) do
    File.rm(spec_path)

    # Clean up empty directories
    spec_path
    |> Path.dirname()
    |> cleanup_empty_dirs()
  end

  defp cleanup_empty_dirs(dir) do
    case File.ls(dir) do
      {:ok, []} ->
        File.rmdir(dir)
        dir |> Path.dirname() |> cleanup_empty_dirs()

      _ ->
        :ok
    end
  end
end

defmodule CodeMySpec.ProjectsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `CodeMySpec.Projects` context.
  """

  @doc """
  Generate a project.
  """
  def project_fixture(scope, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        code_repo: "some code_repo",
        docs_repo: "some docs_repo",
        name: "some name",
        setup_error: "some setup_error",
        status: :created
      })

    {:ok, project} = CodeMySpec.Projects.create_project(scope, attrs)
    project
  end
end

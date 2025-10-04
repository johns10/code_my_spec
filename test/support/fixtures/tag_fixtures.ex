defmodule CodeMySpec.TagFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `CodeMySpec.Content.Tag` schema.
  """

  alias CodeMySpec.Content.Tag
  alias CodeMySpec.Repo

  def valid_tag_attributes(project, account, attrs \\ %{}) do
    unique_id = System.unique_integer([:positive])

    Enum.into(attrs, %{
      name: "Test Tag #{unique_id}",
      project_id: project.id,
      account_id: account.id
    })
  end

  def tag_fixture(project, account, attrs \\ %{}) do
    %Tag{}
    |> Tag.changeset(valid_tag_attributes(project, account, attrs))
    |> Repo.insert!()
  end

  def uppercase_tag_fixture(project, account, attrs \\ %{}) do
    attrs = Enum.into(attrs, %{name: "UPPERCASE TAG"})
    tag_fixture(project, account, attrs)
  end

  def mixed_case_tag_fixture(project, account, attrs \\ %{}) do
    attrs = Enum.into(attrs, %{name: "MiXeD CaSe TaG"})
    tag_fixture(project, account, attrs)
  end

  def special_chars_tag_fixture(project, account, attrs \\ %{}) do
    attrs = Enum.into(attrs, %{name: "Tag with Special-Chars & Symbols!"})
    tag_fixture(project, account, attrs)
  end

  def long_tag_fixture(project, account, attrs \\ %{}) do
    attrs = Enum.into(attrs, %{name: String.duplicate("a", 50)})
    tag_fixture(project, account, attrs)
  end
end
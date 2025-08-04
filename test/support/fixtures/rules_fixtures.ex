defmodule CodeMySpec.RulesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `CodeMySpec.Rules` context.
  """

  @doc """
  Generate a rule.
  """
  def rule_fixture(scope, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        component_type: "some component_type",
        content: "some content",
        name: "some name",
        session_type: "some session_type"
      })

    {:ok, rule} = CodeMySpec.Rules.create_rule(scope, attrs)
    rule
  end
end

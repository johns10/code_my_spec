defmodule CodeMySpec.UserPreferencesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `CodeMySpec.UserPreferences` context.
  """

  @doc """
  Generate a user_preference.
  """
  def user_preference_fixture(scope, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        active_account_id: 42,
        active_project_id: 42,
        token: "some token"
      })

    {:ok, user_preference} = CodeMySpec.UserPreferences.create_user_preferences(scope, attrs)
    user_preference
  end
end

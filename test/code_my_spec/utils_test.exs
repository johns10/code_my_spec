defmodule CodeMySpec.UtilsTest do
  use CodeMySpec.DataCase, async: true

  alias CodeMySpec.Utils

  describe "changeset_error_to_string/1" do
    test "handles Ecto.Enum type errors without crashing" do
      alias CodeMySpec.Stories.Story

      # Create a changeset with an invalid type that will trigger an Ecto.Enum validation error
      changeset =
        Story.changeset(
          %Story{},
          %{
            title: "Finalize",
            description: "Test step",
            acceptance_criteria: ["ProjectSetupSessions.Steps.Finalize"],
            status: "fuck"
          }
        )

      # This should not crash with Protocol.UndefinedError
      error_string = Utils.changeset_error_to_string(changeset)

      # Should contain the field name and indicate it's invalid
      assert error_string =~ "status"
      assert error_string =~ "is invalid"
    end
  end
end

defmodule CodeMySpec.UtilsTest do
  use CodeMySpec.DataCase, async: true

  import CodeMySpec.UsersFixtures

  alias CodeMySpec.Utils

  describe "changeset_error_to_string/1" do
    test "handles Ecto.Enum type errors without crashing" do
      alias CodeMySpec.Components.Component

      scope = full_scope_fixture()

      # Create a changeset with an invalid type that will trigger an Ecto.Enum validation error
      changeset =
        Component.changeset(
          %Component{},
          %{
            name: "Finalize",
            description: "Test step",
            module_name: "ProjectSetupSessions.Steps.Finalize",
            type: "invalid_type",
            account_id: scope.active_account.id,
            project_id: scope.active_project.id
          },
          scope
        )

      # This should not crash with Protocol.UndefinedError
      error_string = Utils.changeset_error_to_string(changeset)

      # Should contain the field name and indicate it's invalid
      assert error_string =~ "type"
      assert error_string =~ "is invalid"
    end
  end
end

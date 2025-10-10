defmodule CodeMySpec.UtilsTest do
  use CodeMySpec.DataCase, async: true

  import CodeMySpec.UsersFixtures

  alias CodeMySpec.Utils
  alias CodeMySpec.Documents.ContextDesign

  describe "changeset_error_to_string/1" do
    test "formats simple validation errors" do
      changeset = ContextDesign.changeset(%ContextDesign{}, %{})

      error_string = Utils.changeset_error_to_string(changeset)

      assert error_string =~ "purpose: can't be blank"
    end

    test "interpolates values in error messages" do
      changeset =
        ContextDesign.changeset(%ContextDesign{}, %{
          purpose: "test",
          components: [%{module_name: "ab", description: "test"}]
        })

      error_string = Utils.changeset_error_to_string(changeset)

      assert error_string =~ "must be a valid Elixir module name"
    end

    test "formats nested embedded schema errors" do
      changeset =
        ContextDesign.changeset(%ContextDesign{}, %{
          purpose: "test",
          components: [%{module_name: "ValidModule"}]
        })

      error_string = Utils.changeset_error_to_string(changeset)

      assert error_string =~ "components"
      assert error_string =~ "description"
    end

    test "handles multiple validation errors" do
      changeset =
        ContextDesign.changeset(%ContextDesign{}, %{
          dependencies: ["invalid-module-name", "AnotherBad!"]
        })

      error_string = Utils.changeset_error_to_string(changeset)

      assert error_string =~ "purpose:"
      assert error_string =~ "dependencies:"
    end

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

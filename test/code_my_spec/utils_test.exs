defmodule CodeMySpec.UtilsTest do
  use ExUnit.Case, async: true

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
  end
end

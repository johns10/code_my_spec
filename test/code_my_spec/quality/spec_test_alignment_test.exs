defmodule CodeMySpec.QualityTest do
  use ExUnit.Case, async: true

  alias CodeMySpec.Quality
  alias CodeMySpec.Components.Component
  alias CodeMySpec.Projects.Project

  describe "spec_test_alignment/2" do
    test "validates component and returns result" do
      # Use a test component
      component = %Component{
        module_name: "Code.ElixirAst",
        type: :module
      }

      project = %Project{
        module_name: "CodeMySpec"
      }

      assert :ok == Quality.SpecTestAlignment.spec_test_alignment(component, project)
    end
  end
end

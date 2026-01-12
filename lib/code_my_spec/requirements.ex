defmodule CodeMySpec.Requirements do
  alias CodeMySpec.Requirements.RequirementsRepository
  alias CodeMySpec.Components

  defdelegate clear_all_project_requirements(scope), to: RequirementsRepository
  defdelegate clear_requirements(scope, component, opts \\ []), to: RequirementsRepository
  defdelegate create_requirement(scope, component, attrs, opts \\ []), to: RequirementsRepository

  def check_requirements(scope, component, opts) do
    include_types = Keyword.get(opts, :include, [])
    exclude_types = Keyword.get(opts, :exclude, [])

    Components.get_requirements_for_type(component.type)
    |> Enum.filter(fn %{name: name} ->
      exclude = length(exclude_types) > 0 and name in exclude_types

      include =
        (length(include_types) > 0 and name in include_types) or length(include_types) == 0

      include && !exclude
    end)
    |> Enum.map(fn requirement_spec ->
      checker = requirement_spec.checker
      checker.check(scope, requirement_spec, component, opts)
    end)
  end
end

defmodule CodeMySpec.Components.Requirements.DependencyChecker do
  @behaviour CodeMySpec.Components.Requirements.CheckerBehaviour
  alias CodeMySpec.Components.Component

  def check(%{name: name} = requirement_spec, %Component{dependencies: dependencies}) do
    {satisfied, details} =
      case {name, dependencies} do
        {:dependencies_satisfied, []} ->
          {true, %{status: "No dependencies to satisfy"}}

        {:dependencies_satisfied, deps} when is_list(deps) ->
          # Check if all dependencies have their requirements satisfied
          all_satisfied = Enum.all?(deps, &dependency_satisfied?/1)

          if all_satisfied do
            {true, %{status: "All dependencies satisfied", count: length(deps)}}
          else
            unsatisfied_deps =
              deps
              |> Enum.reject(&dependency_satisfied?/1)
              |> Enum.map(& &1.name)

            {false,
             %{
               reason: "Some dependencies not satisfied",
               unsatisfied_dependencies: unsatisfied_deps,
               total_dependencies: length(deps),
               unsatisfied_count: length(unsatisfied_deps)
             }}
          end

        # Handle case where dependencies is not loaded
        {:dependencies_satisfied, %Ecto.Association.NotLoaded{}} ->
          {false, %{reason: "Dependencies not loaded"}}

        # Handle other cases
        {_, _} ->
          {false, %{reason: "Invalid dependency structure"}}
      end

    %{
      name: Atom.to_string(requirement_spec.name),
      type: :dependencies_satisfied,
      description: generate_description(requirement_spec.name),
      checker_module: Atom.to_string(requirement_spec.checker),
      satisfied_by:
        requirement_spec.satisfied_by && Atom.to_string(requirement_spec.satisfied_by),
      satisfied: satisfied,
      checked_at: DateTime.utc_now(),
      details: details
    }
  end

  defp dependency_satisfied?(%Component{requirements: requirements}) when is_list(requirements) do
    # All requirements must be satisfied
    Enum.all?(requirements, fn req -> req.satisfied end)
  end

  defp dependency_satisfied?(%Component{requirements: %Ecto.Association.NotLoaded{}}) do
    # If requirements not loaded, assume not satisfied for safety
    false
  end

  defp dependency_satisfied?(_), do: false

  defp generate_description(:dependencies_satisfied),
    do: "All component dependencies are satisfied"

  defp generate_description(name), do: "Dependency requirement #{name} is satisfied"
end

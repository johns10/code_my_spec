defmodule CodeMySpec.Components.Requirements.HierarchicalChecker do
  @behaviour CodeMySpec.Components.Requirements.CheckerBehaviour
  require Logger
  alias CodeMySpec.Components.Component

  def check(%{name: name} = requirement_spec, %Component{} = component) do
    {satisfied, details} =
      case name do
        :children_designs ->
          check_children_requirements(component, "design_file")

        :children_implementations ->
          check_children_requirements(component, "implementation_file")

        :children_tests ->
          check_children_requirements(component, "test_file")

        :children_complete ->
          check_all_children_requirements(component)

        _ ->
          Logger.error("#{__MODULE__} was passed a registry spec with an invalid name #{name}.")
          {false, %{reason: "Invalid hierarchical requirement type"}}
      end

    %{
      name: Atom.to_string(requirement_spec.name),
      type: :hierarchy,
      description: generate_description(requirement_spec.name),
      checker_module: Atom.to_string(requirement_spec.checker),
      satisfied_by:
        requirement_spec.satisfied_by && Atom.to_string(requirement_spec.satisfied_by),
      satisfied: satisfied,
      checked_at: DateTime.utc_now(),
      details: details
    }
  end

  defp check_children_requirements(
         %Component{child_components: %Ecto.Association.NotLoaded{}} = component,
         _requirement_name
       ) do
    Logger.error("#{__MODULE__} was passed a component with child components not loaded.",
      component: component
    )

    {false, %{reason: "Child components not loaded"}}
  end

  defp check_children_requirements(%Component{child_components: []}, _requirement_name) do
    {true, %{status: "No child components to check", count: 0}}
  end

  defp check_children_requirements(%Component{child_components: children}, requirement_name)
       when is_list(children) do
    all_satisfied = all_children_have_requirement?(children, requirement_name)

    if all_satisfied do
      {true, %{status: "All child components have required #{requirement_name}"}}
    else
      {false, %{reason: "Some child components missing #{requirement_name}"}}
    end
  end

  defp check_all_children_requirements(%Component{
         child_components: %Ecto.Association.NotLoaded{}
       }) do
    {false, %{reason: "Child components not loaded"}}
  end

  defp check_all_children_requirements(%Component{child_components: []}) do
    {true, %{status: "No child components to check", count: 0}}
  end

  defp check_all_children_requirements(%Component{child_components: children})
       when is_list(children) do
    all_complete = all_children_complete?(children)

    if all_complete do
      {true, %{status: "All child components fully complete"}}
    else
      {false, %{reason: "Some child components not fully complete"}}
    end
  end

  defp all_children_have_requirement?([], _requirement_name), do: true

  defp all_children_have_requirement?([component | rest], requirement_name) do
    has_requirement?(component, requirement_name) and
      all_children_have_requirement?(get_children(component), requirement_name) and
      all_children_have_requirement?(rest, requirement_name)
  end

  defp all_children_complete?([]), do: true

  defp all_children_complete?([component | rest]) do
    fully_complete?(component) and
      all_children_complete?(get_children(component)) and
      all_children_complete?(rest)
  end

  defp get_children(%Component{child_components: %Ecto.Association.NotLoaded{}}), do: []
  defp get_children(%Component{child_components: children}) when is_list(children), do: children
  defp get_children(_), do: []

  defp has_requirement?(%Component{requirements: requirements}, requirement_name)
       when is_list(requirements) do
    Enum.any?(requirements, fn req ->
      req.name == requirement_name and req.satisfied
    end)
  end

  defp fully_complete?(%Component{requirements: %Ecto.Association.NotLoaded{}}), do: false
  defp fully_complete?(%Component{requirements: []}), do: true

  defp fully_complete?(%Component{requirements: requirements}) when is_list(requirements) do
    # Component is fully complete if all its requirements are satisfied
    Enum.all?(requirements, fn req -> req.satisfied end)
  end

  defp fully_complete?(_), do: false

  defp generate_description(:children_designs),
    do: "All child component design files exist"

  defp generate_description(:children_implementations),
    do: "All child component implementation files exist"

  defp generate_description(:children_tests),
    do: "All child component test files exist"

  defp generate_description(:children_complete),
    do: "All child components are fully implemented and tested"

  defp generate_description(name),
    do: "Hierarchical requirement #{name} is satisfied"
end

defmodule CodeMySpecCli.Components.ComponentMenu do
  @moduledoc """
  Interactive typeahead menu for searching and selecting components.

  Uses Owl.IO.select with live search to filter components by module name.
  """

  alias CodeMySpec.Components
  alias CodeMySpec.Users.Scope

  @doc """
  Shows an interactive component search menu with typeahead filtering.

  ## Parameters
    - `scope` - User scope for querying components

  ## Returns
    - `{:ok, component}` - Selected component
    - `{:error, :cancelled}` - User cancelled the selection

  ## Examples

      iex> ComponentMenu.show(scope)
      {:ok, %Component{module_name: "MyApp.Accounts", ...}}
  """
  def show(%Scope{} = scope) do
    # Get all components initially
    all_components = Components.list_components(scope)

    if length(all_components) == 0 do
      Owl.IO.puts(["\n", Owl.Data.tag("No components found in project.", :yellow), "\n"])
      {:error, :no_components}
    else
      # Create label-to-component mapping
      label_map =
        all_components
        |> Enum.map(fn component ->
          label = format_component_label(component)
          {label, component}
        end)
        |> Map.new()

      # Extract just labels for Owl.IO.select
      labels = Map.keys(label_map)

      # Show select menu
      case Owl.IO.select(labels, label: "Search and select a component:") do
        nil -> {:error, :cancelled}
        selected_label -> {:ok, Map.get(label_map, selected_label)}
      end
    end
  end

  @doc """
  Shows component menu and returns just the component ID if selected.
  """
  def select_component_id(%Scope{} = scope) do
    case show(scope) do
      {:ok, component} -> {:ok, component.id}
      error -> error
    end
  end

  # Private Functions

  # Formats a component for display in the menu
  defp format_component_label(component) do
    type_str = format_type(component.type)
    module_name = component.module_name || "Unknown"

    # Format: "ModuleName (type)" - plain string for Owl.IO.select
    "#{module_name} (#{type_str})"
  end

  defp format_type(nil), do: "unknown"
  defp format_type(type) when is_atom(type) do
    type
    |> Atom.to_string()
    |> String.replace("_", " ")
  end
end
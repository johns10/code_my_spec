defmodule CodeMySpecCli.Screens.ComponentsBrowser do
  @moduledoc """
  Components browser screen for Ratatouille.

  Displays a searchable list of components with real-time updates.
  """

  import Ratatouille.View
  import Ratatouille.Constants, only: [key: 1]

  alias CodeMySpec.Components
  alias CodeMySpec.Users.Scope

  # States: :list, :detail
  defstruct [
    :state,
    :scope,
    :components,
    :selected_index,
    :filter,
    :detail_component,
    :error_message
  ]

  @doc """
  Initialize the components browser screen.
  Returns {state, nil} - no async commands needed.
  """
  def init do
    scope = Scope.for_cli()

    if is_nil(scope) do
      state = %__MODULE__{
        state: :error,
        scope: nil,
        components: [],
        selected_index: 0,
        filter: "",
        detail_component: nil,
        error_message: "No active project found. Run /init to initialize a project."
      }

      {state, nil}
    else
      # Subscribe to component changes
      Components.subscribe_components(scope)

      # Load initial components
      components = Components.list_components(scope)

      state = %__MODULE__{
        state: :list,
        scope: scope,
        components: components,
        selected_index: 0,
        filter: "",
        detail_component: nil,
        error_message: nil
      }

      {state, nil}
    end
  end

  @doc """
  Update the components browser state.
  Returns {:ok, new_state} or {:switch_screen, screen_name, new_state}.
  """
  def update(model, msg) do
    case {model.state, msg} do
      # Error state - just exit on Esc or Enter
      {:error, {:event, %{key: k}}} ->
        if k == key(:esc) or k == key(:enter) do
          {:switch_screen, :repl, model}
        else
          {:ok, model}
        end

      # List state - handle character input first (typeahead)
      {:list, {:event, %{ch: ?q}}} when model.filter == "" ->
        {:switch_screen, :repl, model}

      {:list, {:event, %{ch: ch}}} when ch >= 32 and ch <= 126 ->
        new_filter = model.filter <> <<ch::utf8>>
        {:ok, %{model | filter: new_filter, selected_index: 0}}

      # List state - handle navigation and special keys
      {:list, {:event, %{key: k}}} ->
        filtered = filter_components(model.components, model.filter)

        cond do
          k == key(:arrow_up) ->
            new_index = max(0, model.selected_index - 1)
            {:ok, %{model | selected_index: new_index}}

          k == key(:arrow_down) ->
            new_index = min(length(filtered) - 1, model.selected_index + 1)
            {:ok, %{model | selected_index: new_index}}

          k == key(:enter) and length(filtered) > 0 and model.selected_index < length(filtered) ->
            selected_component = Enum.at(filtered, model.selected_index)
            {:ok, %{model | state: :detail, detail_component: selected_component}}

          k == key(:backspace) or k == key(:backspace2) ->
            new_filter = String.slice(model.filter, 0..-2//1)
            {:ok, %{model | filter: new_filter, selected_index: 0}}

          k == key(:esc) ->
            {:switch_screen, :repl, model}

          true ->
            {:ok, model}
        end

      # Detail state - return to list on Esc or Enter
      {:detail, {:event, %{key: k}}} ->
        if k == key(:esc) or k == key(:enter) do
          {:ok, %{model | state: :list, detail_component: nil}}
        else
          {:ok, model}
        end

      # PubSub messages for component updates
      {_, {:created, component}} ->
        new_components = [component | model.components] |> sort_components()
        {:ok, %{model | components: new_components}}

      {_, {:updated, component}} ->
        new_components =
          model.components
          |> Enum.map(fn c -> if c.id == component.id, do: component, else: c end)
          |> sort_components()

        {:ok, %{model | components: new_components}}

      {_, {:deleted, component}} ->
        new_components = Enum.reject(model.components, &(&1.id == component.id))
        {:ok, %{model | components: new_components}}

      _ ->
        {:ok, model}
    end
  end

  @doc """
  Render the components browser screen.
  """
  def render(model) do
    case model.state do
      :error -> render_error(model)
      :list -> render_list(model)
      :detail -> render_detail(model)
    end
  end

  # Rendering functions

  defp render_error(model) do
    row do
      column(size: 12) do
        panel(title: "Components Browser - Error") do
          label(content: model.error_message, color: :red)
          label(content: "")
          label(content: "Press Esc or Enter to return to REPL")
        end
      end
    end
  end

  defp render_list(model) do
    filtered = filter_components(model.components, model.filter)
    component_count = length(model.components)
    title = "Components(#{component_count})"

    [
      # Header
      row do
        column(size: 12) do
          panel(title: title) do
            label(content: "Use ↑/↓ to navigate, Enter to view details, 'q' or Esc to exit")
          end
        end
      end,

      # Components list
      row do
        column(size: 12) do
          panel(title: "Components", height: :fill) do
            if length(filtered) == 0 do
              if model.filter == "" do
                label(
                  content: "No components found. Run /init to scan your project.",
                  color: :yellow
                )
              else
                label(content: "No matches found.", color: :yellow)
              end
            else
              viewport do
                for {component, index} <- Enum.with_index(filtered) do
                  render_component_item(component, index == model.selected_index)
                end
              end
            end
          end
        end
      end,

      # Search bar (at the bottom)
      row do
        column(size: 12) do
          label do
            text(content: "Search: ", color: :cyan)
            text(content: model.filter, attributes: [:bold])
            text(content: "_", color: :yellow)
          end
        end
      end
    ]
  end

  defp render_component_item(component, is_selected) do
    module_name = component.module_name || "Unknown"
    prefix = if is_selected, do: "▶ ", else: "  "

    label do
      text(content: prefix, attributes: if(is_selected, do: [:bold], else: []))

      text(
        content: module_name,
        attributes: if(is_selected, do: [:bold], else: []),
        color: if(is_selected, do: :cyan, else: :white)
      )
    end
  end

  defp render_detail(model) do
    component = model.detail_component

    row do
      column(size: 12) do
        panel(title: "Component Details") do
          label do
            text(content: "Module Name: ", color: :yellow)
            text(content: component.module_name || "Unknown")
          end

          label do
            text(content: "Type: ", color: :yellow)
            text(content: format_type(component.type))
          end

          if component.description do
            label do
              text(content: "Description: ", color: :yellow)
              text(content: component.description)
            end
          end

          label(content: "")
          label(content: "Press Enter or Esc to return", color: :yellow)
        end
      end
    end
  end

  # Helper functions

  defp filter_components(components, "") do
    components
  end

  defp filter_components(components, filter) do
    filter_lower = String.downcase(filter)

    components
    |> Enum.filter(fn component ->
      module_name = component.module_name || ""
      String.contains?(String.downcase(module_name), filter_lower)
    end)
  end

  defp format_type(nil), do: "Other"

  defp format_type(type) when is_atom(type) do
    type
    |> Atom.to_string()
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  defp sort_components(components) do
    Enum.sort_by(components, &{&1.type, &1.module_name})
  end
end

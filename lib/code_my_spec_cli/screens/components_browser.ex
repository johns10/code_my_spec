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
    :selected_requirement_index,
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
        selected_requirement_index: 0,
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
        selected_requirement_index: 0,
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
            # Load the component with requirements preloaded
            component_with_requirements =
              Components.get_component!(model.scope, selected_component.id)

            {:ok,
             %{
               model
               | state: :detail,
                 detail_component: component_with_requirements,
                 selected_requirement_index: 0
             }}

          k == key(:backspace) or k == key(:backspace2) ->
            new_filter = String.slice(model.filter, 0..-2//1)
            {:ok, %{model | filter: new_filter, selected_index: 0}}

          k == key(:esc) ->
            {:switch_screen, :repl, model}

          true ->
            {:ok, model}
        end

      # Detail state - navigate requirements and create sessions
      {:detail, {:event, %{key: k}}} ->
        requirements = model.detail_component.requirements || []

        cond do
          k == key(:esc) ->
            {:ok, %{model | state: :list, detail_component: nil, selected_requirement_index: 0}}

          k == key(:arrow_up) and length(requirements) > 0 ->
            new_index = max(0, model.selected_requirement_index - 1)
            {:ok, %{model | selected_requirement_index: new_index}}

          k == key(:arrow_down) and length(requirements) > 0 ->
            new_index = min(length(requirements) - 1, model.selected_requirement_index + 1)
            {:ok, %{model | selected_requirement_index: new_index}}

          k == key(:enter) and length(requirements) > 0 and
              model.selected_requirement_index < length(requirements) ->
            selected_requirement = Enum.at(requirements, model.selected_requirement_index)
            create_session_for_requirement(model, selected_requirement)

          true ->
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

  # Helper function to create a session for a requirement
  defp create_session_for_requirement(model, requirement) do
    alias CodeMySpec.Sessions

    # Determine session type from requirement's satisfied_by field
    session_type = parse_session_type(requirement.satisfied_by)

    session_attrs = %{
      type: session_type,
      agent: :claude_code,
      environment: :cli,
      execution_mode: :manual,
      component_id: model.detail_component.id,
      state: %{}
    }

    case Sessions.create_session(model.scope, session_attrs) do
      {:ok, _session} ->
        {:ok, %{model | state: :list, detail_component: nil, selected_requirement_index: 0}}

      {:error, _changeset} ->
        # If session creation fails, just return to list
        {:ok, %{model | state: :list, detail_component: nil, selected_requirement_index: 0}}
    end
  end

  # Parse the session type from the satisfied_by module name
  defp parse_session_type(nil), do: CodeMySpec.ComponentCodingSessions
  defp parse_session_type(""), do: CodeMySpec.ComponentCodingSessions

  defp parse_session_type(satisfied_by) when is_binary(satisfied_by) do
    # Extract session type from module name like "CodeMySpec.ComponentDesignSessions"
    case satisfied_by do
      "ContextSpecSessions" -> CodeMySpec.ContextSpecSessions
      "ContextComponentsDesignSessions" -> CodeMySpec.ContextComponentsDesignSessions
      "ContextDesignReviewSessions" -> CodeMySpec.ContextDesignReviewSessions
      "ContextCodingSessions" -> CodeMySpec.ContextCodingSessions
      "ContextTestingSessions" -> CodeMySpec.ContextTestingSessions
      "ComponentDesignSessions" -> CodeMySpec.ComponentDesignSessions
      "ComponentDesignReviewSessions" -> CodeMySpec.ComponentDesignReviewSessions
      "ComponentTestSessions" -> CodeMySpec.ComponentTestSessions
      "ComponentCodingSessions" -> CodeMySpec.ComponentCodingSessions
      "IntegrationSessions" -> CodeMySpec.IntegrationSessions
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
    requirements = component.requirements || []

    [
      # Component details
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
          end
        end
      end,

      # Requirements section
      row do
        column(size: 12) do
          panel(title: "Requirements (#{length(requirements)})", height: :fill) do
            if length(requirements) == 0 do
              label(content: "No requirements defined", color: :yellow)
            else
              viewport do
                for {requirement, index} <- Enum.with_index(requirements) do
                  render_requirement_item(requirement, index == model.selected_requirement_index)
                end
              end
            end
          end
        end
      end,

      # Footer
      row do
        column(size: 12) do
          label(
            content: "Use ↑/↓ to navigate requirements, Enter to create session, Esc to return",
            color: :yellow
          )
        end
      end
    ]
  end

  defp render_requirement_item(requirement, is_selected) do
    status_icon = if requirement.satisfied, do: "✓", else: "✗"
    status_color = if requirement.satisfied, do: :green, else: :red
    prefix = if is_selected, do: "▶ ", else: "  "

    label do
      text(content: prefix, attributes: if(is_selected, do: [:bold], else: []))
      text(content: "#{status_icon} ", color: status_color, attributes: [:bold])

      text(
        content: requirement.name || "Unknown",
        attributes: if(is_selected, do: [:bold], else: []),
        color: if(is_selected, do: :cyan, else: :white)
      )

      text(content: " - #{requirement.description || ""}")
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

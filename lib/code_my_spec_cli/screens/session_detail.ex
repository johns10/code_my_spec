defmodule CodeMySpecCli.Screens.SessionDetail do
  @moduledoc """
  Session detail screen for Ratatouille.

  Displays detailed information about a single session including all its interactions.
  Allows deleting individual interactions and navigating back to the sessions list.
  """

  import Ratatouille.View
  import Ratatouille.Constants, only: [key: 1]
  require Logger

  alias CodeMySpec.Sessions
  alias CodeMySpec.Sessions.{Interaction, InteractionsRepository}
  alias CodeMySpec.Users.Scope

  # Key code constants
  @arrow_up key(:arrow_up)
  @arrow_down key(:arrow_down)
  @esc key(:esc)

  defstruct [
    :scope,
    :session,
    :selected_interaction_index,
    :error_message,
    :confirm_delete,
    :delete_target_id
  ]

  @type t :: %__MODULE__{
          scope: Scope.t() | nil,
          session: Sessions.Session.t(),
          selected_interaction_index: integer(),
          error_message: String.t() | nil,
          confirm_delete: boolean(),
          delete_target_id: binary() | nil
        }

  @doc """
  Initialize the session detail screen with a session.
  """
  @spec init_with_session(Sessions.Session.t()) :: {t(), nil}
  def init_with_session(session) do
    scope = Scope.for_cli()

    # Subscribe to session updates
    Sessions.subscribe_user_sessions(scope)

    state = %__MODULE__{
      scope: scope,
      session: session,
      selected_interaction_index: 0,
      error_message: nil,
      confirm_delete: false,
      delete_target_id: nil
    }

    {state, nil}
  end

  @doc """
  Handle keyboard input and system messages.
  """
  @spec update(t(), term()) :: {:ok, t()} | {:switch_screen, atom(), t()}
  def update(model, msg) do
    case msg do
      # Arrow key navigation
      {:event, %{key: @arrow_up}} ->
        handle_arrow_up(model)

      {:event, %{key: @arrow_down}} ->
        handle_arrow_down(model)

      # 'd' key - delete interaction
      {:event, %{ch: ?d}} ->
        handle_delete_interaction(model)

      # 'y' key - confirm deletion
      {:event, %{ch: ?y}} ->
        handle_confirm_delete(model)

      # 'n' key - cancel deletion
      {:event, %{ch: ?n}} ->
        handle_cancel_delete(model)

      # 'q' or Esc key - exit to sessions list
      {:event, %{ch: ?q}} ->
        handle_exit(model)

      {:event, %{key: @esc}} ->
        handle_exit(model)

      # PubSub messages for session updates
      {:updated, session} ->
        # Check if this is our session
        if session.id == model.session.id do
          # Adjust selection index if needed
          new_index =
            if model.selected_interaction_index >= length(session.interactions) do
              max(0, length(session.interactions) - 1)
            else
              model.selected_interaction_index
            end

          {:ok, %{model | session: session, selected_interaction_index: new_index}}
        else
          {:ok, model}
        end

      {:deleted, session} ->
        # If our session was deleted, return to sessions list
        if session.id == model.session.id do
          {:switch_screen, :sessions, model}
        else
          {:ok, model}
        end

      _ ->
        {:ok, model}
    end
  end

  # Private update handlers

  defp handle_arrow_up(model) do
    new_index = max(0, model.selected_interaction_index - 1)
    {:ok, %{model | selected_interaction_index: new_index}}
  end

  defp handle_arrow_down(model) do
    new_index = min(length(model.session.interactions) - 1, model.selected_interaction_index + 1)
    {:ok, %{model | selected_interaction_index: new_index}}
  end

  defp handle_delete_interaction(model) do
    if length(model.session.interactions) > 0 &&
         model.selected_interaction_index < length(model.session.interactions) do
      interaction = Enum.at(model.session.interactions, model.selected_interaction_index)

      {:ok,
       %{
         model
         | confirm_delete: true,
           delete_target_id: interaction.id,
           error_message: "Delete this interaction? (y/n)"
       }}
    else
      {:ok, model}
    end
  end

  defp handle_confirm_delete(model) do
    if model.confirm_delete && model.delete_target_id do
      interaction = InteractionsRepository.get(model.delete_target_id)

      case InteractionsRepository.delete(interaction) do
        {:ok, _deleted} ->
          # Reload the session to get updated interactions
          updated_session = Sessions.get_session!(model.scope, model.session.id)

          # Adjust selection index
          new_index =
            if model.selected_interaction_index >= length(updated_session.interactions) do
              max(0, length(updated_session.interactions) - 1)
            else
              model.selected_interaction_index
            end

          {:ok,
           %{
             model
             | session: updated_session,
               selected_interaction_index: new_index,
               confirm_delete: false,
               delete_target_id: nil,
               error_message: nil
           }}

        {:error, reason} ->
          {:ok,
           %{
             model
             | confirm_delete: false,
               delete_target_id: nil,
               error_message: "Failed to delete interaction: #{inspect(reason)}"
           }}
      end
    else
      {:ok, model}
    end
  end

  defp handle_cancel_delete(model) do
    {:ok, %{model | confirm_delete: false, delete_target_id: nil, error_message: nil}}
  end

  defp handle_exit(model) do
    {:switch_screen, :sessions, model}
  end

  @doc """
  Render the session detail screen.
  """
  @spec render(t()) :: term()
  def render(model) do
    interaction_count = length(model.session.interactions)

    [
      # Header with session info
      row do
        column(size: 12) do
          panel(title: "Session Details") do
            [
              render_session_header(model.session),
              # Error/confirmation message
              if model.error_message do
                label(
                  content: "⚠ #{model.error_message}",
                  color: if(model.confirm_delete, do: :yellow, else: :red),
                  attributes: [:bold]
                )
              end
            ]
          end
        end
      end,
      # Interactions list
      row do
        column(size: 12) do
          panel(title: "Interactions (#{interaction_count})", height: :fill) do
            [
              # Instructions
              label(
                content: "↑/↓: navigate | d: delete | q/esc: back",
                color: :cyan
              ),
              if interaction_count == 0 do
                label(content: "No interactions in this session.", color: :yellow)
              else
                viewport do
                  for {interaction, index} <- Enum.with_index(model.session.interactions) do
                    render_interaction_item(
                      interaction,
                      index == model.selected_interaction_index
                    )
                  end
                end
              end
            ]
          end
        end
      end
    ]
  end

  # Render session header with key details
  defp render_session_header(session) do
    session_type_name =
      session.type
      |> Atom.to_string()
      |> String.split(".")
      |> List.last()
      |> Inflex.singularize()
      |> Recase.to_sentence()
      |> String.replace("session", "")
      |> String.trim()

    component_name =
      with {:ok, %{} = component} <- Map.fetch(session, :component),
           {:ok, name} <- Map.fetch(component, :name) do
        name
      else
        _ -> "component no longer exists"
      end

    status_color = status_color(session.status)

    label do
      text(content: "Type: ", attributes: [:bold])
      text(content: session_type_name)
      text(content: " | ")
      text(content: "Component: ", attributes: [:bold])
      text(content: component_name)
      text(content: " | ")
      text(content: "Status: ", attributes: [:bold])
      text(content: "#{session.status}", color: status_color)
    end
  end

  # Render a single interaction item
  defp render_interaction_item(interaction, is_selected) do
    prefix = if is_selected, do: "▶ ", else: "  "

    # Status indicator
    {status_icon, status_color} =
      cond do
        Interaction.pending?(interaction) ->
          {"⏳", :yellow}

        Interaction.successful?(interaction) ->
          {"✓", :green}

        Interaction.failed?(interaction) ->
          {"✗", :red}

        true ->
          {"○", :white}
      end

    # Command type
    command_type =
      if interaction.command do
        interaction.command.module
        |> Atom.to_string()
        |> String.split(".")
        |> List.last()
        |> Inflex.singularize()
        |> Recase.to_sentence()
      else
        "Unknown"
      end

    # Display text - show step name if it exists, otherwise just command type
    display_text =
      if interaction.step_name do
        "#{interaction.step_name} - #{command_type}"
      else
        command_type
      end

    label do
      text(
        content: prefix,
        attributes: if(is_selected, do: [:bold], else: [])
      )

      text(
        content: "[#{status_icon}] ",
        color: status_color,
        attributes: [:bold]
      )

      text(
        content: display_text,
        attributes: if(is_selected, do: [:bold], else: []),
        color: if(is_selected, do: :cyan, else: :white)
      )
    end
  end

  # Helper functions

  defp status_color(:active), do: :green
  defp status_color(:complete), do: :blue
  defp status_color(:failed), do: :red
  defp status_color(:cancelled), do: :yellow
  defp status_color(_), do: :white
end

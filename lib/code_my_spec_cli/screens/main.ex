defmodule CodeMySpecCli.Screens.Main do
  @moduledoc """
  Main application screen router.

  Routes between different screen modules:
  - :repl - Command prompt interface (Repl)
  - :init - Project initialization (Init)
  """
  @behaviour Ratatouille.App

  import Ratatouille.View

  alias CodeMySpecCli.Screens.Repl
  alias CodeMySpecCli.Screens.Init
  alias CodeMySpecCli.Screens.ComponentsBrowser
  alias CodeMySpecCli.Screens.Sessions
  alias CodeMySpecCli.Screens.SessionDetail

  defstruct [
    :screen,
    :repl_state,
    :init_state,
    :components_state,
    :sessions_state,
    :session_detail_state
  ]

  @impl true
  def init(_context) do
    %__MODULE__{
      screen: :repl,
      repl_state: Repl.init(),
      init_state: nil,
      components_state: nil,
      sessions_state: nil,
      session_detail_state: nil
    }
  end

  @impl true
  def subscribe(_model) do
    # Return an interval subscription that will trigger re-renders every 100ms
    # This allows components to fetch fresh auth/project status
    Ratatouille.Runtime.Subscription.interval(100, :tick)
  end

  @impl true
  def update(model, msg) do
    case {model.screen, msg} do
      # Tick from interval subscription - just re-render
      {_, :tick} ->
        model

      # REPL screen
      {:repl, msg} ->
        case Repl.update(model.repl_state, msg) do
          {:ok, new_repl_state} ->
            %{model | repl_state: new_repl_state}

          {:switch_screen, :init, new_repl_state} ->
            # Init.init() returns {state, command} tuple
            case Init.init() do
              {init_state, nil} ->
                %{model | screen: :init, repl_state: new_repl_state, init_state: init_state}

              {init_state, command} ->
                new_model = %{
                  model
                  | screen: :init,
                    repl_state: new_repl_state,
                    init_state: init_state
                }

                {new_model, command}
            end

          {:switch_screen, :components, new_repl_state} ->
            # ComponentsBrowser.init() returns {state, command} tuple
            case ComponentsBrowser.init() do
              {components_state, nil} ->
                %{
                  model
                  | screen: :components,
                    repl_state: new_repl_state,
                    components_state: components_state
                }
            end

          {:switch_screen, :sessions, new_repl_state} ->
            # Sessions.init() returns {state, command} tuple
            case Sessions.init() do
              {sessions_state, nil} ->
                %{
                  model
                  | screen: :sessions,
                    repl_state: new_repl_state,
                    sessions_state: sessions_state
                }
            end

          {:switch_screen, _other_screen, new_repl_state} ->
            # Generic fallback for unknown screens
            %{model | repl_state: new_repl_state}
        end

      # Init screen
      {:init, msg} ->
        case Init.update(model.init_state, msg) do
          {:ok, new_init_state} ->
            %{model | init_state: new_init_state}

          {:switch_screen, :repl, _new_init_state} ->
            %{model | screen: :repl}
        end

      # Components screen
      {:components, msg} ->
        case ComponentsBrowser.update(model.components_state, msg) do
          {:ok, new_components_state} ->
            %{model | components_state: new_components_state}

          {:switch_screen, :repl, _new_components_state} ->
            %{model | screen: :repl}
        end

      # Sessions screen
      {:sessions, msg} ->
        case Sessions.update(model.sessions_state, msg) do
          {:ok, new_sessions_state} ->
            %{model | sessions_state: new_sessions_state}

          {:switch_screen, :session_detail, new_sessions_state} ->
            # Get selected session from sessions_state
            session = Enum.at(new_sessions_state.sessions, new_sessions_state.selected_session_index)

            # Initialize detail screen with session
            case SessionDetail.init_with_session(session) do
              {detail_state, nil} ->
                %{
                  model
                  | screen: :session_detail,
                    sessions_state: new_sessions_state,
                    session_detail_state: detail_state
                }
            end

          {:switch_screen, :repl, _new_sessions_state} ->
            %{model | screen: :repl}
        end

      # Session detail screen
      {:session_detail, msg} ->
        case SessionDetail.update(model.session_detail_state, msg) do
          {:ok, new_detail_state} ->
            %{model | session_detail_state: new_detail_state}

          {:switch_screen, :sessions, _new_detail_state} ->
            # Return to sessions list
            %{model | screen: :sessions}
        end

      _ ->
        model
    end
  end

  @impl true
  def render(model) do
    view do
      panel(title: "CodeMySpec", height: :fill) do
        case model.screen do
          :repl -> Repl.render(model.repl_state)
          :init -> Init.render(model.init_state)
          :components -> ComponentsBrowser.render(model.components_state)
          :sessions -> Sessions.render(model.sessions_state)
          :session_detail -> SessionDetail.render(model.session_detail_state)
        end
      end
    end
  end
end

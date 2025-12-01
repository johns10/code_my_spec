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

  defstruct [:screen, :repl_state, :init_state, :components_state]

  @impl true
  def init(_context) do
    %__MODULE__{
      screen: :repl,
      repl_state: Repl.init(),
      init_state: nil,
      components_state: nil
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
                new_model = %{model | screen: :init, repl_state: new_repl_state, init_state: init_state}
                {new_model, command}
            end

          {:switch_screen, :components, new_repl_state} ->
            # ComponentsBrowser.init() returns {state, command} tuple
            case ComponentsBrowser.init() do
              {components_state, nil} ->
                %{model | screen: :components, repl_state: new_repl_state, components_state: components_state}

              {components_state, command} ->
                new_model = %{model | screen: :components, repl_state: new_repl_state, components_state: components_state}
                {new_model, command}
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

          {:switch_screen, _other_screen, _new_init_state} ->
            # Generic fallback
            model
        end

      # Components screen
      {:components, msg} ->
        case ComponentsBrowser.update(model.components_state, msg) do
          {:ok, new_components_state} ->
            %{model | components_state: new_components_state}

          {:switch_screen, :repl, _new_components_state} ->
            %{model | screen: :repl}

          {:switch_screen, _other_screen, _new_components_state} ->
            # Generic fallback
            model
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
        end
      end
    end
  end
end
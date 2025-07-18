defmodule CodeMySpecWeb.Live.CurrentPathHook do
  @moduledoc """
  LiveView hook to mount the current path in socket assigns.
  """
  import Phoenix.Component, only: [assign: 3]
  import Phoenix.LiveView, only: [attach_hook: 4]

  def on_mount(:default, _params, _session, socket) do
    {:cont, attach_hook(socket, :current_path, :handle_params, &assign_current_path/3)}
  end

  defp assign_current_path(_params, uri, socket) do
    {:cont, assign(socket, :current_path, URI.parse(uri).path)}
  end
end

defmodule CodeMySpecCli.WebServer.Config do
  @moduledoc """
  Configuration for the local CLI web server.

  Provides centralized access to server settings like port and URL.
  """

  @default_port 8314

  @doc """
  Get the local server port.

  Returns the port from Application environment if set, otherwise returns the default.
  """
  def local_server_port do
    Application.get_env(:code_my_spec, :cli_server_port, @default_port)
  end

  @doc """
  Get the local server base URL.

  Returns the full URL including protocol and port.
  """
  def local_server_url do
    "http://localhost:#{local_server_port()}"
  end

  @doc """
  Get the OAuth callback URL.

  Returns the full callback URL for OAuth redirects.
  """
  def oauth_callback_url do
    "#{local_server_url()}/oauth/callback"
  end
end

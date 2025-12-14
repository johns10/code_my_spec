defmodule CodeMySpecCli.WebServer do
  @moduledoc """
  Local HTTP server for OAuth callbacks and Anthropic API proxying.

  This server runs as a supervised child alongside the REPL and provides:
  - OAuth callback handling
  - Future: Anthropic API proxy for credential management
  """

  alias CodeMySpecCli.WebServer.Config

  @doc """
  Child spec for supervision tree.
  """
  def child_spec(opts) do
    port = Keyword.get(opts, :port, Config.local_server_port())

    %{
      id: __MODULE__,
      start: {Bandit, :start_link, [[plug: CodeMySpecCli.WebServer.Router, port: port]]},
      type: :worker,
      restart: :permanent
    }
  end
end

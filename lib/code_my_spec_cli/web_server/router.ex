defmodule CodeMySpecCli.WebServer.Router do
  @moduledoc """
  Router for the local web server.

  Handles:
  - OAuth callbacks
  - Future: Anthropic API proxying
  """
  use Plug.Router
  require EEx

  alias CodeMySpecCli.Auth.OAuthClient

  plug(:match)
  plug(:dispatch)

  # Compile templates at build time
  @templates_dir Path.join([__DIR__, "templates"])
  @success_template Path.join(@templates_dir, "oauth_success.html.eex")
  @error_template Path.join(@templates_dir, "oauth_error.html.eex")

  EEx.function_from_file(:defp, :render_success, @success_template, [])
  EEx.function_from_file(:defp, :render_error, @error_template, [:error])

  get "/oauth/callback" do
    conn = fetch_query_params(conn)

    case conn.query_params do
      %{"code" => code, "state" => state} ->
        # Notify any waiting OAuth processes
        OAuthClient.handle_callback({:ok, code, state})
        send_success_response(conn)

      %{"error" => error} ->
        OAuthClient.handle_callback({:error, error})
        send_error_response(conn, error)

      _ ->
        OAuthClient.handle_callback({:error, "invalid_callback"})
        send_error_response(conn, "Invalid callback parameters")
    end
  end

  match _ do
    send_resp(conn, 404, "Not Found")
  end

  defp send_success_response(conn) do
    conn
    |> put_resp_content_type("text/html")
    |> send_resp(200, render_success())
  end

  defp send_error_response(conn, error) do
    conn
    |> put_resp_content_type("text/html")
    |> send_resp(400, render_error(error))
  end
end

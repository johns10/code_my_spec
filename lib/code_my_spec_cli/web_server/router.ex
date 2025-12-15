defmodule CodeMySpecCli.WebServer.Router do
  @moduledoc """
  Router for the local web server.

  Handles:
  - OAuth callbacks
  - Future: Anthropic API proxying
  """
  use Plug.Router
  require EEx
  require Logger

  alias CodeMySpecCli.Auth.OAuthClient

  plug(:match)
  plug(Plug.Parsers, parsers: [:json], json_decoder: Jason)
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

  post "/sessions/:session_id/hooks" do
    handle_hook(conn, conn.path_params["session_id"])
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

  defp handle_hook(conn, session_id) do
    case CodeMySpec.Users.Scope.for_cli() do
      nil ->
        Logger.warning("Hook received but no CLI scope available (project not initialized)")

        conn
        |> put_resp_content_type("application/json")
        |> send_resp(503, Jason.encode!(%{status: "error", error: "CLI not initialized"}))

      scope ->
        process_hook(conn, scope, session_id)
    end
  end

  defp process_hook(conn, scope, _session_id) do
    with %{"hook_name" => hook_name, "hook_data" => hook_data, "interaction_id" => interaction_id} <- conn.body_params,
         {:ok, _session} <- add_hook_event(scope, interaction_id, hook_name, hook_data) do
      Logger.debug("Successfully processed hook #{hook_name} for interaction #{interaction_id}")

      conn
      |> put_resp_content_type("application/json")
      |> send_resp(200, Jason.encode!(%{status: "ok"}))
    else
      {:error, :interaction_not_found} ->
        Logger.warning("Hook received for non-existent interaction")

        conn
        |> put_resp_content_type("application/json")
        |> send_resp(404, Jason.encode!(%{status: "error", error: "Interaction not found"}))

      {:error, reason} ->
        Logger.error("Failed to process hook: #{inspect(reason)}")

        conn
        |> put_resp_content_type("application/json")
        |> send_resp(500, Jason.encode!(%{status: "error", error: inspect(reason)}))

      nil ->
        Logger.warning("Hook received with invalid payload format")

        conn
        |> put_resp_content_type("application/json")
        |> send_resp(400, Jason.encode!(%{status: "error", error: "Invalid payload"}))
    end
  end

  defp add_hook_event(scope, interaction_id, hook_name, hook_data) do
    # Build event attributes in the format expected by EventHandler
    event_attrs = %{
      event_type: hook_name,
      sent_at: hook_data["timestamp"] || DateTime.utc_now(),
      data: hook_data
    }

    CodeMySpec.Sessions.EventHandler.handle_event(scope, interaction_id, event_attrs)
  end
end

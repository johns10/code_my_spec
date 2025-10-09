defmodule CodeMySpecWeb.SessionsController do
  use CodeMySpecWeb, :controller

  alias CodeMySpec.Sessions

  action_fallback CodeMySpecWeb.FallbackController

  def index(conn, params) do
    scope = conn.assigns.current_scope

    opts =
      case params["status"] do
        nil ->
          []

        status when is_binary(status) ->
          [status: [String.to_existing_atom(status)]]

        statuses when is_list(statuses) ->
          [status: Enum.map(statuses, &String.to_existing_atom/1)]
      end

    sessions = Sessions.list_sessions(scope, opts)
    render(conn, :index, sessions: sessions)
  end

  def show(conn, %{"id" => id}) do
    scope = conn.assigns.current_scope

    case Sessions.get_session(scope, id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> send_resp(404, "Not Found")

      session ->
        render(conn, :show, session: session)
    end
  end

  def create(conn, %{"session" => session_params}) do
    scope = conn.assigns.current_scope

    with {:ok, session} <- Sessions.create_session(scope, session_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/api/sessions/#{session}")
      |> render(:show, session: session)
    end
  end

  def next_command(conn, %{"sessions_id" => session_id}) do
    scope = conn.assigns.current_scope

    case Sessions.next_command(scope, session_id) do
      {:ok, session} ->
        render(conn, :show, session: session)

      {:error, :session_not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{status: "not_found", error: "Session not found"})

      {:error, :complete} ->
        session = Sessions.get_session(scope, session_id)
        render(conn, :show, session: session)

      {:error, :failed} ->
        session = Sessions.get_session(scope, session_id)
        render(conn, :show, session: session)
    end
  end

  def submit_result(conn, %{
        "sessions_id" => session_id,
        "interaction_id" => interaction_id,
        "result" => result
      }) do
    scope = conn.assigns.current_scope

    with {:ok, session} <- Sessions.handle_result(scope, session_id, interaction_id, result) do
      render(conn, :show, session: session)
    else
      {:error, :session_not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{status: "not_found", error: "Session not found"})

      {:error, :interaction_not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{status: "not_found", error: "Interaction not found"})
    end
  end

  def cancel(conn, %{"id" => id}) do
    scope = conn.assigns.current_scope

    case Sessions.get_session(scope, id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{status: "not_found", error: "Session not found"})

      session ->
        with {:ok, session} <- Sessions.update_session(scope, session, %{status: :cancelled}) do
          render(conn, :show, session: session)
        end
    end
  end
end

defmodule CodeMySpecWeb.UserController do
  @moduledoc """
  API controller for user information.
  """

  use CodeMySpecWeb, :controller

  @doc """
  GET /api/me
  Returns the current authenticated user's information.
  """
  def me(conn, _params) do
    case conn.assigns[:current_scope] do
      %{user: user} when not is_nil(user) ->
        json(conn, %{
          id: user.id,
          email: user.email
        })

      _ ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "unauthorized"})
    end
  end
end

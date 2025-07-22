defmodule CodeMySpecWeb.OAuthController do
  @moduledoc """
  OAuth2 Authorization Server Controller

  Handles OAuth2 authorization flow for MCP clients.
  """

  use CodeMySpecWeb, :controller

  alias ExOauth2Provider.{Authorization, Token}

  @doc """
  GET /oauth/authorize
  Shows the authorization page to the user
  """
  def authorize(conn, params) do
    case conn.assigns[:current_scope] do
      nil ->
        # User not authenticated, redirect to login with return path
        conn
        |> put_session(:oauth_params, params)
        |> redirect(to: ~p"/users/log-in")

      scope ->
        case Authorization.preauthorize(scope.user, params, otp_app: :code_my_spec) do
          {:ok, client, scopes} ->
            render(conn, :authorize, client: client, scopes: scopes)

          {:redirect, redirect_uri} ->
            redirect(conn, external: redirect_uri)

          {:native_redirect, payload} ->
            json(conn, payload)

          {:error, error, http_status} ->
            conn
            |> put_status(http_status)
            |> put_flash(:error, "OAuth authorization error: #{inspect(error)}")
            |> redirect(to: ~p"/")
        end
    end
  end

  @doc """
  POST /oauth/authorize
  Handles the user's authorization decision
  """
  def create(conn, %{"authorization" => auth_params} = params) do
    case conn.assigns[:current_scope] do
      nil ->
        conn
        |> put_flash(:error, "Authentication required")
        |> redirect(to: ~p"/users/log-in")

      scope ->
        case Authorization.authorize(scope.user, params, otp_app: :code_my_spec) do
          {:redirect, redirect_uri} ->
            redirect(conn, external: redirect_uri)

          {:native_redirect, payload} ->
            json(conn, payload)

          {:error, error, http_status} ->
            conn
            |> put_status(http_status)
            |> put_flash(:error, "Authorization failed: #{inspect(error)}")
            |> redirect(to: ~p"/oauth/authorize?" <> URI.encode_query(auth_params))
        end
    end
  end

  @doc """
  DELETE /oauth/authorize
  Handles authorization denial
  """
  def delete(conn, params) do
    case conn.assigns[:current_scope] do
      nil ->
        conn
        |> put_flash(:error, "Authentication required")
        |> redirect(to: ~p"/users/log-in")

      scope ->
        case Authorization.deny(scope.user, params, otp_app: :code_my_spec) do
          {:redirect, redirect_uri} ->
            redirect(conn, external: redirect_uri)

          {:error, error, http_status} ->
            conn
            |> put_status(http_status)
            |> put_flash(:error, "Authorization denial failed: #{inspect(error)}")
            |> redirect(to: ~p"/")
        end
    end
  end

  @doc """
  POST /oauth/token
  Handles token requests (authorization code exchange, refresh tokens)
  """
  def token(conn, params) do
    case Token.grant(params, otp_app: :code_my_spec) do
      {:ok, access_token} ->
        json(conn, %{
          access_token: access_token.access_token,
          refresh_token: access_token.refresh_token,
          expires_in: access_token.expires_in,
          token_type: "Bearer",
          scope: access_token.scope
        })

      {:error, error, http_status} ->
        conn
        |> put_status(http_status)
        |> json(%{error: "invalid_request", error_description: inspect(error)})
    end
  end

  @doc """
  POST /oauth/revoke
  Handles token revocation
  """
  def revoke(conn, params) do
    case Token.revoke(params, otp_app: :code_my_spec) do
      {:ok, _} ->
        conn
        |> put_status(:ok)
        |> json(%{})

      {:error, error, http_status} ->
        conn
        |> put_status(http_status)
        |> json(%{error: "invalid_request", error_description: inspect(error)})
    end
  end
end

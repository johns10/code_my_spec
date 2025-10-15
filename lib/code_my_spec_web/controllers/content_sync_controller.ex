defmodule CodeMySpecWeb.ContentSyncController do
  @moduledoc """
  Controller for handling content synchronization from server to client appliances.

  This endpoint receives content pushed from the CodeMySpec SaaS server to client
  appliances. It validates the deployment key before accepting content.
  """

  use CodeMySpecWeb, :controller

  alias CodeMySpec.Content

  action_fallback CodeMySpecWeb.FallbackController

  @doc """
  Handles content sync POST requests from the server.

  Validates the deployment key against the DEPLOY_KEY environment variable,
  then processes the content payload.

  ## Expected Payload

      %{
        "content" => [%{slug, title, content_type, ...}, ...],
        "synced_at" => ISO8601 datetime
      }

  ## Authentication

  Requires Bearer token in Authorization header matching DEPLOY_KEY env var.
  """
  def sync(conn, %{"content" => content_list, "synced_at" => _synced_at}) do
    with :ok <- validate_deploy_key(conn),
         {:ok, _result} <- sync_content(content_list) do
      conn
      |> put_status(:ok)
      |> json(%{
        status: "success",
        synced_count: length(content_list),
        message: "Content synced successfully"
      })
    else
      {:error, :unauthorized} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{status: "error", error: "Invalid deployment key"})

      {:error, :missing_deploy_key} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{status: "error", error: "Missing deployment key"})

      {:error, :deploy_key_not_configured} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{status: "error", error: "Deploy key not configured on server"})

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{status: "error", error: inspect(reason)})
    end
  end

  def sync(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{status: "error", error: "Missing required parameters: content, synced_at"})
  end

  # ============================================================================
  # Private Functions - Authentication
  # ============================================================================

  @spec validate_deploy_key(Plug.Conn.t()) :: :ok | {:error, atom()}
  defp validate_deploy_key(conn) do
    with {:ok, expected_key} <- get_expected_deploy_key(),
         {:ok, provided_key} <- extract_bearer_token(conn) do
      if secure_compare(expected_key, provided_key) do
        :ok
      else
        {:error, :unauthorized}
      end
    end
  end

  @spec get_expected_deploy_key() :: {:ok, String.t()} | {:error, :deploy_key_not_configured}
  defp get_expected_deploy_key do
    case Application.get_env(:code_my_spec, :deploy_key) do
      nil -> {:error, :deploy_key_not_configured}
      "" -> {:error, :deploy_key_not_configured}
      key -> {:ok, key}
    end
  end

  @spec extract_bearer_token(Plug.Conn.t()) :: {:ok, String.t()} | {:error, :missing_deploy_key}
  defp extract_bearer_token(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] -> {:ok, token}
      _ -> {:error, :missing_deploy_key}
    end
  end

  @spec secure_compare(String.t(), String.t()) :: boolean()
  defp secure_compare(left, right) do
    # Use constant-time comparison to prevent timing attacks
    if byte_size(left) == byte_size(right) do
      Plug.Crypto.secure_compare(left, right)
    else
      # Still do a comparison to maintain constant time
      Plug.Crypto.secure_compare(left, left)
      false
    end
  end

  # ============================================================================
  # Private Functions - Content Sync
  # ============================================================================

  @spec sync_content([map()]) :: {:ok, term()} | {:error, term()}
  defp sync_content(content_list) do
    Content.sync_content(content_list)
  end
end

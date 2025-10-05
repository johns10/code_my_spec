defmodule CodeMySpecWeb.IntegrationsController do
  @moduledoc """
  Handles OAuth provider integration flows.

  ## Request Phase
  - User clicks "Connect GitHub" button
  - `request/2` generates authorization URL and stores session params
  - User is redirected to provider for consent

  ## Callback Phase
  - Provider redirects back with authorization code
  - `callback/2` exchanges code for tokens
  - Integration is created/updated with encrypted credentials
  - User is redirected to integrations page

  ## Error Handling
  - OAuth errors from provider (e.g., access_denied) are displayed to user
  - Technical errors are logged and shown as generic error messages
  """

  use CodeMySpecWeb, :controller

  alias CodeMySpec.Integrations
  alias CodeMySpec.Users.Scope

  require Logger

  @doc """
  Initiates OAuth flow by redirecting to provider authorization URL.

  Session params from Assent are stored in Phoenix session for callback verification.
  """
  def request(conn, %{"provider" => provider_str}) do
    provider = String.to_existing_atom(provider_str)

    case Integrations.authorize_url(provider) do
      {:ok, %{url: url, session_params: session_params}} ->
        conn
        |> put_session(:oauth_session_params, session_params)
        |> put_session(:oauth_provider, provider)
        |> redirect(external: url)

      {:error, reason} ->
        Logger.error("Failed to generate OAuth URL for #{provider}: #{inspect(reason)}")

        conn
        |> put_flash(:error, "Failed to connect to #{provider_name(provider)}")
        |> redirect(to: ~p"/users/settings")
    end
  end

  @doc """
  Handles OAuth callback from provider.

  Retrieves session params stored during request phase and exchanges
  authorization code for access token. Creates or updates integration.
  """
  def callback(conn, params) do
    provider = get_session(conn, :oauth_provider)
    session_params = get_session(conn, :oauth_session_params) || %{}
    scope = conn.assigns.current_scope

    conn =
      conn
      |> delete_session(:oauth_session_params)
      |> delete_session(:oauth_provider)

    case handle_oauth_callback(scope, provider, params, session_params) do
      {:ok, _integration} ->
        conn
        |> put_flash(:info, "Successfully connected to #{provider_name(provider)}")
        |> redirect(to: ~p"/users/settings")

      {:error, %Ecto.Changeset{} = changeset} ->
        Logger.error("Failed to persist integration: #{inspect(changeset)}")

        conn
        |> put_flash(:error, "Failed to save integration")
        |> redirect(to: ~p"/users/settings")

      {:error, reason} ->
        Logger.error("OAuth callback failed for #{provider}: #{inspect(reason)}")

        error_message = format_oauth_error(params, reason)

        conn
        |> put_flash(:error, error_message)
        |> redirect(to: ~p"/users/settings")
    end
  end

  @doc """
  Removes integration connection.
  """
  def delete(conn, %{"provider" => provider_str}) do
    provider = String.to_existing_atom(provider_str)
    scope = conn.assigns.current_scope

    case Integrations.delete_integration(scope, provider) do
      {:ok, _integration} ->
        conn
        |> put_flash(:info, "Disconnected from #{provider_name(provider)}")
        |> redirect(to: ~p"/users/settings")

      {:error, :not_found} ->
        conn
        |> put_flash(:error, "No connection found for #{provider_name(provider)}")
        |> redirect(to: ~p"/users/settings")
    end
  end

  # Private Helpers

  defp handle_oauth_callback(nil, _provider, _params, _session_params) do
    {:error, :not_authenticated}
  end

  defp handle_oauth_callback(%Scope{} = scope, provider, params, session_params) do
    # Check for OAuth error in callback params
    case Map.get(params, "error") do
      nil ->
        Integrations.handle_callback(scope, provider, params, session_params)

      error ->
        {:error, error}
    end
  end

  defp format_oauth_error(%{"error" => "access_denied"}, _reason) do
    "You denied access. Please try again if you want to connect."
  end

  defp format_oauth_error(%{"error" => error, "error_description" => description}, _reason) do
    "OAuth error: #{description} (#{error})"
  end

  defp format_oauth_error(%{"error" => error}, _reason) do
    "OAuth error: #{error}"
  end

  defp format_oauth_error(_params, :not_authenticated) do
    "You must be logged in to connect integrations"
  end

  defp format_oauth_error(_params, :unsupported_provider) do
    "This provider is not supported"
  end

  defp format_oauth_error(_params, _reason) do
    "Failed to complete OAuth flow. Please try again."
  end

  defp provider_name(:github), do: "GitHub"
  defp provider_name(:gitlab), do: "GitLab"
  defp provider_name(:bitbucket), do: "Bitbucket"
  defp provider_name(provider), do: to_string(provider)
end

defmodule CodeMySpecCli.Auth.OAuthClient do
  @moduledoc """
  OAuth2 client for CLI authentication.

  Implements authorization code flow with PKCE using a local server
  to handle the callback.
  """

  require Logger

  alias CodeMySpecCli.Auth.Strategy

  @callback_port 8314
  @callback_path "/oauth/callback"
  @token_file ".codemyspec_token"
  @client_config_file ".codemyspec_client"

  @doc """
  Authenticate the user via OAuth2 authorization code flow with PKCE.

  Opens the user's browser and waits for the callback from the local server.
  Returns an access token on success.
  """
  def authenticate(opts \\ []) do
    server_base_url = opts[:server_url] || get_server_url()

    # Get or register OAuth client
    {:ok, client_id, client_secret} = get_or_register_client(server_base_url)

    # Create OAuth2 client with PKCE
    {code_verifier, code_challenge} = generate_pkce_pair()
    state = generate_state()

    client =
      OAuth2.Client.new(
        strategy: Strategy,
        client_id: client_id,
        client_secret: client_secret,
        site: server_base_url,
        authorize_url: "#{server_base_url}/oauth/authorize",
        token_url: "#{server_base_url}/oauth/token",
        redirect_uri: "http://localhost:#{@callback_port}#{@callback_path}",
        request_opts: build_hackney_opts(server_base_url)
      )

    # Build authorization URL with PKCE
    auth_url =
      OAuth2.Client.authorize_url!(client,
        scope: "read write",
        code_challenge: code_challenge,
        code_challenge_method: "S256",
        state: state
      )

    IO.puts("\n🔐 Opening browser for authentication...")
    IO.puts("If the browser doesn't open, visit: #{auth_url}\n")

    # Register this process to receive the callback
    Registry.register(CodeMySpecCli.Registry, {:oauth_waiting, state}, nil)

    # Open browser
    open_browser(auth_url)

    # Wait for callback
    result =
      receive do
        {:oauth_callback, {:ok, code, ^state}} ->
          IO.puts("✓ Authorization received")

          # Exchange code for token
          params = [
            code: code,
            code_verifier: code_verifier,
            client_id: client_id,
            client_secret: client_secret,
            grant_type: "authorization_code",
            redirect_uri: client.redirect_uri
          ]

          case OAuth2.Client.get_token(client, params) do
            {:ok, %OAuth2.Client{token: token}} ->
              token_data = %{
                "access_token" => token.access_token,
                "refresh_token" => token.refresh_token,
                "expires_in" => token.expires_at,
                "token_type" => token.token_type,
                "scope" => token.other_params["scope"]
              }

              save_token(token_data)
              IO.puts("✓ Authentication successful!\n")
              {:ok, token_data}

            {:error, %OAuth2.Error{reason: reason}} ->
              {:error, "Token exchange failed: #{inspect(reason)}"}

            {:error, %OAuth2.Response{status_code: status, body: body}} ->
              {:error, "Token exchange failed (#{status}): #{inspect(body)}"}
          end

        {:oauth_callback, {:error, error}} ->
          {:error, "OAuth authorization failed: #{error}"}
      after
        120_000 ->
          {:error, "Timeout waiting for authorization"}
      end

    # Unregister
    Registry.unregister(CodeMySpecCli.Registry, {:oauth_waiting, state})

    result
  end

  @doc """
  Called by the local server when an OAuth callback is received.
  Notifies the waiting process.
  """
  def handle_callback({:ok, code, state}) do
    case Registry.lookup(CodeMySpecCli.Registry, {:oauth_waiting, state}) do
      [{pid, _}] -> send(pid, {:oauth_callback, {:ok, code, state}})
      [] -> Logger.warning("No process waiting for OAuth callback with state: #{state}")
    end
  end

  def handle_callback({:error, error}) do
    # For errors, we don't have the state, so we can't target a specific process
    # Just log it for now
    Logger.error("OAuth callback error: #{error}")
  end

  @doc """
  Get a valid access token, refreshing if necessary.
  """
  def get_token do
    case load_token() do
      {:ok, token_data} ->
        if token_expired?(token_data) do
          refresh_token(token_data)
        else
          {:ok, token_data["access_token"]}
        end

      :error ->
        {:error, :not_authenticated}
    end
  end

  @doc """
  Check if user is authenticated.
  """
  def authenticated? do
    case get_token() do
      {:ok, _token} -> true
      {:error, _} -> false
    end
  end

  @doc """
  Clear stored credentials.
  """
  def logout do
    token_path = Path.join(System.user_home!(), @token_file)
    File.rm(token_path)
    IO.puts("✓ Logged out successfully")
    :ok
  end

  # Private functions

  defp get_or_register_client(server_base_url) do
    config_path = Path.join(System.user_home!(), @client_config_file)

    case File.read(config_path) do
      {:ok, content} ->
        data = Jason.decode!(content)

        # Check if client is for the same server
        if data["server_url"] == server_base_url do
          {:ok, data["client_id"], data["client_secret"]}
        else
          register_new_client(config_path, server_base_url)
        end

      {:error, _} ->
        register_new_client(config_path, server_base_url)
    end
  end

  defp register_new_client(config_path, server_base_url) do
    registration_params = %{
      client_name: "CodeMySpec CLI",
      redirect_uris: ["http://localhost:#{@callback_port}#{@callback_path}"]
    }

    url = "#{server_base_url}/oauth/register"
    req_opts = build_req_opts(server_base_url)

    case Req.post(url, Keyword.merge([json: registration_params], req_opts)) do
      {:ok, %{status: 201, body: body}} ->
        client_id = body["client_id"]
        client_secret = body["client_secret"]

        # Save for future use
        File.write!(
          config_path,
          Jason.encode!(%{
            server_url: server_base_url,
            client_id: client_id,
            client_secret: client_secret
          })
        )

        File.chmod!(config_path, 0o600)

        {:ok, client_id, client_secret}

      {:ok, %{status: status, body: body}} when is_binary(body) ->
        # Handle HTML error responses (like ngrok errors)
        if String.contains?(body, "<!DOCTYPE html>") do
          raise "Server is not reachable at #{server_base_url}. Is the Phoenix server running?"
        else
          raise "Client registration failed (HTTP #{status}): #{String.slice(body, 0, 200)}"
        end

      {:ok, response} ->
        raise "Client registration failed (HTTP #{response.status}): #{inspect(response.body)}"

      {:error, %Mint.TransportError{reason: :econnrefused}} ->
        raise "Cannot connect to server at #{server_base_url}. Is the Phoenix server running?"

      {:error, reason} ->
        raise "Failed to connect to server at #{server_base_url}: #{inspect(reason)}"
    end
  end

  defp refresh_token(token_data) do
    case token_data["refresh_token"] do
      nil ->
        # No refresh token, need to re-authenticate
        {:error, :needs_authentication}

      refresh_token ->
        server_base_url = get_server_url()
        {:ok, client_id, client_secret} = get_or_register_client(server_base_url)

        client =
          OAuth2.Client.new(
            strategy: Strategy,
            client_id: client_id,
            client_secret: client_secret,
            site: server_base_url,
            token_url: "#{server_base_url}/oauth/token"
          )

        params = [
          refresh_token: refresh_token,
          grant_type: "refresh_token",
          client_id: client_id,
          client_secret: client_secret
        ]

        case OAuth2.Client.get_token(client, params) do
          {:ok, %OAuth2.Client{token: token}} ->
            new_token_data = %{
              "access_token" => token.access_token,
              "refresh_token" => token.refresh_token || refresh_token,
              "expires_in" => token.expires_at,
              "token_type" => token.token_type,
              "scope" => token.other_params["scope"]
            }

            save_token(new_token_data)
            {:ok, new_token_data["access_token"]}

          {:error, _} ->
            {:error, :needs_authentication}
        end
    end
  end

  defp save_token(token_data) do
    token_path = Path.join(System.user_home!(), @token_file)

    enriched_data = Map.put(token_data, "fetched_at", System.system_time(:second))

    File.write!(token_path, Jason.encode!(enriched_data))
    File.chmod!(token_path, 0o600)
  end

  defp load_token do
    token_path = Path.join(System.user_home!(), @token_file)

    case File.read(token_path) do
      {:ok, content} ->
        {:ok, Jason.decode!(content)}

      {:error, _} ->
        :error
    end
  end

  defp token_expired?(token_data) do
    case token_data["expires_in"] do
      nil ->
        # No expiration data, consider it expired
        true

      expires_at ->
        current_time = System.system_time(:second)
        # Consider expired if less than 5 minutes remaining
        current_time >= expires_at - 300
    end
  end

  defp generate_pkce_pair do
    code_verifier = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)

    code_challenge =
      :crypto.hash(:sha256, code_verifier)
      |> Base.url_encode64(padding: false)

    {code_verifier, code_challenge}
  end

  defp generate_state do
    :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)
  end

  defp open_browser(url) do
    case :os.type() do
      {:unix, :darwin} -> System.cmd("open", [url])
      {:unix, _} -> System.cmd("xdg-open", [url])
      {:win32, _} -> System.cmd("cmd", ["/c", "start", url])
    end
  end

  defp get_server_url do
    Application.get_env(:code_my_spec, :oauth_base_url, "http://localhost:4000")
  end

  # Build Req options for HTTP requests (used for registration)
  defp build_req_opts(server_url) do
    if String.starts_with?(server_url, "https://localhost") do
      # For local HTTPS with self-signed certs, disable verification
      [connect_options: [transport_opts: [verify: :verify_none]]]
    else
      []
    end
  end

  # Build hackney options for OAuth2 library (used for token exchange)
  defp build_hackney_opts(server_url) do
    if String.starts_with?(server_url, "https://localhost") do
      # For local HTTPS with self-signed certs, disable verification
      [ssl_options: [{:verify, :verify_none}]]
    else
      []
    end
  end
end

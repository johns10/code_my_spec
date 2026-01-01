defmodule CodeMySpecCli.Auth.OAuthClient do
  @moduledoc """
  OAuth2 client for CLI authentication.

  Implements authorization code flow with PKCE using a local server
  to handle the callback.
  """

  require Logger

  alias CodeMySpecCli.Auth.Strategy
  alias CodeMySpecCli.WebServer.Config

  @client_config_file ".codemyspec_client"

  @doc """
  Authenticate with UI notifications.

  Returns the auth URL that will be opened in the browser.
  """
  def authenticate_with_ui(opts \\ []) do
    server_base_url = opts[:server_url] || get_server_url()
    {:ok, client_id, _client_secret} = get_or_register_client(server_base_url)

    # Generate PKCE for the auth URL
    {_code_verifier, code_challenge} = generate_pkce_pair()
    state = generate_state()

    # Build auth URL
    redirect_uri = Config.oauth_callback_url()

    auth_url =
      "#{server_base_url}/oauth/authorize?" <>
        "client_id=#{client_id}" <>
        "&code_challenge=#{code_challenge}" <>
        "&code_challenge_method=S256" <>
        "&redirect_uri=#{URI.encode_www_form(redirect_uri)}" <>
        "&response_type=code" <>
        "&scope=read+write" <>
        "&state=#{state}"

    # Continue with normal authentication (this will block)
    result = authenticate(opts)

    # Return both the URL and the result
    {auth_url, result}
  end

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
        redirect_uri: Config.oauth_callback_url(),
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

    # Register this process to receive the callback
    Registry.register(CodeMySpecCli.Registry, {:oauth_waiting, state}, nil)

    # Open browser (silently - TUI will show the URL)
    open_browser(auth_url)

    # Wait for callback
    result =
      receive do
        {:oauth_callback, {:ok, code, ^state}} ->
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
              Logger.debug("OAuth token received: #{token.scope}")

              # The OAuth2 library sometimes returns the JSON response as a string in access_token
              # Parse it if needed
              {access_token, refresh_token, expires_in, scope} =
                case Jason.decode(token.access_token) do
                  {:ok, parsed} ->
                    {parsed["access_token"], parsed["refresh_token"], parsed["expires_in"],
                     parsed["scope"]}

                  {:error, _} ->
                    # Already parsed correctly
                    {token.access_token, token.refresh_token, token.expires_at,
                     token.other_params["scope"]}
                end

              token_data = %{
                "access_token" => access_token,
                "refresh_token" => refresh_token,
                "expires_in" => expires_in,
                "token_type" => token.token_type,
                "scope" => scope
              }

              # Fetch and save user info (this also saves the token to DB)
              with {:ok, %{id: user_id, email: email}} <-
                     fetch_user_info(server_base_url, access_token),
                   {:ok, _client_user} <- save_client_user(user_id, email, token_data),
                   :ok <- CodeMySpecCli.Config.set_current_user_email(email) do
                # Broadcast auth status change (TUI will update automatically)
                Phoenix.PubSub.broadcast(CodeMySpec.PubSub, "cli:auth", {:auth_changed, true})
              else
                {:error, _reason} ->
                  # Still broadcast success even if there was a warning
                  Phoenix.PubSub.broadcast(CodeMySpec.PubSub, "cli:auth", {:auth_changed, true})
              end

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
  Get a valid access token from the database, refreshing if necessary.
  """
  def get_token do
    case get_current_user() do
      {:ok, user} ->
        if token_expired?(user) do
          refresh_token_for_user(user)
        else
          {:ok, user.oauth_token}
        end

      {:error, _} ->
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
  Clear stored credentials from database.
  """
  def logout do
    case get_current_user() do
      {:ok, user} ->
        user
        |> CodeMySpec.ClientUsers.ClientUser.changeset(%{
          oauth_token: nil,
          oauth_refresh_token: nil,
          oauth_expires_at: nil
        })
        |> CodeMySpec.Repo.update()

        CodeMySpecCli.Config.clear_current_user_email()

        # Broadcast auth status change (TUI will update automatically)
        Phoenix.PubSub.broadcast(CodeMySpec.PubSub, "cli:auth", {:auth_changed, false})

        :ok

      {:error, _} ->
        :ok
    end
  end

  # Private functions

  defp get_current_user do
    case CodeMySpecCli.Config.get_current_user_email() do
      {:ok, email} ->
        case CodeMySpec.Repo.get_by(CodeMySpec.ClientUsers.ClientUser, email: email) do
          nil -> {:error, :not_found}
          user -> {:ok, user}
        end

      {:error, _} ->
        {:error, :no_current_user}
    end
  end

  def get_or_register_client(server_base_url) do
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
      redirect_uris: [Config.oauth_callback_url()]
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

  defp refresh_token_for_user(user) do
    case user.oauth_refresh_token do
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
            # Parse JSON if needed (same as authenticate/1)
            {access_token, new_refresh_token, expires_in, _scope} =
              case Jason.decode(token.access_token) do
                {:ok, parsed} ->
                  {parsed["access_token"], parsed["refresh_token"], parsed["expires_in"],
                   parsed["scope"]}

                {:error, _} ->
                  {token.access_token, token.refresh_token, token.expires_at,
                   token.other_params["scope"]}
              end

            # Update user in database with new tokens
            token_data = %{
              "access_token" => access_token,
              "refresh_token" => new_refresh_token || refresh_token,
              "expires_in" => expires_in
            }

            case save_client_user(user.id, user.email, token_data) do
              {:ok, _} -> {:ok, access_token}
              {:error, _} -> {:error, :needs_authentication}
            end

          {:error, _} ->
            {:error, :needs_authentication}
        end
    end
  end

  defp token_expired?(%CodeMySpec.ClientUsers.ClientUser{oauth_expires_at: nil}), do: true

  defp token_expired?(%CodeMySpec.ClientUsers.ClientUser{oauth_expires_at: expires_at}) do
    # Consider expired if less than 5 minutes remaining
    DateTime.compare(DateTime.utc_now(), DateTime.add(expires_at, -300, :second)) == :gt
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

  def get_server_url do
    Application.get_env(:code_my_spec, :oauth_base_url, "http://localhost:4000")
  end

  defp save_client_user(user_id, email, token_data) do
    attrs = %{
      id: user_id,
      email: email,
      oauth_token: token_data["access_token"],
      oauth_refresh_token: token_data["refresh_token"],
      oauth_expires_at: DateTime.add(DateTime.utc_now(), token_data["expires_in"], :second)
    }

    # Try to find existing user by ID or email
    case CodeMySpec.Repo.get(CodeMySpec.ClientUsers.ClientUser, user_id) do
      nil ->
        # Create new user
        %CodeMySpec.ClientUsers.ClientUser{}
        |> CodeMySpec.ClientUsers.ClientUser.changeset(attrs)
        |> CodeMySpec.Repo.insert()

      existing_user ->
        # Update existing user
        existing_user
        |> CodeMySpec.ClientUsers.ClientUser.changeset(attrs)
        |> CodeMySpec.Repo.update()
    end
  end

  defp fetch_user_info(server_base_url, access_token) do
    url = "#{server_base_url}/api/me"
    req_opts = build_req_opts(server_base_url)

    headers = [{"authorization", "Bearer #{access_token}"}]

    Logger.debug(
      "Fetching user info from #{url} with token: #{String.slice(access_token, 0..10)}..."
    )

    case Req.get(url, Keyword.merge([headers: headers], req_opts)) do
      {:ok, %{status: 200, body: %{"id" => id, "email" => email}}} ->
        {:ok, %{id: id, email: email}}

      {:ok, %{status: status, body: body}} ->
        Logger.debug("Failed to fetch user info (HTTP #{status}): #{inspect(body)}")
        {:error, "Failed to fetch user info (HTTP #{status})"}

      {:error, reason} ->
        {:error, reason}
    end
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

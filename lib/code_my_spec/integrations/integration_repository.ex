defmodule CodeMySpec.Integrations.IntegrationRepository do
  @moduledoc """
  Data access layer for Integration CRUD operations filtered by user_id.

  All operations are scoped to the user provided in the Scope struct, ensuring
  multi-tenant isolation and preventing unauthorized access to OAuth credentials.
  Cloak handles automatic encryption/decryption of access_token and refresh_token.
  """

  import Ecto.Query
  alias CodeMySpec.Repo
  alias CodeMySpec.Users.Scope
  alias CodeMySpec.Integrations.Integration

  @type provider :: :github | :gitlab | :bitbucket
  @type integration_attrs :: %{
          optional(:user_id) => integer(),
          optional(:provider) => provider(),
          optional(:access_token) => binary(),
          optional(:refresh_token) => binary(),
          optional(:expires_at) => DateTime.t(),
          optional(:granted_scopes) => [String.t()],
          optional(:provider_metadata) => map()
        }

  # Basic CRUD Operations

  @doc """
  Retrieves a single integration for the scoped user and provider.

  Returns `{:error, :not_found}` if no integration exists.
  Cloak automatically decrypts access_token and refresh_token when loading.

  ## Examples

      iex> get_integration(scope, :github)
      {:ok, %Integration{provider: :github}}

      iex> get_integration(scope, :gitlab)
      {:error, :not_found}
  """
  @spec get_integration(Scope.t(), provider()) ::
          {:ok, Integration.t()} | {:error, :not_found}
  def get_integration(%Scope{user: user}, provider) do
    Integration
    |> where([i], i.user_id == ^user.id and i.provider == ^provider)
    |> Repo.one()
    |> case do
      nil -> {:error, :not_found}
      integration -> {:ok, integration}
    end
  end

  @doc """
  Returns all integrations for the scoped user, ordered by most recently created.

  ## Examples

      iex> list_integrations(scope)
      [%Integration{}, %Integration{}]
  """
  @spec list_integrations(Scope.t()) :: [Integration.t()]
  def list_integrations(%Scope{user: user}) do
    Integration
    |> where([i], i.user_id == ^user.id)
    |> order_by([i], desc: i.inserted_at, desc: i.id)
    |> Repo.all()
  end

  @doc """
  Creates a new integration with encrypted tokens.

  Validates provider is supported and enforces unique constraint on (user_id, provider).
  User ID from scope is merged with attrs to ensure proper scoping.

  ## Examples

      iex> create_integration(scope, %{provider: :github, access_token: "token"})
      {:ok, %Integration{}}

      iex> create_integration(scope, %{provider: :invalid})
      {:error, %Ecto.Changeset{}}
  """
  @spec create_integration(Scope.t(), integration_attrs()) ::
          {:ok, Integration.t()} | {:error, Ecto.Changeset.t()}
  def create_integration(%Scope{user: user}, attrs) do
    %Integration{}
    |> Integration.changeset(Map.put(attrs, :user_id, user.id))
    |> Repo.insert()
  end

  @doc """
  Updates an existing integration with new attributes.

  Commonly used for token refresh operations. Returns `{:error, :not_found}`
  if integration doesn't exist for scoped user.

  ## Examples

      iex> update_integration(scope, :github, %{access_token: "new_token"})
      {:ok, %Integration{}}

      iex> update_integration(scope, :gitlab, %{access_token: "token"})
      {:error, :not_found}
  """
  @spec update_integration(Scope.t(), provider(), integration_attrs()) ::
          {:ok, Integration.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def update_integration(%Scope{} = scope, provider, attrs) do
    case get_integration(scope, provider) do
      {:ok, integration} ->
        integration
        |> Integration.changeset(attrs)
        |> Repo.update()

      {:error, :not_found} ->
        {:error, :not_found}
    end
  end

  @doc """
  Removes an integration and all associated encrypted tokens.

  Returns `{:error, :not_found}` if integration doesn't exist for scoped user.

  ## Examples

      iex> delete_integration(scope, :github)
      {:ok, %Integration{}}

      iex> delete_integration(scope, :gitlab)
      {:error, :not_found}
  """
  @spec delete_integration(Scope.t(), provider()) ::
          {:ok, Integration.t()} | {:error, :not_found}
  def delete_integration(%Scope{} = scope, provider) do
    case get_integration(scope, provider) do
      {:ok, integration} ->
        Repo.delete(integration)

      {:error, :not_found} ->
        {:error, :not_found}
    end
  end

  # Query Builders

  @doc """
  Alias for `get_integration/2`, provides semantic clarity when querying by provider.

  ## Examples

      iex> by_provider(scope, :github)
      {:ok, %Integration{provider: :github}}
  """
  @spec by_provider(Scope.t(), provider()) ::
          {:ok, Integration.t()} | {:error, :not_found}
  def by_provider(%Scope{} = scope, provider) do
    get_integration(scope, provider)
  end

  @doc """
  Returns all integrations for the scoped user where expires_at is less than current timestamp.

  Used to identify integrations requiring token refresh. Efficient query that
  doesn't require decrypting tokens (expires_at is unencrypted).

  ## Examples

      iex> with_expired_tokens(scope)
      [%Integration{expires_at: ~U[2024-01-01 00:00:00Z]}]
  """
  @spec with_expired_tokens(Scope.t()) :: [Integration.t()]
  def with_expired_tokens(%Scope{user: user}) do
    now = DateTime.utc_now()

    Integration
    |> where([i], i.user_id == ^user.id and i.expires_at < ^now)
    |> Repo.all()
  end

  # Specialized Operations

  @doc """
  Creates or updates an integration based on unique constraint (user_id, provider).

  Used during OAuth callback to handle both first-time connections and reconnections.
  Uses `on_conflict: :replace_all` with conflict_target `[:user_id, :provider]`.

  ## Examples

      iex> upsert_integration(scope, :github, %{access_token: "token"})
      {:ok, %Integration{}}
  """
  @spec upsert_integration(Scope.t(), provider(), integration_attrs()) ::
          {:ok, Integration.t()} | {:error, Ecto.Changeset.t()}
  def upsert_integration(%Scope{user: user}, provider, attrs) do
    attrs_with_scope = Map.merge(attrs, %{user_id: user.id, provider: provider})

    %Integration{}
    |> Integration.changeset(attrs_with_scope)
    |> Repo.insert(
      on_conflict: {:replace_all_except, [:id, :inserted_at]},
      conflict_target: [:user_id, :provider],
      returning: true
    )
  end

  @doc """
  Returns true if an integration exists for the scoped user and provider, false otherwise.

  Efficient check without loading full integration record.

  ## Examples

      iex> connected?(scope, :github)
      true

      iex> connected?(scope, :gitlab)
      false
  """
  @spec connected?(Scope.t(), provider()) :: boolean()
  def connected?(%Scope{user: user}, provider) do
    Integration
    |> where([i], i.user_id == ^user.id and i.provider == ^provider)
    |> Repo.exists?()
  end
end

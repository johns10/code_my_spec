defmodule CodeMySpec.Sessions.InteractionRegistry do
  @moduledoc """
  Maintains ephemeral runtime state for interactions executing asynchronously.

  Provides real-time visibility into interaction status through non-durable
  status updates from agent hook callbacks. Status is cleared when users
  interact with it in the TUI.
  """

  use GenServer
  require Logger

  alias CodeMySpec.Sessions.RuntimeInteraction

  @doc """
  Start the InteractionRegistry GenServer.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Store or update ephemeral runtime status for an interaction.

  ## Examples

      iex> runtime = RuntimeInteraction.new("interaction-123", %{agent_state: "running"})
      iex> register_status(runtime)
      :ok
  """
  @spec register_status(RuntimeInteraction.t()) :: :ok
  def register_status(%RuntimeInteraction{} = runtime) do
    GenServer.call(__MODULE__, {:register, runtime})
  end

  @doc """
  Update runtime status for an interaction with new attributes.
  Fetches existing runtime, merges attrs, and registers the update.
  Creates new runtime if none exists.

  This is the preferred API for updating status - it handles merging automatically.

  ## Examples

      iex> update_status("interaction-123", %{agent_state: "running"})
      :ok

      iex> update_status("interaction-123", %{last_notification: nil})  # Explicit clear
      :ok
  """
  @spec update_status(binary(), map()) :: :ok
  def update_status(interaction_id, attrs) when is_binary(interaction_id) and is_map(attrs) do
    GenServer.call(__MODULE__, {:update, interaction_id, attrs})
  end

  @doc """
  Retrieve current ephemeral status for an interaction.

  ## Examples

      iex> get_status("interaction-123")
      {:ok, %RuntimeInteraction{}}

      iex> get_status("unknown")
      {:error, :not_found}
  """
  @spec get_status(binary()) :: {:ok, RuntimeInteraction.t()} | {:error, :not_found}
  def get_status(interaction_id) when is_binary(interaction_id) do
    GenServer.call(__MODULE__, {:get, interaction_id})
  end

  @doc """
  Remove ephemeral status for an interaction.

  Called when user interacts with the notification in the TUI.

  ## Examples

      iex> clear_status("interaction-123")
      :ok
  """
  @spec clear_status(binary()) :: :ok
  def clear_status(interaction_id) when is_binary(interaction_id) do
    GenServer.call(__MODULE__, {:clear, interaction_id})
  end

  @doc """
  Remove all ephemeral status entries from registry.

  ## Examples

      iex> clear_all()
      :ok
  """
  @spec clear_all() :: :ok
  def clear_all do
    GenServer.call(__MODULE__, :clear_all)
  end

  @doc """
  List all interaction IDs with active runtime status.

  ## Examples

      iex> list_active()
      ["interaction-123", "interaction-456"]
  """
  @spec list_active() :: [binary()]
  def list_active do
    GenServer.call(__MODULE__, :list_active)
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    # Use simple map for storage - could be upgraded to ETS if needed
    {:ok, %{}}
  end

  @impl true
  def handle_call({:register, %RuntimeInteraction{} = runtime}, _from, state) do
    # Just store the runtime as-is - caller is responsible for merging
    updated_state = Map.put(state, runtime.interaction_id, runtime)

    Logger.debug(
      "Registered status for interaction #{runtime.interaction_id}: #{runtime.agent_state}"
    )

    {:reply, :ok, updated_state}
  end

  @impl true
  def handle_call({:update, interaction_id, attrs}, _from, state) do
    # Fetch existing, merge with changeset, store result
    updated_runtime =
      case Map.get(state, interaction_id) do
        nil ->
          # No existing runtime, create new
          RuntimeInteraction.new(interaction_id, attrs)

        existing ->
          # Update existing with new attrs - changeset handles partial updates
          RuntimeInteraction.update(existing, attrs)
      end

    updated_state = Map.put(state, interaction_id, updated_runtime)

    Logger.debug(
      "Updated status for interaction #{interaction_id}: #{updated_runtime.agent_state}"
    )

    {:reply, :ok, updated_state}
  end

  @impl true
  def handle_call({:get, interaction_id}, _from, state) do
    case Map.fetch(state, interaction_id) do
      {:ok, status} -> {:reply, {:ok, status}, state}
      :error -> {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_call({:clear, interaction_id}, _from, state) do
    updated_state = Map.delete(state, interaction_id)
    Logger.debug("Cleared status for interaction #{interaction_id}")
    {:reply, :ok, updated_state}
  end

  @impl true
  def handle_call(:clear_all, _from, _state) do
    Logger.debug("Cleared all interaction statuses")
    {:reply, :ok, %{}}
  end

  @impl true
  def handle_call(:list_active, _from, state) do
    interaction_ids = Map.keys(state)
    {:reply, interaction_ids, state}
  end
end

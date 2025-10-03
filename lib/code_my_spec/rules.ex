defmodule CodeMySpec.Rules do
  @moduledoc """
  The Rules context.
  """

  alias CodeMySpec.Rules.Rule
  alias CodeMySpec.Users.Scope
  alias CodeMySpec.Rules.RulesRepository
  alias CodeMySpec.Rules.RulesSeeder

  @doc """
  Subscribes to scoped notifications about any rule changes.

  The broadcasted messages match the pattern:

    * {:created, %Rule{}}
    * {:updated, %Rule{}}
    * {:deleted, %Rule{}}

  """
  def subscribe_rules(%Scope{} = scope) do
    key = scope.active_account.id

    Phoenix.PubSub.subscribe(CodeMySpec.PubSub, "user:#{key}:rules")
  end

  defp broadcast(%Scope{} = scope, message) do
    key = scope.active_account.id

    Phoenix.PubSub.broadcast(CodeMySpec.PubSub, "user:#{key}:rules", message)
  end

  @doc """
  Returns the list of rules.

  ## Examples

      iex> list_rules(scope)
      [%Rule{}, ...]

  """
  defdelegate list_rules(scope), to: RulesRepository

  @doc """
  Gets a single rule.

  Raises `Ecto.NoResultsError` if the Rule does not exist.

  ## Examples

      iex> get_rule!(123)
      %Rule{}

      iex> get_rule!(456)
      ** (Ecto.NoResultsError)

  """
  defdelegate get_rule!(scope, id), to: RulesRepository

  @doc """
  Creates a rule.

  ## Examples

      iex> create_rule(%{field: value})
      {:ok, %Rule{}}

      iex> create_rule(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_rule(%Scope{} = scope, attrs) do
    with {:ok, rule = %Rule{}} <- RulesRepository.create_rule(scope, attrs) do
      broadcast(scope, {:created, rule})
      {:ok, rule}
    end
  end

  @doc """
  Updates a rule.

  ## Examples

      iex> update_rule(rule, %{field: new_value})
      {:ok, %Rule{}}

      iex> update_rule(rule, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_rule(%Scope{} = scope, %Rule{} = rule, attrs) do
    with {:ok, rule = %Rule{}} <- RulesRepository.update_rule(scope, rule, attrs) do
      broadcast(scope, {:updated, rule})
      {:ok, rule}
    end
  end

  @doc """
  Deletes a rule.

  ## Examples

      iex> delete_rule(rule)
      {:ok, %Rule{}}

      iex> delete_rule(rule)
      {:error, %Ecto.Changeset{}}

  """
  def delete_rule(%Scope{} = scope, %Rule{} = rule) do
    true = rule.account_id == scope.active_account.id

    with {:ok, rule = %Rule{}} <- RulesRepository.delete_rule(scope, rule) do
      broadcast(scope, {:deleted, rule})
      {:ok, rule}
    end
  end

  @doc """
  Finds matching rules based on component type and session type.

  ## Examples

      iex> find_matching_rules(scope, "context", "coding")
      [%Rule{}, ...]

  """
  defdelegate find_matching_rules(scope, component_type, session_type), to: RulesRepository

  @doc """
  Seeds base rules for an account from markdown files.

  ## Examples

      iex> seed_account_rules(scope)
      {:ok, [%Rule{}, ...]}

  """
  defdelegate seed_account_rules(scope), to: RulesSeeder

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking rule changes.

  ## Examples

      iex> change_rule(rule)
      %Ecto.Changeset{data: %Rule{}}

  """
  defdelegate change_rule(scope, rule, attrs \\ %{}), to: RulesRepository

  @doc """
  Deletes all rules for an account.

  ## Examples

      iex> delete_all_rules(scope)
      {5, nil}

  """
  defdelegate delete_all_rules(scope), to: RulesRepository
end

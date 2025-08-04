defmodule CodeMySpec.Rules.RulesRepository do
  import Ecto.Query, warn: false
  alias CodeMySpec.Repo
  alias CodeMySpec.Rules.Rule
  alias CodeMySpec.Users.Scope

  def list_rules(%Scope{} = scope) do
    Repo.all_by(Rule, account_id: scope.active_account.id)
  end

  def get_rule!(%Scope{} = scope, id) do
    Repo.get_by!(Rule, id: id, account_id: scope.active_account.id)
  end

  def create_rule(%Scope{} = scope, attrs) do
    %Rule{}
    |> Rule.changeset(attrs, scope)
    |> Repo.insert()
  end

  def update_rule(%Scope{} = scope, %Rule{} = rule, attrs) do
    true = rule.account_id == scope.active_account.id

    rule
    |> Rule.changeset(attrs, scope)
    |> Repo.update()
  end

  def delete_rule(%Scope{} = scope, %Rule{} = rule) do
    true = rule.account_id == scope.active_account.id
    Repo.delete(rule)
  end

  def find_matching_rules(%Scope{} = scope, component_type, session_type) do
    from(r in Rule,
      where: r.account_id == ^scope.active_account.id,
      where: r.component_type == ^component_type or r.component_type == "*",
      where: r.session_type == ^session_type or r.session_type == "*",
      order_by: [r.component_type, r.session_type]
    )
    |> Repo.all()
  end

  def change_rule(%Scope{} = scope, %Rule{} = rule, attrs \\ %{}) do
    true = rule.account_id == scope.active_account.id

    Rule.changeset(rule, attrs, scope)
  end
end

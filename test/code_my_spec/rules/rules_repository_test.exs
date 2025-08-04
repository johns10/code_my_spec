defmodule CodeMySpec.Rules.RulesRepositoryTest do
  use CodeMySpec.DataCase

  alias CodeMySpec.Rules

  describe "rules" do
    alias CodeMySpec.Rules.Rule

    import CodeMySpec.UsersFixtures, only: [full_scope_fixture: 0]
    import CodeMySpec.RulesFixtures

    @invalid_attrs %{name: nil, session_type: nil, content: nil, component_type: nil}

    test "list_rules/1 returns all scoped rules" do
      scope = full_scope_fixture()
      other_scope = full_scope_fixture()
      rule = rule_fixture(scope)
      other_rule = rule_fixture(other_scope)
      assert Rules.list_rules(scope) == [rule]
      assert Rules.list_rules(other_scope) == [other_rule]
    end

    test "get_rule!/2 returns the rule with given id" do
      scope = full_scope_fixture()
      rule = rule_fixture(scope)
      other_scope = full_scope_fixture()
      assert Rules.get_rule!(scope, rule.id) == rule
      assert_raise Ecto.NoResultsError, fn -> Rules.get_rule!(other_scope, rule.id) end
    end

    test "create_rule/2 with valid data creates a rule" do
      valid_attrs = %{
        name: "some name",
        session_type: "some session_type",
        content: "some content",
        component_type: "some component_type"
      }

      scope = full_scope_fixture()

      assert {:ok, %Rule{} = rule} = Rules.create_rule(scope, valid_attrs)
      assert rule.name == "some name"
      assert rule.session_type == "some session_type"
      assert rule.content == "some content"
      assert rule.component_type == "some component_type"
      assert rule.account_id == scope.active_account.id
    end

    test "create_rule/2 with invalid data returns error changeset" do
      scope = full_scope_fixture()
      assert {:error, %Ecto.Changeset{}} = Rules.create_rule(scope, @invalid_attrs)
    end

    test "update_rule/3 with valid data updates the rule" do
      scope = full_scope_fixture()
      rule = rule_fixture(scope)

      update_attrs = %{
        name: "some updated name",
        session_type: "some updated session_type",
        content: "some updated content",
        component_type: "some updated component_type"
      }

      assert {:ok, %Rule{} = rule} = Rules.update_rule(scope, rule, update_attrs)
      assert rule.name == "some updated name"
      assert rule.session_type == "some updated session_type"
      assert rule.content == "some updated content"
      assert rule.component_type == "some updated component_type"
    end

    test "update_rule/3 with invalid scope raises" do
      scope = full_scope_fixture()
      other_scope = full_scope_fixture()
      rule = rule_fixture(scope)

      assert_raise MatchError, fn ->
        Rules.update_rule(other_scope, rule, %{})
      end
    end

    test "update_rule/3 with invalid data returns error changeset" do
      scope = full_scope_fixture()
      rule = rule_fixture(scope)
      assert {:error, %Ecto.Changeset{}} = Rules.update_rule(scope, rule, @invalid_attrs)
      assert rule == Rules.get_rule!(scope, rule.id)
    end

    test "delete_rule/2 deletes the rule" do
      scope = full_scope_fixture()
      rule = rule_fixture(scope)
      assert {:ok, %Rule{}} = Rules.delete_rule(scope, rule)
      assert_raise Ecto.NoResultsError, fn -> Rules.get_rule!(scope, rule.id) end
    end

    test "delete_rule/2 with invalid scope raises" do
      scope = full_scope_fixture()
      other_scope = full_scope_fixture()
      rule = rule_fixture(scope)
      assert_raise MatchError, fn -> Rules.delete_rule(other_scope, rule) end
    end

    test "change_rule/2 returns a rule changeset" do
      scope = full_scope_fixture()
      rule = rule_fixture(scope)
      assert %Ecto.Changeset{} = Rules.change_rule(scope, rule)
    end
  end
end

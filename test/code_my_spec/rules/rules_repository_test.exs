defmodule CodeMySpec.Rules.RulesRepositoryTest do
  use CodeMySpec.DataCase

  alias CodeMySpec.Rules.RulesRepository

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
      assert RulesRepository.list_rules(scope) == [rule]
      assert RulesRepository.list_rules(other_scope) == [other_rule]
    end

    test "get_rule!/2 returns the rule with given id" do
      scope = full_scope_fixture()
      rule = rule_fixture(scope)
      other_scope = full_scope_fixture()
      assert RulesRepository.get_rule!(scope, rule.id) == rule
      assert_raise Ecto.NoResultsError, fn -> RulesRepository.get_rule!(other_scope, rule.id) end
    end

    test "create_rule/2 with valid data creates a rule" do
      valid_attrs = %{
        name: "some name",
        session_type: "some session_type",
        content: "some content",
        component_type: "some component_type"
      }

      scope = full_scope_fixture()

      assert {:ok, %Rule{} = rule} = RulesRepository.create_rule(scope, valid_attrs)
      assert rule.name == "some name"
      assert rule.session_type == "some session_type"
      assert rule.content == "some content"
      assert rule.component_type == "some component_type"
      assert rule.account_id == scope.active_account.id
    end

    test "create_rule/2 with invalid data returns error changeset" do
      scope = full_scope_fixture()
      assert {:error, %Ecto.Changeset{}} = RulesRepository.create_rule(scope, @invalid_attrs)
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

      assert {:ok, %Rule{} = rule} = RulesRepository.update_rule(scope, rule, update_attrs)
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
        RulesRepository.update_rule(other_scope, rule, %{})
      end
    end

    test "update_rule/3 with invalid data returns error changeset" do
      scope = full_scope_fixture()
      rule = rule_fixture(scope)

      assert {:error, %Ecto.Changeset{}} =
               RulesRepository.update_rule(scope, rule, @invalid_attrs)

      assert rule == RulesRepository.get_rule!(scope, rule.id)
    end

    test "delete_rule/2 deletes the rule" do
      scope = full_scope_fixture()
      rule = rule_fixture(scope)
      assert {:ok, %Rule{}} = RulesRepository.delete_rule(scope, rule)
      assert_raise Ecto.NoResultsError, fn -> RulesRepository.get_rule!(scope, rule.id) end
    end

    test "delete_rule/2 with invalid scope raises" do
      scope = full_scope_fixture()
      other_scope = full_scope_fixture()
      rule = rule_fixture(scope)
      assert_raise MatchError, fn -> RulesRepository.delete_rule(other_scope, rule) end
    end

    test "change_rule/2 returns a rule changeset" do
      scope = full_scope_fixture()
      rule = rule_fixture(scope)
      assert %Ecto.Changeset{} = RulesRepository.change_rule(scope, rule)
    end

    test "find_matching_rules/3 returns exact matches" do
      scope = full_scope_fixture()
      rule = rule_fixture(scope, %{component_type: "context", session_type: "coding"})
      _other_rule = rule_fixture(scope, %{component_type: "system", session_type: "coding"})

      matches = RulesRepository.find_matching_rules(scope, "context", "coding")
      assert matches == [rule]
    end

    test "find_matching_rules/3 returns wildcard component matches" do
      scope = full_scope_fixture()
      rule1 = rule_fixture(scope, %{component_type: "*", session_type: "coding"})
      rule2 = rule_fixture(scope, %{component_type: "context", session_type: "coding"})
      _other_rule = rule_fixture(scope, %{component_type: "system", session_type: "testing"})

      matches = RulesRepository.find_matching_rules(scope, "context", "coding")
      assert Enum.sort_by(matches, & &1.id) == Enum.sort_by([rule1, rule2], & &1.id)
    end

    test "find_matching_rules/3 returns wildcard session matches" do
      scope = full_scope_fixture()
      rule1 = rule_fixture(scope, %{component_type: "context", session_type: "*"})
      rule2 = rule_fixture(scope, %{component_type: "context", session_type: "coding"})
      _other_rule = rule_fixture(scope, %{component_type: "system", session_type: "coding"})

      matches = RulesRepository.find_matching_rules(scope, "context", "coding")
      assert Enum.sort_by(matches, & &1.id) == Enum.sort_by([rule1, rule2], & &1.id)
    end

    test "find_matching_rules/3 returns global wildcard matches" do
      scope = full_scope_fixture()
      rule1 = rule_fixture(scope, %{component_type: "*", session_type: "*"})
      rule2 = rule_fixture(scope, %{component_type: "context", session_type: "coding"})
      _other_rule = rule_fixture(scope, %{component_type: "system", session_type: "testing"})

      matches = RulesRepository.find_matching_rules(scope, "context", "coding")
      assert Enum.sort_by(matches, & &1.id) == Enum.sort_by([rule1, rule2], & &1.id)
    end

    test "find_matching_rules/3 respects account scoping" do
      scope = full_scope_fixture()
      other_scope = full_scope_fixture()
      rule = rule_fixture(scope, %{component_type: "context", session_type: "coding"})

      other_rule =
        rule_fixture(other_scope, %{component_type: "context", session_type: "coding"})

      matches = RulesRepository.find_matching_rules(scope, "context", "coding")
      assert matches == [rule]

      other_matches = RulesRepository.find_matching_rules(other_scope, "context", "coding")
      assert other_matches == [other_rule]
    end

    test "find_matching_rules/3 returns empty list when no matches" do
      scope = full_scope_fixture()
      _rule = rule_fixture(scope, %{component_type: "system", session_type: "testing"})

      matches = RulesRepository.find_matching_rules(scope, "context", "coding")
      assert matches == []
    end

    test "find_matching_rules/3 orders results correctly" do
      scope = full_scope_fixture()
      rule1 = rule_fixture(scope, %{component_type: "*", session_type: "*"})
      rule2 = rule_fixture(scope, %{component_type: "*", session_type: "coding"})
      rule3 = rule_fixture(scope, %{component_type: "context", session_type: "*"})
      rule4 = rule_fixture(scope, %{component_type: "context", session_type: "coding"})

      matches = RulesRepository.find_matching_rules(scope, "context", "coding")
      assert matches == [rule1, rule2, rule3, rule4]
    end
  end
end

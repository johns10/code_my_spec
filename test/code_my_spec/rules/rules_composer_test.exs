defmodule CodeMySpec.Rules.RulesComposerTest do
  use ExUnit.Case
  doctest CodeMySpec.Rules.RulesComposer
  alias CodeMySpec.Rules.RulesComposer
  alias CodeMySpec.Rules.Rule

  describe "compose_rules/1" do
    test "composes multiple rules with default separator" do
      rules = [
        %Rule{content: "First rule"},
        %Rule{content: "Second rule"},
        %Rule{content: "Third rule"}
      ]

      result = RulesComposer.compose_rules(rules)
      assert result == "First rule\n\nSecond rule\n\nThird rule"
    end

    test "filters out blank content" do
      rules = [
        %Rule{content: "Valid rule"},
        %Rule{content: ""},
        %Rule{content: "   "},
        %Rule{content: "Another valid rule"}
      ]

      result = RulesComposer.compose_rules(rules)
      assert result == "Valid rule\n\nAnother valid rule"
    end

    test "filters out nil content" do
      rules = [
        %Rule{content: "Valid rule"},
        %Rule{content: nil},
        %Rule{content: "Another valid rule"}
      ]

      result = RulesComposer.compose_rules(rules)
      assert result == "Valid rule\n\nAnother valid rule"
    end

    test "returns empty string for empty list" do
      result = RulesComposer.compose_rules([])
      assert result == ""
    end

    test "returns empty string when all rules have blank content" do
      rules = [
        %Rule{content: ""},
        %Rule{content: nil},
        %Rule{content: "   "}
      ]

      result = RulesComposer.compose_rules(rules)
      assert result == ""
    end

    test "handles single rule" do
      rules = [%Rule{content: "Only rule"}]
      result = RulesComposer.compose_rules(rules)
      assert result == "Only rule"
    end
  end

  describe "compose_rules/2" do
    test "composes rules with custom separator" do
      rules = [
        %Rule{content: "First rule"},
        %Rule{content: "Second rule"}
      ]

      result = RulesComposer.compose_rules(rules, "\n---\n")
      assert result == "First rule\n---\nSecond rule"
    end

    test "composes rules with single character separator" do
      rules = [
        %Rule{content: "First rule"},
        %Rule{content: "Second rule"}
      ]

      result = RulesComposer.compose_rules(rules, "|")
      assert result == "First rule|Second rule"
    end

    test "filters out blank content with custom separator" do
      rules = [
        %Rule{content: "Valid rule"},
        %Rule{content: ""},
        %Rule{content: "Another valid rule"}
      ]

      result = RulesComposer.compose_rules(rules, " | ")
      assert result == "Valid rule | Another valid rule"
    end

    test "returns empty string for empty list with custom separator" do
      result = RulesComposer.compose_rules([], "|||")
      assert result == ""
    end

    test "handles single rule with custom separator" do
      rules = [%Rule{content: "Only rule"}]
      result = RulesComposer.compose_rules(rules, "SEPARATOR")
      assert result == "Only rule"
    end
  end
end

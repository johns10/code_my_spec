defmodule CodeMySpecWeb.RuleLiveTest do
  use CodeMySpecWeb.ConnCase

  import Phoenix.LiveViewTest
  import CodeMySpec.RulesFixtures

  @create_attrs %{
    name: "some name",
    session_type: "some session_type",
    content: "some content",
    component_type: "some component_type"
  }
  @update_attrs %{
    name: "some updated name",
    session_type: "some updated session_type",
    content: "some updated content",
    component_type: "some updated component_type"
  }
  @invalid_attrs %{name: nil, session_type: nil, content: nil, component_type: nil}

  setup :register_log_in_setup_account

  defp create_rule(%{scope: scope}) do
    rule = rule_fixture(scope)

    %{rule: rule}
  end

  describe "Index" do
    setup [:create_rule]

    test "lists all rules", %{conn: conn, rule: rule} do
      {:ok, _index_live, html} = live(conn, ~p"/rules")

      assert html =~ "Listing Rules"
      assert html =~ rule.name
    end

    test "saves new rule", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/rules")

      assert {:ok, form_live, _} =
               index_live
               |> element("a", "New Rule")
               |> render_click()
               |> follow_redirect(conn, ~p"/rules/new")

      assert render(form_live) =~ "New Rule"

      assert form_live
             |> form("#rule-form", rule: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, index_live, _html} =
               form_live
               |> form("#rule-form", rule: @create_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/rules")

      html = render(index_live)
      assert html =~ "Rule created successfully"
      assert html =~ "some name"
    end

    test "updates rule in listing", %{conn: conn, rule: rule} do
      {:ok, index_live, _html} = live(conn, ~p"/rules")

      assert {:ok, form_live, _html} =
               index_live
               |> element("#rules-#{rule.id} a", "Edit")
               |> render_click()
               |> follow_redirect(conn, ~p"/rules/#{rule}/edit")

      assert render(form_live) =~ "Edit Rule"

      assert form_live
             |> form("#rule-form", rule: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, index_live, _html} =
               form_live
               |> form("#rule-form", rule: @update_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/rules")

      html = render(index_live)
      assert html =~ "Rule updated successfully"
      assert html =~ "some updated name"
    end

    test "deletes rule in listing", %{conn: conn, rule: rule} do
      {:ok, index_live, _html} = live(conn, ~p"/rules")

      assert index_live |> element("#rules-#{rule.id} a", "Delete") |> render_click()
      refute has_element?(index_live, "#rules-#{rule.id}")
    end
  end

  describe "Show" do
    setup [:create_rule]

    test "displays rule", %{conn: conn, rule: rule} do
      {:ok, _show_live, html} = live(conn, ~p"/rules/#{rule}")

      assert html =~ "Show Rule"
      assert html =~ rule.name
    end

    test "updates rule and returns to show", %{conn: conn, rule: rule} do
      {:ok, show_live, _html} = live(conn, ~p"/rules/#{rule}")

      assert {:ok, form_live, _} =
               show_live
               |> element("a", "Edit")
               |> render_click()
               |> follow_redirect(conn, ~p"/rules/#{rule}/edit?return_to=show")

      assert render(form_live) =~ "Edit Rule"

      assert form_live
             |> form("#rule-form", rule: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, show_live, _html} =
               form_live
               |> form("#rule-form", rule: @update_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/rules/#{rule}")

      html = render(show_live)
      assert html =~ "Rule updated successfully"
      assert html =~ "some updated name"
    end
  end
end

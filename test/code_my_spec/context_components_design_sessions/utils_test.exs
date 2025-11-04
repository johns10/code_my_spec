defmodule CodeMySpec.ContextComponentsDesignSessions.UtilsTest do
  use ExUnit.Case, async: true

  alias CodeMySpec.ContextComponentsDesignSessions.Utils
  alias CodeMySpec.Sessions.Session
  alias CodeMySpec.Components.Component

  describe "branch_name/1" do
    test "generates correct branch name for simple component name" do
      session = %Session{
        type: CodeMySpec.ContextComponentsDesignSessions,
        component: %Component{name: "Accounts"}
      }

      assert Utils.branch_name(session) == "docs-context-components-design-session-for-accounts"
    end

    test "converts component name to lowercase" do
      session = %Session{
        type: CodeMySpec.ContextComponentsDesignSessions,
        component: %Component{name: "UserManagement"}
      }

      assert Utils.branch_name(session) == "docs-context-components-design-session-for-usermanagement"
    end

    test "replaces spaces with hyphens" do
      session = %Session{
        type: CodeMySpec.ContextComponentsDesignSessions,
        component: %Component{name: "User Management"}
      }

      assert Utils.branch_name(session) == "docs-context-components-design-session-for-user-management"
    end

    test "replaces special characters with hyphens" do
      session = %Session{
        type: CodeMySpec.ContextComponentsDesignSessions,
        component: %Component{name: "API::Handler"}
      }

      assert Utils.branch_name(session) == "docs-context-components-design-session-for-api-handler"
    end

    test "replaces multiple special characters with single hyphen" do
      session = %Session{
        type: CodeMySpec.ContextComponentsDesignSessions,
        component: %Component{name: "User & Auth"}
      }

      assert Utils.branch_name(session) == "docs-context-components-design-session-for-user-auth"
    end

    test "collapses multiple consecutive hyphens" do
      session = %Session{
        type: CodeMySpec.ContextComponentsDesignSessions,
        component: %Component{name: "User---Management"}
      }

      assert Utils.branch_name(session) == "docs-context-components-design-session-for-user-management"
    end

    test "trims leading and trailing hyphens" do
      session = %Session{
        type: CodeMySpec.ContextComponentsDesignSessions,
        component: %Component{name: "-User-"}
      }

      assert Utils.branch_name(session) == "docs-context-components-design-session-for-user"
    end

    test "preserves existing hyphens and underscores" do
      session = %Session{
        type: CodeMySpec.ContextComponentsDesignSessions,
        component: %Component{name: "user-auth_handler"}
      }

      assert Utils.branch_name(session) == "docs-context-components-design-session-for-user-auth_handler"
    end

    test "handles complex names with mixed characters" do
      session = %Session{
        type: CodeMySpec.ContextComponentsDesignSessions,
        component: %Component{name: "User Management & Auth (v2)"}
      }

      assert Utils.branch_name(session) == "docs-context-components-design-session-for-user-management-auth-v2"
    end
  end
end

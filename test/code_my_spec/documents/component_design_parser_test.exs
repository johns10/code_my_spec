defmodule CodeMySpec.Documents.ComponentDesignParserTest do
  use ExUnit.Case, async: true

  alias CodeMySpec.Documents.ComponentDesignParser

  describe "from_markdown/1" do
    test "parses component design markdown correctly" do
      markdown = """
      # User Authentication Component

      ## Purpose
      Manages user authentication and session handling for the application.

      ## Public API
      - `authenticate_user(credentials)` - Validates user credentials
      - `create_session(user)` - Creates authenticated session
      - `refresh_token(token)` - Refreshes authentication token

      ## Execution Flow
      1. User submits credentials
      2. System validates against database
      3. Session token generated and stored
      4. User redirected to dashboard

      ## Implementation Notes
      Uses JWT tokens with 24-hour expiration.
      """

      {:ok, result} = ComponentDesignParser.from_markdown(markdown)

      assert result.purpose =~ "Manages user authentication"
      assert result.public_api =~ "authenticate_user(credentials)"
      assert result.public_api =~ "create_session(user)"
      assert result.execution_flow =~ "User submits credentials"
      assert result.execution_flow =~ "Session token generated"

      # Check other sections are captured
      assert is_map(result.other_sections)
      assert Map.has_key?(result.other_sections, "implementation notes")
      assert result.other_sections["implementation notes"] =~ "JWT tokens"
    end

    test "handles empty sections gracefully" do
      markdown = """
      # Test Component

      ## Purpose
      Test component purpose.

      ## Public API

      ## Execution Flow

      ## Custom Section
      Some custom content.
      """

      {:ok, result} = ComponentDesignParser.from_markdown(markdown)

      assert result.purpose == "Test component purpose."
      assert result.public_api == ""
      assert result.execution_flow == ""
      assert Map.has_key?(result.other_sections, "custom section")
      assert result.other_sections["custom section"] =~ "Some custom content"
    end

    test "parses lists correctly in sections" do
      markdown = """
      # API Component

      ## Purpose
      Provides REST API endpoints.

      ## Public API
      - GET /users - List all users
      - POST /users - Create new user
      - PUT /users/:id - Update user
      - DELETE /users/:id - Delete user

      ## Execution Flow
      1. Request validation
      2. Business logic execution
      3. Response formatting
      4. Error handling
      """

      {:ok, result} = ComponentDesignParser.from_markdown(markdown)

      assert result.public_api =~ "- GET /users"
      assert result.public_api =~ "- POST /users"
      assert result.execution_flow =~ "1. Request validation"
      assert result.execution_flow =~ "4. Error handling"
    end

    test "captures unknown sections in other_sections" do
      markdown = """
      # Test Component

      ## Purpose
      Test component.

      ## Custom Section
      This is a custom section that should be preserved.

      ## Another Unknown Section
      More custom content here.

      ## Technical Details
      Implementation-specific information.
      """

      {:ok, result} = ComponentDesignParser.from_markdown(markdown)

      assert result.purpose == "Test component."
      assert Map.has_key?(result.other_sections, "custom section")
      assert Map.has_key?(result.other_sections, "another unknown section")
      assert Map.has_key?(result.other_sections, "technical details")
      assert result.other_sections["custom section"] =~ "custom section"
      assert result.other_sections["technical details"] =~ "Implementation-specific"
    end

    test "handles minimal component design" do
      markdown = """
      # Minimal Component

      ## Purpose
      A minimal component for testing.
      """

      {:ok, result} = ComponentDesignParser.from_markdown(markdown)

      assert result.purpose == "A minimal component for testing."
      assert result.public_api == ""
      assert result.execution_flow == ""
      assert result.other_sections == %{}
    end

    test "handles malformed markdown gracefully" do
      invalid_markdown = """
      # Test Component

      ## Purpose
      Valid purpose.

      ## Public API
      - Unclosed list item
      - Another item

      Some text without proper structure.
      """

      {:ok, result} = ComponentDesignParser.from_markdown(invalid_markdown)

      assert result.purpose == "Valid purpose."
      assert result.public_api =~ "Unclosed list item"
      assert result.public_api =~ "Some text without proper structure"
    end
  end
end
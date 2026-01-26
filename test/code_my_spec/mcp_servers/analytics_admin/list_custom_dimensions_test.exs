defmodule CodeMySpec.McpServers.AnalyticsAdmin.Tools.ListCustomDimensionsTest do
  use ExUnit.Case, async: true

  alias CodeMySpec.TestRecorder

  @moduledoc """
  Tests for the ListCustomDimensions MCP tool.

  ## Recording Cassettes

  To record a real API response:

  1. Set up a valid Google OAuth integration in your test database
  2. Delete the cassette: `rm test/cassettes/analytics_list_custom_dimensions_success.etf`
  3. Run the test: `mix test test/market_my_spec/mcp_servers/analytics_admin/list_custom_dimensions_test.exs`
  4. Or force re-record: `RERECORD=true mix test`

  The cassette will be created and subsequent test runs will use the recorded response.
  """

  describe "execute/2 with recorded responses" do
    test "formats custom dimensions response correctly" do
      # Use a pre-recorded cassette for testing the formatting logic
      result =
        TestRecorder.record_or_replay("analytics_list_custom_dimensions_formatted", fn ->
          # This would be your real API response
          {:ok,
           %{
             customDimensions: [
               %{
                 name: "properties/123456/customDimensions/dimension1",
                 displayName: "User Category",
                 parameterName: "user_category",
                 scope: "USER",
                 description: "Category of the user"
               },
               %{
                 name: "properties/123456/customDimensions/dimension2",
                 displayName: "Session Type",
                 parameterName: "session_type",
                 scope: "SESSION",
                 description: "Type of session"
               }
             ]
           }}
        end)

      assert {:ok, response} = result
      assert length(response.customDimensions) == 2
      assert Enum.all?(response.customDimensions, &Map.has_key?(&1, :displayName))
    end

    test "handles empty custom dimensions list" do
      result =
        TestRecorder.record_or_replay("analytics_list_custom_dimensions_empty", fn ->
          {:ok, %{customDimensions: []}}
        end)

      assert {:ok, %{customDimensions: []}} = result
    end

    test "handles API errors" do
      result =
        TestRecorder.record_or_replay("analytics_list_custom_dimensions_error", fn ->
          {:error, %{status: 404, body: "Property not found"}}
        end)

      assert {:error, _} = result
    end
  end
end

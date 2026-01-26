defmodule CodeMySpec.McpServers.ArchitectureServerTest do
  use ExUnit.Case, async: true

  alias CodeMySpec.McpServers.ArchitectureServer

  describe "ArchitectureServer" do
    test "has correct server info" do
      info = ArchitectureServer.server_info()

      assert info["name"] == "architecture-server"
      assert info["version"] == "1.0.0"
    end

    test "has correct server capabilities" do
      capabilities = ArchitectureServer.server_capabilities()

      assert Map.has_key?(capabilities, "tools")
    end

    test "returns valid child_spec" do
      spec = ArchitectureServer.child_spec([])

      assert spec.id == ArchitectureServer
      assert spec.start == {Hermes.Server.Supervisor, :start_link, [ArchitectureServer, []]}
      assert spec.type == :supervisor
      assert spec.restart == :permanent
    end

    test "has registered components" do
      components = ArchitectureServer.__components__()

      # Should have 10 tools registered
      assert length(components) == 10

      # Verify some key tools are present
      component_names = Enum.map(components, & &1.name)
      assert "create_spec" in component_names
      assert "get_spec" in component_names
      assert "list_spec_names" in component_names
      assert "start_architecture_design" in component_names
      assert "validate_dependency_graph" in component_names
    end
  end
end

defmodule CodeMySpec.MCPServers.ComponentsServer do
  use Hermes.Server,
    name: "components-server",
    version: "1.0.0",
    capabilities: [:tools, :resources, :prompts]

  # Core CRUD operations
  component(CodeMySpec.MCPServers.Components.Tools.CreateComponent)
  component(CodeMySpec.MCPServers.Components.Tools.UpdateComponent)
  component(CodeMySpec.MCPServers.Components.Tools.DeleteComponent)
  component(CodeMySpec.MCPServers.Components.Tools.GetComponent)
  component(CodeMySpec.MCPServers.Components.Tools.ListComponents)

  # Batch operations
  component(CodeMySpec.MCPServers.Components.Tools.CreateComponents)
  component(CodeMySpec.MCPServers.Components.Tools.CreateDependencies)

  # Dependency management
  component(CodeMySpec.MCPServers.Components.Tools.CreateDependency)
  component(CodeMySpec.MCPServers.Components.Tools.DeleteDependency)

  # Architecture and design tools
  component(CodeMySpec.MCPServers.Components.Tools.StartContextDesign)
  component(CodeMySpec.MCPServers.Components.Tools.ReviewContextDesign)
  component(CodeMySpec.MCPServers.Components.Tools.ShowArchitecture)
end

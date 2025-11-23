defmodule CodeMySpec.MCPServers.ComponentsServer do
  use Hermes.Server,
    name: "components-server",
    version: "1.0.0",
    capabilities: [:tools]

  # Core CRUD operations
  component(CodeMySpec.MCPServers.Components.Tools.CreateComponent)
  component(CodeMySpec.MCPServers.Components.Tools.UpdateComponent)
  component(CodeMySpec.MCPServers.Components.Tools.DeleteComponent)
  component(CodeMySpec.MCPServers.Components.Tools.GetComponent)
  component(CodeMySpec.MCPServers.Components.Tools.ListComponents)
  component(CodeMySpec.MCPServers.Stories.Tools.ListStories)

  # Batch operations
  # component(CodeMySpec.MCPServers.Components.Tools.CreateComponents)
  # component(CodeMySpec.MCPServers.Components.Tools.CreateDependencies)

  # Dependency management
  component(CodeMySpec.MCPServers.Components.Tools.CreateDependency)
  component(CodeMySpec.MCPServers.Components.Tools.DeleteDependency)

  # Similar component management
  component(CodeMySpec.MCPServers.Components.Tools.AddSimilarComponent)
  component(CodeMySpec.MCPServers.Components.Tools.RemoveSimilarComponent)

  # Architecture and design tools
  component(CodeMySpec.MCPServers.Components.Tools.StartContextDesign)
  component(CodeMySpec.MCPServers.Components.Tools.ReviewContextDesign)
  component(CodeMySpec.MCPServers.Components.Tools.ShowArchitecture)
  component(CodeMySpec.MCPServers.Components.Tools.ArchitectureHealthSummary)
  component(CodeMySpec.MCPServers.Components.Tools.ContextStatistics)
  component(CodeMySpec.MCPServers.Components.Tools.OrphanedContexts)
  component(CodeMySpec.MCPServers.Stories.Tools.SetStoryComponent)
end

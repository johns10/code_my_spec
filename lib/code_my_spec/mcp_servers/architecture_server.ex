defmodule CodeMySpec.MCPServers.ArchitectureServer do
  use Hermes.Server,
    name: "architecture-server",
    version: "1.0.0",
    capabilities: [:tools]

  # Spec file management
  component(CodeMySpec.MCPServers.Architecture.Tools.CreateSpec)
  component(CodeMySpec.MCPServers.Architecture.Tools.UpdateSpecMetadata)
  component(CodeMySpec.MCPServers.Architecture.Tools.ListSpecs)
  component(CodeMySpec.MCPServers.Architecture.Tools.GetSpec)
  component(CodeMySpec.MCPServers.Architecture.Tools.DeleteSpec)

  # Design workflow
  component(CodeMySpec.MCPServers.Architecture.Tools.StartArchitectureDesign)
  component(CodeMySpec.MCPServers.Architecture.Tools.ReviewArchitectureDesign)

  # Architecture analysis
  # component(CodeMySpec.MCPServers.Architecture.Tools.GetArchitectureSummary)
  # component(CodeMySpec.MCPServers.Architecture.Tools.GetComponentImpact)
  component(CodeMySpec.MCPServers.Architecture.Tools.GetComponentView)
  component(CodeMySpec.MCPServers.Architecture.Tools.ValidateDependencyGraph)
end

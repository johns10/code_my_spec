defmodule CodeMySpec.McpServers.ArchitectureServer do
  use Hermes.Server,
    name: "architecture-server",
    version: "1.0.0",
    capabilities: [:tools]

  # Spec file management
  component(CodeMySpec.McpServers.Architecture.Tools.CreateSpec)
  component(CodeMySpec.McpServers.Architecture.Tools.UpdateSpecMetadata)
  component(CodeMySpec.McpServers.Architecture.Tools.ListSpecs)
  component(CodeMySpec.McpServers.Architecture.Tools.GetSpec)
  component(CodeMySpec.McpServers.Architecture.Tools.DeleteSpec)

  # Design workflow
  component(CodeMySpec.McpServers.Architecture.Tools.StartArchitectureDesign)
  component(CodeMySpec.McpServers.Architecture.Tools.ReviewArchitectureDesign)

  # Architecture analysis
  # component(CodeMySpec.McpServers.Architecture.Tools.GetArchitectureSummary)
  # component(CodeMySpec.McpServers.Architecture.Tools.GetComponentImpact)
  component(CodeMySpec.McpServers.Architecture.Tools.GetComponentView)
  component(CodeMySpec.McpServers.Architecture.Tools.ValidateDependencyGraph)
end

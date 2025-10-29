defmodule CodeMySpec.MCPServers.AnalyticsAdminServer do
  use Hermes.Server,
    name: "analytics-admin-server",
    version: "1.0.0",
    capabilities: [:tools]

  # Tool components - Custom Dimensions
  component(CodeMySpec.MCPServers.AnalyticsAdmin.Tools.ListCustomDimensions)
  component(CodeMySpec.MCPServers.AnalyticsAdmin.Tools.GetCustomDimension)
  component(CodeMySpec.MCPServers.AnalyticsAdmin.Tools.CreateCustomDimension)
  component(CodeMySpec.MCPServers.AnalyticsAdmin.Tools.UpdateCustomDimension)
  component(CodeMySpec.MCPServers.AnalyticsAdmin.Tools.ArchiveCustomDimension)

  # Tool components - Custom Metrics
  component(CodeMySpec.MCPServers.AnalyticsAdmin.Tools.ListCustomMetrics)
  component(CodeMySpec.MCPServers.AnalyticsAdmin.Tools.CreateCustomMetric)
  component(CodeMySpec.MCPServers.AnalyticsAdmin.Tools.GetCustomMetric)
  component(CodeMySpec.MCPServers.AnalyticsAdmin.Tools.UpdateCustomMetric)
  component(CodeMySpec.MCPServers.AnalyticsAdmin.Tools.ArchiveCustomMetric)

  # Tool components - Key Events
  component(CodeMySpec.MCPServers.AnalyticsAdmin.Tools.ListKeyEvents)
  component(CodeMySpec.MCPServers.AnalyticsAdmin.Tools.CreateKeyEvent)
  component(CodeMySpec.MCPServers.AnalyticsAdmin.Tools.UpdateKeyEvent)
  component(CodeMySpec.MCPServers.AnalyticsAdmin.Tools.DeleteKeyEvent)
end

defmodule CodeMySpec.MCPServers.StoriesServer do
  use Hermes.Server,
    name: "stories-server",
    version: "1.0.0",
    capabilities: [:tools, :resources, :prompts]

  # Tool components
  component(CodeMySpec.MCPServers.Stories.Tools.CreateStory)
  component(CodeMySpec.MCPServers.Stories.Tools.CreateStories)
  component(CodeMySpec.MCPServers.Stories.Tools.UpdateStory)
  component(CodeMySpec.MCPServers.Stories.Tools.DeleteStory)
  component(CodeMySpec.MCPServers.Stories.Tools.GetStory)
  component(CodeMySpec.MCPServers.Stories.Tools.ListStories)
  component(CodeMySpec.MCPServers.Stories.Tools.StartStoryInterview)
  component(CodeMySpec.MCPServers.Stories.Tools.StartStoryReview)
end

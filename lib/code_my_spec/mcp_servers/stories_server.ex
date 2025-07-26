defmodule CodeMySpec.MCPServers.StoriesServer do
  use Hermes.Server,
    name: "stories-server",
    version: "1.0.0",
    capabilities: [:tools, :resources, :prompts]

  # Tool components
  component(CodeMySpec.MCPServers.Stories.Tools.CreateStory)
  component(CodeMySpec.MCPServers.Stories.Tools.UpdateStory)
  component(CodeMySpec.MCPServers.Stories.Tools.DeleteStory)

  # Resource components
  component(CodeMySpec.MCPServers.Stories.Resources.Story)
  component(CodeMySpec.MCPServers.Stories.Resources.StoriesList)

  # Prompt components (conversation starters)
  component(CodeMySpec.MCPServers.Stories.Prompts.StoryInterview)
  component(CodeMySpec.MCPServers.Stories.Prompts.StoryReview)
end

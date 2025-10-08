%{
  hero: %{
    title: "CodeMySpec",
    tagline: "AI-Assisted Phoenix Development That Actually Ships",
    description: "Stop drowning in LLM-generated slop. Build production-ready Phoenix applications through structured workflows, clear component boundaries, and human oversight where it matters."
  },
  value_props: [
    %{
      icon: :structure,
      title: "Process Over Prompts",
      description: "Strict workflows guide AI through design and testing. No more compounding errors from vague specifications."
    },
    %{
      icon: :boundaries,
      title: "Phoenix-Native Architecture",
      description: "Context boundaries, dependency tracking, and type classification that enforces real architectural patterns."
    },
    %{
      icon: :oversight,
      title: "Human-in-the-Loop",
      description: "Approval gates and review steps at critical junctures. AI generates, you architect."
    },
    %{
      icon: :traceability,
      title: "Complete Traceability",
      description: "From user stories through components to tests. Know exactly why every piece of code exists."
    }
  ],
  features: [
    %{
      title: "User Story Management",
      description: "Web UI for organizing requirements with project scoping"
    },
    %{
      title: "Component Architecture",
      description: "Define Phoenix contexts with dependency tracking and type classification"
    },
    %{
      title: "MCP Integration",
      description: "Claude Code/Desktop integration via Hermes MCP servers"
    },
    %{
      title: "Session Orchestration",
      description: "Structured workflows for design and test generation with AI"
    },
    %{
      title: "Content Sync",
      description: "Git-based markdown/HTML/HEEx management with frontmatter"
    },
    %{
      title: "Multi-Tenancy",
      description: "Secure account-based scoping with OAuth2"
    }
  ],
  cta: %{
    primary: %{
      text: "Get Started",
      href: "/users/register"
    },
    secondary: %{
      text: "View Documentation",
      href: "/content"
    }
  },
  tech_stack: "Phoenix 1.8 • LiveView 1.1 • Ecto SQL • PostgreSQL • Oban • Hermes MCP"
}

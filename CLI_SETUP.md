# CodeMySpec CLI Setup Guide

## Overview

The CodeMySpec CLI has been successfully bootstrapped! This CLI provides a command-line interface for:

- **Session Management**: Start and manage Claude Code sessions in tmux
- **Code Generation**: Trigger code generation from stories
- **Interactive Dashboard**: Monitor active sessions with a TUI
- **Project Initialization**: Set up CodeMySpec in Phoenix projects

## Architecture

```
lib/
├── code_my_spec_cli.ex              # Main entry point
├── code_my_spec_cli/
│   ├── cli.ex                       # Optimus CLI parser
│   ├── session_manager.ex           # GenServer managing tmux sessions
│   ├── dashboard.ex                 # Ratatouille TUI dashboard
│   └── commands/
│       ├── init.ex                  # Initialize project
│       ├── generate.ex              # Generate code from stories
│       ├── dashboard.ex             # Launch dashboard
│       └── session.ex               # Session management commands
```

## Dependencies Added

- **optimus** (~> 0.5) - CLI argument parsing
- **ratatouille** (~> 0.5) - Terminal UI framework
- **burrito** (~> 1.5) - Binary packaging

## Prerequisites

Before using the CLI, ensure you have:

1. **tmux** installed: `brew install tmux` (macOS) or `apt-get install tmux` (Linux)
2. **claude** CLI available in PATH
3. **Elixir 1.18+** and **Erlang** (as specified in `.tool-versions`)

## Building the CLI

### Development Mode (escript)

For fast iteration during development:

```bash
# Install dependencies
mix deps.get

# Compile the project
mix compile

# Build the escript
mix escript.build

# Run the CLI
./codemyspec --help
```

### Production Mode (Burrito)

For distributable binaries:

```bash
# Build for your platform
MIX_ENV=prod mix release code_my_spec_cli

# Binaries will be in:
ls -la burrito_out/
# code_my_spec_cli_linux
# code_my_spec_cli_macos
# code_my_spec_cli_macos_arm
```

**Important**: During development, bump the version in `mix.exs` or Burrito will use cached binaries.

## Available Commands

### Initialize Project

```bash
codemyspec init
codemyspec init --force  # Overwrite existing config
```

Creates `.codemyspec/config.json` in the current directory.

### Generate Code

```bash
# Interactive mode (launches dashboard)
codemyspec generate --interactive
codemyspec generate -i

# Generate from specific story IDs
codemyspec generate STORY-123,STORY-124

# Target specific context
codemyspec generate STORY-123 --context UserContext
```

### Session Management

```bash
# List active sessions
codemyspec session list

# Attach to a session (Ctrl-B D to detach)
codemyspec session attach <session-id>

# Kill a session
codemyspec session kill <session-id>
```

### Dashboard

```bash
# Launch interactive TUI dashboard
codemyspec dashboard
```

**Dashboard Controls:**
- `j` / `↓` - Move down
- `k` / `↑` - Move up
- `a` - Attach to selected session
- `q` - Quit

## How It Works

### Session Management

1. **tmux Sessions**: Each code generation task runs in a detached tmux session
2. **Persistence**: Sessions continue running even after CLI exits
3. **Naming**: Sessions are named `cms-<random-id>` for easy identification
4. **Monitoring**: The SessionManager GenServer tracks all active sessions

### Workflow

```
User runs: codemyspec generate STORY-123
    ↓
CLI creates detached tmux session: cms-a3f2e1
    ↓
tmux session starts: claude
    ↓
Claude receives prompt: "Generate code for Story STORY-123..."
    ↓
User can:
  - Attach to watch progress (codemyspec session attach a3f2e1)
  - Monitor via dashboard (codemyspec dashboard)
  - Let it run in background
```

## Integration with MCP

The CLI is designed to work with your existing MCP servers:

- **StoriesServer**: Fetch story details
- **ComponentsServer**: Access component specifications
- **AnalyticsAdminServer**: Track generation metrics

### Future Enhancements

```elixir
# In commands/generate.ex
defp fetch_story_details(story_id) do
  # Call MCP server to get full story details
  # Build comprehensive prompt from story data
end
```

## Testing Locally

```bash
# 1. Build the escript
mix escript.build

# 2. Initialize in a test directory
cd ~/tmp/test-phoenix-app
~/code_my_spec/codemyspec init

# 3. Verify config created
cat .codemyspec/config.json

# 4. Test session list (should be empty)
~/code_my_spec/codemyspec session list

# 5. Start a test session
~/code_my_spec/codemyspec generate TEST-1

# 6. View in dashboard
~/code_my_spec/codemyspec dashboard

# 7. Attach to session
~/code_my_spec/codemyspec session attach <id>

# 8. Detach from session
# Press: Ctrl-B then D

# 9. Kill session
~/code_my_spec/codemyspec session kill <id>
```

## Deployment

### Homebrew Tap

Create a formula in your tap repository:

```ruby
# Formula/codemyspec.rb
class Codemyspec < Formula
  desc "AI-powered Phoenix code generator"
  homepage "https://github.com/yourname/code_my_spec"
  url "https://github.com/yourname/code_my_spec/releases/download/v0.1.0/codemyspec-darwin-arm64.tar.gz"
  sha256 "..."
  version "0.1.0"

  def install
    bin.install "codemyspec"
  end

  test do
    system "#{bin}/codemyspec", "--version"
  end
end
```

Users install with:

```bash
brew tap yourname/tap
brew install codemyspec
```

### Direct Binary

```bash
# Download from GitHub releases
curl -L https://github.com/yourname/code_my_spec/releases/download/v0.1.0/codemyspec-linux -o codemyspec
chmod +x codemyspec
sudo mv codemyspec /usr/local/bin/
```

## Troubleshooting

### "tmux not found"

```bash
# macOS
brew install tmux

# Ubuntu/Debian
sudo apt-get install tmux

# Verify
which tmux
```

### "claude not found"

The SessionManager expects `claude` to be available. Update `session_manager.ex:65` if your Claude CLI has a different name (e.g., `claude-code`).

### Sessions don't appear in dashboard

Sessions persist in tmux. List tmux sessions directly:

```bash
tmux list-sessions
# Should show: cms-<id>: ...

# Manually attach to tmux session
tmux attach -t cms-<id>
```

### Burrito binary doesn't reflect changes

Burrito caches extracted binaries. Either:

1. Bump version in `mix.exs`
2. Clear cache: `rm -rf ~/.cache/burrito/code_my_spec_cli`

## Next Steps

1. **MCP Integration**: Connect to StoriesServer for real story data
2. **Progress Tracking**: Parse Claude output to track completion status
3. **Error Recovery**: Handle tmux session crashes gracefully
4. **Config Management**: Support advanced `.codemyspec/config.json` options
5. **Testing**: Add ExUnit tests for commands and session management

## Resources

- [Burrito Docs](https://hexdocs.pm/burrito/)
- [Optimus Docs](https://hexdocs.pm/optimus/)
- [Ratatouille GitHub](https://github.com/ndreynolds/ratatouille)
- [tmux Cheat Sheet](https://tmuxcheatsheet.com/)

## Support

For issues or questions:

- GitHub Issues: https://github.com/yourname/code_my_spec/issues
- Documentation: https://codemyspec.com/docs

#!/bin/bash
# Start CodeMySpec CLI with tmux orchestration
# This script creates a tmux session and launches the Ratatouille TUI in Window 0
# Automatically detects if running in dev (uses mix) or prod (uses Burrito binary)

set -e

SESSION_NAME="codemyspec-main"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Determine which command to run based on MIX_ENV
if [ "$MIX_ENV" = "cli" ]; then
  # Development mode: Use mix
  MODE="development"
  COMMAND="cd $PROJECT_DIR && mix cli"
  echo "Starting CodeMySpec CLI with tmux orchestration..."
  echo "Mode: DEVELOPMENT (using mix cli)"
  echo "Project directory: $PROJECT_DIR"
else
  # Production mode: Use Burrito binary
  MODE="production"
  BURRITO_BINARY="$PROJECT_DIR/burrito_out/code_my_spec_cli_macos_m1"
  COMMAND="$BURRITO_BINARY"
  echo "Starting CodeMySpec CLI with tmux orchestration..."
  echo "Mode: PRODUCTION (using Burrito binary)"
  echo "Binary: $BURRITO_BINARY"

  if [ ! -f "$BURRITO_BINARY" ]; then
    echo ""
    echo "Error: Burrito binary not found at: $BURRITO_BINARY"
    echo "To build the production binary, run: mix release"
    exit 1
  fi
fi

echo ""

# Kill any existing session with the same name
if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
  echo "Existing session '$SESSION_NAME' found. Killing it..."
  tmux kill-session -t "$SESSION_NAME"
fi

# Create new tmux session with Ratatouille TUI in Window 0
echo "Creating tmux session: $SESSION_NAME"
if [ "$MIX_ENV" = "cli" ]; then
  tmux new-session -d \
    -s "$SESSION_NAME" \
    -n "ratatouille" \
    -c "$PROJECT_DIR" \
    "$COMMAND"
else
  tmux new-session -d \
    -s "$SESSION_NAME" \
    -n "ratatouille" \
    "$COMMAND"
fi

# Configure tmux status line with helpful info
tmux set-option -t "$SESSION_NAME" \
  status-right "#[fg=cyan]CodeMySpec | CTRL-B [0-9] switch | [ESC] list"

# Set some useful options
tmux set-option -t "$SESSION_NAME" base-index 0
tmux set-option -t "$SESSION_NAME" renumber-windows on

echo ""
echo "✓ Tmux session created: $SESSION_NAME"
echo "✓ CodeMySpec CLI is running in Window 0 ($MODE mode)"
echo ""
echo "Attaching to session..."
echo ""
echo "Tmux shortcuts:"
echo "  Ctrl+B 0     - Return to CodeMySpec dashboard"
echo "  Ctrl+B 1-9   - Switch to session window"
echo "  Ctrl+B n/p   - Next/Previous window"
echo "  Ctrl+B d     - Detach (session runs in background)"
echo "  Ctrl+B [     - Enter scroll mode (q to exit)"
echo ""

if [ "$MODE" = "development" ]; then
  echo "Development mode tips:"
  echo "  - Code changes require restarting the CLI"
  echo "  - Use 'mix release' to build production binary"
  echo "  - Unset MIX_ENV to use production mode"
  echo ""
fi

# Attach to the session
tmux attach-session -t "$SESSION_NAME"

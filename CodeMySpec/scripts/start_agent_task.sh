#!/bin/bash
# start_agent_task.sh
# Start an agent task session and return the prompt for Claude
#
# Usage:
#   CodeMySpec/scripts/start_agent_task.sh component_spec MyApp.Accounts
#
# The script calls the Elixir CLI, parses the structured output,
# exports session tracking variables, and returns just the prompt.
#
# Environment variables set (for subsequent commands):
#   CMS_SESSION_ID      - Database session ID (for stop hook)
#   CMS_SESSION_TYPE    - Session type name
#   CMS_COMPONENT       - Component name
#   CMS_STATUS          - "ok" or "error"
#
# Also writes session ID to .code_my_spec/internal/current_session/session_id

set -euo pipefail

SESSION_TYPE="${1:-}"
MODULE_NAME="${2:-}"

if [ -z "$SESSION_TYPE" ] || [ -z "$MODULE_NAME" ]; then
    echo "Usage: start_agent_task.sh <session_type> <module_name>" >&2
    echo "Example: start_agent_task.sh component_spec MyApp.Accounts" >&2
    exit 1
fi

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Project root is two levels up from CodeMySpec/scripts/
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Call the Elixir CLI and capture output
OUTPUT=$(cd "$PROJECT_ROOT" && MIX_ENV=cli mix cli start-agent-task -t "$SESSION_TYPE" -m "$MODULE_NAME" 2>/dev/null)

# Function to extract a simple field value (single line after marker)
extract_field() {
    local field="$1"
    echo "$OUTPUT" | grep -A1 "^:::${field}:::$" | tail -1
}

# Function to extract multiline content between heredoc markers
extract_multiline() {
    local field="$1"
    local start_marker="<<<${field}_START"
    local end_marker=">>>${field}_END"

    echo "$OUTPUT" | sed -n "/${start_marker}/,/${end_marker}/p" | sed '1d;$d'
}

# Extract all fields
CMS_SESSION_ID=$(extract_field "SESSION_ID")
CMS_SESSION_TYPE=$(extract_field "SESSION_TYPE")
CMS_COMPONENT=$(extract_field "COMPONENT")
CMS_STATUS=$(extract_field "STATUS")

# Check for errors
if [ "$CMS_STATUS" = "error" ]; then
    CMS_ERROR=$(extract_multiline "ERROR")
    echo "Error starting agent task: $CMS_ERROR" >&2
    exit 1
fi

# Extract the prompt
CMS_PROMPT=$(extract_multiline "PROMPT")

# Export variables for subsequent commands in the same shell
export CMS_SESSION_ID
export CMS_SESSION_TYPE
export CMS_COMPONENT
export CMS_STATUS

# Write session ID to file for stop hook to read
mkdir -p .code_my_spec/internal/current_session
echo "$CMS_SESSION_ID" > .code_my_spec/internal/current_session/session_id

# Output just the prompt for Claude to consume
echo "$CMS_PROMPT"

#!/bin/bash
# evaluate_agent_task.sh
# Evaluate/validate an agent task session's output
#
# Usage:
#   CodeMySpec/scripts/evaluate_agent_task.sh <session_id>
#
# Called by stop hook to validate Claude's output against the session type's
# evaluate function. Returns feedback if validation fails.

set -euo pipefail

# Get session ID from: arg > env var > .code_my_spec/internal/current_session/session_id file
SESSION_ID="${1:-${CMS_SESSION_ID:-}}"

if [ -z "$SESSION_ID" ] && [ -f .code_my_spec/internal/current_session/session_id ]; then
    SESSION_ID=$(cat .code_my_spec/internal/current_session/session_id)
fi

if [ -z "$SESSION_ID" ]; then
    echo "Usage: evaluate_agent_task.sh <session_id>" >&2
    echo "Or set CMS_SESSION_ID env var, or have .code_my_spec/internal/current_session/session_id file" >&2
    exit 1
fi

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Project root is two levels up from CodeMySpec/scripts/
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Call the Elixir CLI and capture output (stderr goes to a temp file for error reporting)
STDERR_FILE=$(mktemp)
OUTPUT=$(cd "$PROJECT_ROOT" && MIX_ENV=cli mix cli evaluate-agent-task -s "$SESSION_ID" 2>"$STDERR_FILE") || {
    echo "CLI command failed. stderr:" >&2
    cat "$STDERR_FILE" >&2
    rm -f "$STDERR_FILE"
    exit 1
}
rm -f "$STDERR_FILE"

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

# Extract status
CMS_EVAL_STATUS=$(extract_field "STATUS")

# Exit codes:
# 0 - stdout/stderr not shown
# 2 - show stderr to model and continue conversation
# Other - show stderr to user only

case "$CMS_EVAL_STATUS" in
    "valid")
        echo "Component specification is valid!" >&2
        exit 1  # Show to user that it ran
        ;;
    "invalid")
        FEEDBACK=$(extract_multiline "FEEDBACK")
        echo "$FEEDBACK" >&2
        exit 2  # Show to model so it can fix
        ;;
    "error")
        ERROR=$(extract_multiline "ERROR")
        echo "Evaluate error: $ERROR" >&2
        exit 1  # Show to user
        ;;
    *)
        echo "Evaluate hook ran - status: $CMS_EVAL_STATUS" >&2
        echo "Session ID: $SESSION_ID" >&2
        exit 1  # Show to user
        ;;
esac

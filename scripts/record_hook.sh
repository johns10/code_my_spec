#!/bin/bash
# Records hook inputs to a log file (one JSON per line)
# Usage: Add to hooks.json as a command hook

LOG_FILE="${HOOK_LOG_FILE:-$HOME/.claude/hook_log.jsonl}"

# Read stdin and append to log file
cat >> "$LOG_FILE"
echo >> "$LOG_FILE"

# Output empty JSON to allow hook to continue
echo '{}'

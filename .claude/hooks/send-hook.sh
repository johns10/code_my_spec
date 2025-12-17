#!/bin/bash
# Generic hook forwarder - send-hook.sh

HOOK_NAME="$1"

if [ -z "$HOOK_NAME" ]; then
    echo "Error: Hook name required as first argument" >&2
    exit 1
fi

# Read hook input from stdin
HOOK_INPUT=$(cat)

# Check for hook URL
if [ -z "$CODE_MY_SPEC_HOOK_URL" ]; then
    echo "Warning: CODE_MY_SPEC_HOOK_URL not set" >&2
    exit 0
fi

# Combine hook name with input data and context
PAYLOAD=$(jq -n \
    --arg hook_name "$HOOK_NAME" \
    --argjson hook_data "$HOOK_INPUT" \
    --arg session_id "${CODE_MY_SPEC_SESSION_ID:-}" \
    --arg interaction_id "${CODE_MY_SPEC_INTERACTION_ID:-}" \
    '{hook_name: $hook_name, hook_data: $hook_data, session_id: $session_id, interaction_id: $interaction_id}')

# Forward to hook server
curl -s -X POST \
    -H "Content-Type: application/json" \
    -d "$PAYLOAD" \
    "$CODE_MY_SPEC_HOOK_URL"

exit 0
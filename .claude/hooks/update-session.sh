#!/bin/bash

# SessionStart hook to update external conversation ID in Code My Spec VSCode extension
# This hook captures Claude CLI conversation ID and sends it back to the extension's backend

# Read hook input from stdin
HOOK_INPUT=$(cat)

# Extract Claude's session_id (conversation ID) from the hook input
CLAUDE_SESSION_ID=$(echo "$HOOK_INPUT" | jq -r '.session_id // empty')

# Check if we have the required environment variables from the extension
if [ -z "$CODE_MY_SPEC_SESSION_ID" ] || [ -z "$CODE_MY_SPEC_API_URL" ] || [ -z "$CODE_MY_SPEC_API_TOKEN" ]; then
  # Not running from Code My Spec extension, exit silently
  echo "Warning: Required variables for update-session not found" >&2
  exit 0
fi

# Check if we got a Claude session ID
if [ -z "$CLAUDE_SESSION_ID" ]; then
  echo "Warning: Could not extract session_id from hook input" >&2
  exit 0
fi

# Update the session's external conversation ID via API
HTTP_CODE=$(curl -s -w "%{http_code}" -o /tmp/update_session_response.txt \
  -X PUT \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $CODE_MY_SPEC_API_TOKEN" \
  -d "{\"external_conversation_id\": \"$CLAUDE_SESSION_ID\"}" \
  "$CODE_MY_SPEC_API_URL/api/sessions/$CODE_MY_SPEC_SESSION_ID/external_conversation_id")

if [ "$HTTP_CODE" -ge 200 ] && [ "$HTTP_CODE" -lt 300 ]; then
  echo "Successfully updated session $CODE_MY_SPEC_SESSION_ID with Claude conversation ID: $CLAUDE_SESSION_ID"
else
  echo "Failed to update session (HTTP $HTTP_CODE)" >&2
  cat /tmp/update_session_response.txt >&2
  exit 0  # Don't fail the hook, just log the error
fi

# Clean up temp file
rm -f /tmp/update_session_response.txt

exit 0

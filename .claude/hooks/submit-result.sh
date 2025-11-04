#!/bin/bash

# SessionEnd hook to notify Code My Spec extension that Claude command has completed
# This allows the terminal executor to properly wait for Claude commands to finish
# The orchestrator will handle submitting results to the backend API

# Read hook input from stdin
HOOK_INPUT=$(cat)

# Check if we have the callback URL from the extension
if [ -z "$CODE_MY_SPEC_CALLBACK_URL" ]; then
  # Not running from Code My Spec extension, exit silently
  exit 0
fi

# Extract reason from hook input for logging
REASON=$(echo "$HOOK_INPUT" | jq -r '.reason // "unknown"')

echo "Claude session ended (reason: $REASON), notifying extension..."

# Notify the extension via callback URL
HTTP_CODE=$(curl -s -w "%{http_code}" -o /tmp/callback_response.txt \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{"reason": "'"$REASON"'"}' \
  "$CODE_MY_SPEC_CALLBACK_URL")

if [ "$HTTP_CODE" -ge 200 ] && [ "$HTTP_CODE" -lt 300 ]; then
  echo "Successfully notified extension via callback URL"
else
  echo "Failed to notify extension via callback (HTTP $HTTP_CODE)" >&2
  cat /tmp/callback_response.txt >&2
fi

rm -f /tmp/callback_response.txt

exit 0

#!/bin/bash
set -e

# Usage: ./scripts/deploy-secrets.sh uat|prod

if [ -z "$1" ]; then
  echo "Usage: ./scripts/deploy-secrets.sh uat|prod"
  exit 1
fi

ENV=$1
APP_NAME="code-my-spec-${ENV}"
ENV_FILE=".env.${ENV}"

if [ ! -f "$ENV_FILE" ]; then
  echo "Error: $ENV_FILE not found"
  exit 1
fi

echo "Deploying secrets from $ENV_FILE to $APP_NAME..."

# Read .env file and build fly secrets set command
# Skip empty lines and comments
SECRETS=""
while IFS= read -r line || [ -n "$line" ]; do
  # Skip empty lines and comments
  if [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]]; then
    continue
  fi

  # Extract key=value
  if [[ "$line" =~ ^[[:space:]]*([A-Za-z0-9_]+)[[:space:]]*=[[:space:]]*(.*)[[:space:]]*$ ]]; then
    KEY="${BASH_REMATCH[1]}"
    VALUE="${BASH_REMATCH[2]}"

    # Add to secrets string
    if [ -n "$SECRETS" ]; then
      SECRETS="$SECRETS $KEY=$VALUE"
    else
      SECRETS="$KEY=$VALUE"
    fi
  fi
done < "$ENV_FILE"

if [ -z "$SECRETS" ]; then
  echo "No secrets found in $ENV_FILE"
  exit 1
fi

# Deploy secrets
echo "Setting secrets..."
fly secrets set $SECRETS -a "$APP_NAME"

echo "Done! Secrets deployed to $APP_NAME"
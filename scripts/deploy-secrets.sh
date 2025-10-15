#!/bin/bash
set -euo pipefail

# Deploy secrets from .env files to Fly.io applications
# Usage: ./scripts/deploy-secrets.sh uat|prod

# Color output for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper functions
error() {
    echo -e "${RED}Error: $1${NC}" >&2
    exit 1
}

info() {
    echo -e "${GREEN}$1${NC}"
}

warn() {
    echo -e "${YELLOW}$1${NC}"
}

# Validate arguments
if [ $# -ne 1 ]; then
    error "Usage: ./scripts/deploy-secrets.sh uat|prod"
fi

ENV=$1
APP_NAME="code-my-spec-${ENV}"
ENV_FILE=".env.${ENV}"

# Validate environment argument
if [[ ! "$ENV" =~ ^(uat|prod)$ ]]; then
    error "Invalid environment: $ENV. Must be 'uat' or 'prod'"
fi

# Check if .env file exists
if [ ! -f "$ENV_FILE" ]; then
    error "$ENV_FILE not found"
fi

# Check if fly CLI is installed
if ! command -v fly &> /dev/null; then
    error "fly CLI is not installed. Install it from https://fly.io/docs/flyctl/install/"
fi

info "Deploying secrets from $ENV_FILE to $APP_NAME..."

# Parse .env file and build secrets array
declare -a SECRETS_ARRAY
LINE_NUM=0

while IFS= read -r line || [ -n "$line" ]; do
    LINE_NUM=$((LINE_NUM + 1))

    # Skip empty lines and comments
    if [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]]; then
        continue
    fi

    # Match KEY=VALUE pattern
    if [[ "$line" =~ ^[[:space:]]*([A-Za-z0-9_]+)[[:space:]]*=[[:space:]]*(.*)[[:space:]]*$ ]]; then
        KEY="${BASH_REMATCH[1]}"
        VALUE="${BASH_REMATCH[2]}"

        # Remove surrounding quotes from value if present
        VALUE="${VALUE#\"}"
        VALUE="${VALUE%\"}"
        VALUE="${VALUE#\'}"
        VALUE="${VALUE%\'}"

        SECRETS_ARRAY+=("$KEY=$VALUE")
    else
        warn "Skipping invalid line $LINE_NUM: $line"
    fi
done < "$ENV_FILE"

# Check if any secrets were found
if [ ${#SECRETS_ARRAY[@]} -eq 0 ]; then
    error "No valid secrets found in $ENV_FILE"
fi

info "Found ${#SECRETS_ARRAY[@]} secret(s) to deploy"

# Deploy secrets to Fly.io
info "Setting secrets on $APP_NAME..."
if fly secrets set "${SECRETS_ARRAY[@]}" -a "$APP_NAME"; then
    info "Successfully deployed secrets to $APP_NAME"
else
    error "Failed to deploy secrets to $APP_NAME"
fi

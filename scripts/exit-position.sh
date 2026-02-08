#!/bin/bash

# Yield.xyz Exit Position Script
# Usage: ./exit-position.sh <yield_id> <address> <amount>
# Example: ./exit-position.sh base-usdc-aave-v3-lending 0x742d... 50000000

# Auto-detect config path: local (extracted ZIP) or installed (OpenClaw/ClawHub/Clawdbot)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_DIR=""
for dir in "${SCRIPT_DIR}/.." "${HOME}/.openclaw/skills/yield-finder" "${HOME}/.clawhub/skills/yield-finder" "${HOME}/.clawdbot/skills/yield-finder"; do
  if [ -f "${dir}/config.json" ]; then
    CONFIG_DIR="$dir"
    break
  fi
done
if [ -z "$CONFIG_DIR" ]; then
  echo "Error: config.json not found. Run from the yield-finder directory or install to ~/.clawhub/skills/yield-finder/"
  exit 1
fi

# Load config (supports env var overrides)
API_KEY="${YIELDS_API_KEY:-$(jq -r '.apiKey' "${CONFIG_DIR}/config.json")}"
API_URL="${YIELDS_API_URL:-$(jq -r '.apiUrl' "${CONFIG_DIR}/config.json")}"

YIELD_ID=$1
ADDRESS=$2
AMOUNT=$3

# Validation
if [ -z "$YIELD_ID" ] || [ -z "$ADDRESS" ] || [ -z "$AMOUNT" ]; then
  echo "Error: Missing required arguments"
  echo "Usage: ./exit-position.sh <yield_id> <address> <amount>"
  echo "Example: ./exit-position.sh base-usdc-aave-v3-lending 0x742d... 50000000"
  echo ""
  echo "Note: Amount must be a raw integer string (e.g., '50000000' for 50 USDC)"
  echo "      Formula: raw_amount = human_amount * 10^decimals (USDC=6, ETH=18)"
  exit 1
fi

# Safety Check: Validate Amount Format (must be raw integer string)
if ! [[ "$AMOUNT" =~ ^[0-9]+$ ]]; then
  echo "Error: Amount must be a raw integer string (e.g., '50000000' not '50' or '0.5')"
  echo "Formula: raw_amount = human_amount * 10^decimals"
  echo "  50 USDC (6 decimals) = 50000000"
  echo "  0.5 ETH (18 decimals) = 500000000000000000"
  exit 1
fi

# Build payload
PAYLOAD=$(jq -n \
  --arg yieldId "$YIELD_ID" \
  --arg address "$ADDRESS" \
  --arg amount "$AMOUNT" \
  '{yieldId: $yieldId, address: $address, arguments: {amount: $amount}}')

# Call API
# Returns: Action { id, intent, type, yieldId, address, amount, amountRaw, amountUsd, status, executionPattern, transactions: Transaction[], createdAt, completedAt }
# IMPORTANT: unsignedTransaction in each Transaction is a JSON STRING, not an object! Parse it: jq -r '.unsignedTransaction' | jq '.'
RESPONSE=$(curl -s -X POST "${API_URL}/actions/exit" \
  -H "x-api-key: ${API_KEY}" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD")

# Better error handling
if echo "$RESPONSE" | jq -e '.error // .message' > /dev/null 2>&1; then
  ERROR_MSG=$(echo "$RESPONSE" | jq -r '.message // .error // "Unknown error"')
  ERROR_CODE=$(echo "$RESPONSE" | jq -r '.statusCode // .code // "N/A"')
  echo "Error from Yield.xyz API: $ERROR_MSG (code: $ERROR_CODE)"
  echo ""
  echo "Common causes:"
  echo "  - No active position to exit (check with check-portfolio.sh first)"
  echo "  - Amount exceeds current balance"
  echo "  - Invalid yield ID (use find-yields.sh to discover valid IDs)"
  exit 1
fi

echo "$RESPONSE" | jq '.'

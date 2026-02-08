#!/bin/bash

# Yield.xyz Position Management Script
# Usage: ./manage-position.sh <yield_id> <address> <action> [passthrough] [arguments_json]
# Example: ./manage-position.sh ethereum-eth-lido-staking 0x742d... CLAIM_REWARDS "base64passthrough"
#
# The passthrough value comes from the pendingActions array in the balances response.
# Each pendingAction object contains: { intent, type, passthrough, arguments? }
#
# Discover available actions by checking pendingActions[] in the balances response.
# Each pendingAction has: { type, passthrough, arguments? }
# The 'type' field is the action to pass here.

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
ACTION=$3
PASSTHROUGH=$4
ARGS_JSON=${5:-"{}"}

# Validation
if [ -z "$YIELD_ID" ] || [ -z "$ADDRESS" ] || [ -z "$ACTION" ]; then
  echo "Position Management - Execute actions on your yield positions"
  echo ""
  echo "Usage: ./manage-position.sh <yield_id> <address> <action> [passthrough] [arguments_json]"
  echo ""
  echo "Discover available actions by running check-portfolio.sh first."
  echo "Look for pendingActions[].type in the output."
  echo ""
  echo "Step-by-step workflow:"
  echo "  1. Check your position for pending actions:"
  echo "     ./check-portfolio.sh <yield_id> <address>"
  echo ""
  echo "  2. Look for pendingActions[] in the output. Each has:"
  echo "     { \"type\": \"CLAIM_REWARDS\", \"passthrough\": \"eyJhbGci...\" }"
  echo ""
  echo "  3. Copy the passthrough value and run:"
  echo "     ./manage-position.sh <yield_id> <address> CLAIM_REWARDS \"eyJhbGci...\""
  echo ""
  echo "  4. The response contains unsignedTransaction(s) to sign."
  echo ""
  echo "Examples:"
  echo "  ./manage-position.sh ethereum-eth-lido-staking 0x742d... CLAIM_REWARDS \"eyJhbGci...\""
  echo "  ./manage-position.sh cosmos-atom-cosmoshub-staking 0x742d... RESTAKE_REWARDS \"base64data\""
  exit 1
fi

# Build payload (API validates the action type)
PAYLOAD=$(jq -n \
  --arg yieldId "$YIELD_ID" \
  --arg address "$ADDRESS" \
  --arg action "$ACTION" \
  --arg passthrough "${PASSTHROUGH:-}" \
  --argjson arguments "$ARGS_JSON" \
  '{yieldId: $yieldId, address: $address, action: $action, passthrough: $passthrough, arguments: $arguments}')

# Call API
# Returns: Action { id, intent, type, yieldId, address, amount, amountRaw, amountUsd, status, executionPattern, transactions: Transaction[], createdAt, completedAt }
# IMPORTANT: unsignedTransaction in each Transaction is a JSON STRING, not an object! Parse it: jq -r '.unsignedTransaction' | jq '.'
RESPONSE=$(curl -s -X POST "${API_URL}/actions/manage" \
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
  echo "  - Missing or invalid passthrough value (get from check-portfolio.sh)"
  echo "  - No pending action of type '$ACTION' for this position"
  echo "  - Invalid yield ID"
  exit 1
fi

echo "$RESPONSE" | jq '.'

#!/bin/bash

# Yield.xyz Manage Position
# Usage: ./manage-position.sh <yield_id> <address> <action> <passthrough> [arguments_json]
# Example: ./manage-position.sh ethereum-eth-lido-staking 0x742d... CLAIM_REWARDS "eyJhbGci..."
#
# Discover available actions by checking pendingActions[] in the balances response.
# Each pendingAction has: { type, passthrough, arguments? }
# The 'type' and 'passthrough' fields are required here.
# If the pendingAction has an 'arguments' schema, pass matching JSON as arguments_json.

# Auto-detect config path
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_DIR=""
for dir in "${SCRIPT_DIR}/.." "${HOME}/.openclaw/skills/yield-agent" "${HOME}/.clawhub/skills/yield-agent" "${HOME}/.clawdbot/skills/yield-agent"; do
  if [ -f "${dir}/config.json" ]; then
    CONFIG_DIR="$dir"
    break
  fi
done
if [ -z "$CONFIG_DIR" ]; then
  echo "Error: config.json not found. Run from the yield-agent directory or install to ~/.clawhub/skills/yield-agent/"
  exit 1
fi

# Load config
API_KEY="${YIELDS_API_KEY:-$(jq -r '.apiKey' "${CONFIG_DIR}/config.json")}"
API_URL="${YIELDS_API_URL:-$(jq -r '.apiUrl' "${CONFIG_DIR}/config.json")}"

YIELD_ID=$1
ADDRESS=$2
ACTION=$3
PASSTHROUGH=$4
ARGS_JSON=${5:-"{}"}

# Validation
if [ -z "$YIELD_ID" ] || [ -z "$ADDRESS" ] || [ -z "$ACTION" ] || [ -z "$PASSTHROUGH" ]; then
  echo "Manage Position — claim rewards, restake, redelegate, etc."
  echo ""
  echo "Usage: ./manage-position.sh <yield_id> <address> <action> <passthrough> [arguments_json]"
  echo ""
  echo "Discover available actions:"
  echo "  1. ./check-portfolio.sh <yield_id> <address>"
  echo "  2. Look for pendingActions[] — each has { type, passthrough, arguments? }"
  echo "  3. Pass the type and passthrough here"
  echo ""
  echo "Examples:"
  echo "  ./manage-position.sh ethereum-eth-lido-staking 0x742d... CLAIM_REWARDS \"eyJhbGci...\""
  echo "  ./manage-position.sh cosmos-atom-cosmoshub-staking 0x742d... RESTAKE_REWARDS \"base64data\" '{\"validatorAddress\":\"cosmosvaloper1...\"}'"
  exit 1
fi

# Build payload
PAYLOAD=$(jq -n \
  --arg yieldId "$YIELD_ID" \
  --arg address "$ADDRESS" \
  --arg action "$ACTION" \
  --arg passthrough "$PASSTHROUGH" \
  --argjson arguments "$ARGS_JSON" \
  '{yieldId: $yieldId, address: $address, action: $action, passthrough: $passthrough, arguments: $arguments}')

# Call API
RESPONSE=$(curl -s -X POST "${API_URL}/v1/actions/manage" \
  -H "x-api-key: ${API_KEY}" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD")

# Error handling
if echo "$RESPONSE" | jq -e '.error // .message' > /dev/null 2>&1; then
  ERROR_MSG=$(echo "$RESPONSE" | jq -r '.message // .error // "Unknown error"')
  ERROR_CODE=$(echo "$RESPONSE" | jq -r '.statusCode // .code // "N/A"')
  echo "Error from Yield.xyz API: $ERROR_MSG (code: $ERROR_CODE)"
  echo ""
  echo "Common causes:"
  echo "  - Invalid passthrough (must come from check-portfolio.sh pendingActions[])"
  echo "  - No pending action of type '$ACTION' for this position"
  echo "  - Missing required arguments (check pendingAction.arguments schema)"
  exit 1
fi

echo "$RESPONSE" | jq '.'

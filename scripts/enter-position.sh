#!/bin/bash

# Yield.xyz Enter Position
# Usage: ./enter-position.sh <yield_id> <address> <arguments_json>
# Example: ./enter-position.sh base-usdc-aave-v3-lending 0x742d... '{"amount":"100"}'
# Example: ./enter-position.sh cosmos-atom-cosmoshub-staking 0x742d... '{"amount":"10","validatorAddress":"cosmosvaloper1..."}'
#
# arguments_json must match the yield's mechanics.arguments.enter schema.
# Fetch the yield first (GET /v1/yields/{yieldId}) to discover required fields.
# Amounts are human-readable: "100" = 100 USDC, "1" = 1 ETH.

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
ARGS_JSON=$3

# Validation
if [ -z "$YIELD_ID" ] || [ -z "$ADDRESS" ] || [ -z "$ARGS_JSON" ]; then
  echo "Enter Position — create unsigned transactions to enter a yield"
  echo ""
  echo "Usage: ./enter-position.sh <yield_id> <address> <arguments_json>"
  echo ""
  echo "Examples:"
  echo "  ./enter-position.sh base-usdc-aave-v3-lending 0x742d... '{\"amount\":\"100\"}'"
  echo "  ./enter-position.sh cosmos-atom-cosmoshub-staking 0x742d... '{\"amount\":\"10\",\"validatorAddress\":\"cosmosvaloper1...\"}'"
  echo ""
  echo "Discover required arguments by fetching the yield first:"
  echo "  ./get-yield-info.sh <yield_id>  →  look at mechanics.arguments.enter"
  echo ""
  echo "Amounts are human-readable: '100' = 100 USDC, '1' = 1 ETH"
  exit 1
fi

# Validate arguments_json is valid JSON
if ! echo "$ARGS_JSON" | jq '.' > /dev/null 2>&1; then
  echo "Error: arguments_json must be valid JSON"
  echo "Example: '{\"amount\":\"100\"}'"
  exit 1
fi

# Build payload
PAYLOAD=$(jq -n \
  --arg yieldId "$YIELD_ID" \
  --arg address "$ADDRESS" \
  --argjson arguments "$ARGS_JSON" \
  '{yieldId: $yieldId, address: $address, arguments: $arguments}')

# Call API
RESPONSE=$(curl -s -X POST "${API_URL}/v1/actions/enter" \
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
  echo "  - Missing required arguments (check mechanics.arguments.enter on the yield)"
  echo "  - Amount below minimum (check mechanics.entryLimits)"
  echo "  - Invalid yield ID (use find-yields.sh to discover valid IDs)"
  echo "  - Invalid address format"
  exit 1
fi

echo "$RESPONSE" | jq '.'

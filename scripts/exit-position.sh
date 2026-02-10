#!/bin/bash

# Yield.xyz Exit Position
# Usage: ./exit-position.sh <yield_id> <address> <arguments_json>
# Example: ./exit-position.sh base-usdc-aave-v3-lending 0x742d... '{"amount":"50"}'
#
# arguments_json must match the yield's mechanics.arguments.exit schema.
# Fetch the yield first (GET /v1/yields/{yieldId}) to discover required fields.
# Amounts are human-readable: "50" = 50 USDC, "0.5" = 0.5 ETH.

# Auto-detect config path
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_DIR=""
for dir in "${SCRIPT_DIR}/.." "${HOME}/.openclaw/skills/yield-agent" "${HOME}/.clawhub/skills/yield-agent" "${HOME}/.clawdbot/skills/yield-agent"; do
  if [ -f "${dir}/skill.json" ]; then
    CONFIG_DIR="$dir"
    break
  fi
done
if [ -z "$CONFIG_DIR" ]; then
  echo "Error: skill.json not found. Run from the yield-agent directory or install to ~/.clawhub/skills/yield-agent/"
  exit 1
fi

# Load config
API_KEY="${YIELDS_API_KEY:-$(jq -r '.api.apiKey' "${CONFIG_DIR}/skill.json")}"
API_URL="${YIELDS_API_URL:-$(jq -r '.api.baseUrl' "${CONFIG_DIR}/skill.json")}"

YIELD_ID=$1
ADDRESS=$2
ARGS_JSON=$3

# Validation
if [ -z "$YIELD_ID" ] || [ -z "$ADDRESS" ] || [ -z "$ARGS_JSON" ]; then
  echo "Exit Position — create unsigned transactions to exit a yield"
  echo ""
  echo "Usage: ./exit-position.sh <yield_id> <address> <arguments_json>"
  echo ""
  echo "Examples:"
  echo "  ./exit-position.sh base-usdc-aave-v3-lending 0x742d... '{\"amount\":\"50\"}'"
  echo ""
  echo "Discover required arguments by fetching the yield first:"
  echo "  ./get-yield-info.sh <yield_id>  →  look at mechanics.arguments.exit"
  echo ""
  echo "Amounts are human-readable: '50' = 50 USDC, '0.5' = 0.5 ETH"
  exit 1
fi

# Validate arguments_json is valid JSON
if ! echo "$ARGS_JSON" | jq '.' > /dev/null 2>&1; then
  echo "Error: arguments_json must be valid JSON"
  echo "Example: '{\"amount\":\"50\"}'"
  exit 1
fi

# Build payload
PAYLOAD=$(jq -n \
  --arg yieldId "$YIELD_ID" \
  --arg address "$ADDRESS" \
  --argjson arguments "$ARGS_JSON" \
  '{yieldId: $yieldId, address: $address, arguments: $arguments}')

# Call API
RESPONSE=$(curl -s -X POST "${API_URL}/v1/actions/exit" \
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
  echo "  - Missing required arguments (check mechanics.arguments.exit on the yield)"
  echo "  - Insufficient balance (check with check-portfolio.sh first)"
  echo "  - Invalid yield ID"
  exit 1
fi

echo "$RESPONSE" | jq '.'

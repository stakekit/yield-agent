#!/bin/bash

# Yield.xyz Balance Checker
# Usage: ./check-portfolio.sh <yield_id> <address>
# Example: ./check-portfolio.sh base-usdc-aave-v3-lending 0x742d35Cc6634C0532925a3b844Bc454e4438f44e
#
# Returns balances for a specific yield position including:
# - Balance type (active, claimable, withdrawable, etc.)
# - Amount in human-readable and raw formats
# - USD value
# - Pending actions (claim rewards, withdraw, etc.)
# - Validator info (for staking yields)
#
# To scan ALL positions across a network, use the aggregate endpoint: POST /v1/yields/balances

# Auto-detect config path: local (extracted ZIP) or installed (OpenClaw/ClawHub/Clawdbot)
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

# Load config (supports env var overrides)
API_KEY="${YIELDS_API_KEY:-$(jq -r '.api.apiKey' "${CONFIG_DIR}/skill.json")}"
API_URL="${YIELDS_API_URL:-$(jq -r '.api.baseUrl' "${CONFIG_DIR}/skill.json")}"

YIELD_ID=$1
ADDRESS=$2

# Validation
if [ -z "$YIELD_ID" ] || [ -z "$ADDRESS" ]; then
  echo "Error: Both yield_id and address are required"
  echo "Usage: ./check-portfolio.sh <yield_id> <address>"
  echo "Example: ./check-portfolio.sh base-usdc-aave-v3-lending 0x742d35Cc6634C0532925a3b844Bc454e4438f44e"
  echo ""
  echo "To find your yield IDs, first run: ./find-yields.sh <network>"
  echo "To scan ALL positions, use: POST /v1/yields/balances (aggregate endpoint)"
  exit 1
fi

# Build payload
PAYLOAD=$(jq -n --arg addr "$ADDRESS" '{address: $addr}')

# Call API
# Returns: YieldBalancesDto { yieldId, balances: BalanceDto[] }
# Each BalanceDto has: address, type, amount, amountRaw, amountUsd, token, pendingActions, validator, isEarning
# Each PendingActionDto has: intent, type, passthrough, arguments?
# Use type + passthrough with manage-position.sh
# See references/openapi.yaml for full DTO schemas
RESPONSE=$(curl -s -X POST "${API_URL}/v1/yields/${YIELD_ID}/balances" \
  -H "x-api-key: ${API_KEY}" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD")

# Better error handling
if echo "$RESPONSE" | jq -e '.error // .message' > /dev/null 2>&1; then
  ERROR_MSG=$(echo "$RESPONSE" | jq -r '.message // .error // "Unknown error"')
  echo "Error from Yield.xyz API: $ERROR_MSG"
  echo ""
  echo "Common causes:"
  echo "  - Invalid yield ID (use find-yields.sh to discover valid IDs)"
  echo "  - Invalid address format"
  exit 1
fi

echo "$RESPONSE" | jq '.'

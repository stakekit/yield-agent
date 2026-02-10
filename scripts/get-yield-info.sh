#!/bin/bash

# Yield.xyz Yield Information & Schema Discovery
# Fetches full yield metadata including required arguments, entry limits,
# mechanics, validators, and token details
#
# Usage: ./get-yield-info.sh <yield_id>
# Example: ./get-yield-info.sh base-usdc-aave-v3-lending
# Example: ./get-yield-info.sh ethereum-eth-lido-staking
#
# Shows:
#   - Token details (symbol, decimals, address)
#   - APY and reward rates
#   - Entry/exit mechanics and required arguments schema
#   - Minimum/maximum deposit limits
#   - Whether validator selection is required
#   - Available actions (enter, exit, manage)

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

API_KEY="${YIELDS_API_KEY:-$(jq -r '.api.apiKey' "${CONFIG_DIR}/skill.json")}"
API_URL="${YIELDS_API_URL:-$(jq -r '.api.baseUrl' "${CONFIG_DIR}/skill.json")}"

YIELD_ID=$1

if [ -z "$YIELD_ID" ]; then
  echo "Yield Information & Schema Discovery"
  echo ""
  echo "Usage: ./get-yield-info.sh <yield_id>"
  echo ""
  echo "Examples:"
  echo "  ./get-yield-info.sh base-usdc-aave-v3-lending"
  echo "  ./get-yield-info.sh ethereum-eth-lido-staking"
  echo ""
  echo "Shows full yield metadata including required arguments,"
  echo "entry limits, and whether validators are needed."
  exit 1
fi

RESPONSE=$(curl -s -w "\n%{http_code}" -X GET \
  "${API_URL}/v1/yields/${YIELD_ID}" \
  -H "x-api-key: ${API_KEY}" \
  -H "Content-Type: application/json")

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" != "200" ]; then
  ERROR=$(echo "$BODY" | jq -r '.message // .error // "Unknown error"' 2>/dev/null)
  echo "Error ($HTTP_CODE): $ERROR"
  echo ""
  echo "Common causes:"
  echo "  - Invalid yield ID (use find-yields.sh to discover valid IDs)"
  echo "  - API key issue (check skill.json or YIELDS_API_KEY env var)"
  exit 1
fi

echo "=== Yield Info: $YIELD_ID ==="
echo ""

echo "--- Basic Details ---"
echo "$BODY" | jq -r '"Protocol:    \(.metadata.name // .metadata.protocol // "Unknown")
Type:        \(.type // "Unknown")
Network:     \(.network // "Unknown")
Status:      \(.status // "Unknown")
APY:         \(.apy // "N/A")"'

echo ""
echo "--- Token ---"
echo "$BODY" | jq -r '"Symbol:      \(.token.symbol // "Unknown")
Decimals:    \(.token.decimals // "N/A")
Address:     \(.token.address // "N/A")
Network:     \(.token.network // "N/A")"'

REWARD_TOKEN=$(echo "$BODY" | jq -r '.rewardTokens[0].symbol // empty' 2>/dev/null)
if [ ! -z "$REWARD_TOKEN" ]; then
  echo ""
  echo "--- Reward Token ---"
  echo "$BODY" | jq -r '.rewardTokens[0] | "Symbol:      \(.symbol // "Unknown")\nDecimals:    \(.decimals // "N/A")\nAddress:     \(.address // "N/A")"'
fi

echo ""
echo "--- Entry Mechanics ---"

REQUIRES_VALIDATOR=$(echo "$BODY" | jq -r '.mechanics.requiresValidatorSelection // false' 2>/dev/null)
echo "Validators:  $REQUIRES_VALIDATOR"
if [ "$REQUIRES_VALIDATOR" = "true" ]; then
  echo "             Run: ./list-validators.sh $YIELD_ID"
fi

ENTER_ARGS=$(echo "$BODY" | jq '.args.enter // .mechanics.arguments.enter // empty' 2>/dev/null)
if [ ! -z "$ENTER_ARGS" ] && [ "$ENTER_ARGS" != "null" ]; then
  echo ""
  echo "Required arguments for entering this yield:"

  PARSED_OK=false
  if echo "$ENTER_ARGS" | jq -e '.args' > /dev/null 2>&1; then
    echo "$ENTER_ARGS" | jq -r '.args | to_entries[] | "  \(.key): \(.value.type // "string") (required: \(.value.required // true))\n    min: \(.value.minimum // "none"), max: \(.value.maximum // "none")"' 2>/dev/null
    PARSED_OK=true
  fi

  if [ "$PARSED_OK" = false ]; then
    echo "  (Non-standard schema format. Raw schema below:)"
    echo "$ENTER_ARGS" | jq '.' 2>/dev/null || echo "$ENTER_ARGS"
  fi

  MIN_AMOUNT=$(echo "$ENTER_ARGS" | jq -r '.args.amount.minimum // "none"' 2>/dev/null)
  MAX_AMOUNT=$(echo "$ENTER_ARGS" | jq -r '.args.amount.maximum // "none"' 2>/dev/null)
  TOKEN_DECIMALS=$(echo "$BODY" | jq -r '.token.decimals // 0')

  if [ "$MIN_AMOUNT" != "none" ] && [ "$MIN_AMOUNT" != "null" ]; then
    echo ""
    echo "  Minimum deposit: $MIN_AMOUNT"
  fi
  if [ "$MAX_AMOUNT" != "none" ] && [ "$MAX_AMOUNT" != "null" ]; then
    echo "  Maximum deposit: $MAX_AMOUNT"
  fi
else
  echo "Arguments:   amount (human-readable string) - standard schema"
fi

EXIT_ARGS=$(echo "$BODY" | jq '.args.exit // .mechanics.arguments.exit // empty' 2>/dev/null)
if [ ! -z "$EXIT_ARGS" ] && [ "$EXIT_ARGS" != "null" ]; then
  echo ""
  echo "--- Exit Mechanics ---"
  if echo "$EXIT_ARGS" | jq -e '.args' > /dev/null 2>&1; then
    echo "$EXIT_ARGS" | jq -r '.args | to_entries[] | "  \(.key): \(.value.type // "string") (required: \(.value.required // true))"' 2>/dev/null
  else
    echo "  (Non-standard schema format. Raw schema below:)"
    echo "$EXIT_ARGS" | jq '.' 2>/dev/null || echo "$EXIT_ARGS"
  fi
fi

MANAGE_ACTIONS=$(echo "$BODY" | jq '.args.manage // .mechanics.arguments.manage // empty' 2>/dev/null)
if [ ! -z "$MANAGE_ACTIONS" ] && [ "$MANAGE_ACTIONS" != "null" ]; then
  echo ""
  echo "--- Manage Actions ---"
  echo "Available actions for this yield:"
  echo "$MANAGE_ACTIONS" | jq -r 'if type == "object" then to_entries[] | "  \(.key)" else . end' 2>/dev/null
fi

echo ""
echo "--- Quick Commands ---"
echo "  Enter:       ./enter-position.sh $YIELD_ID <address> '{\"amount\":\"100\"}'"
if [ "$REQUIRES_VALIDATOR" = "true" ]; then
  echo "  Validators:  ./list-validators.sh $YIELD_ID"
fi
echo "  Check pos:   ./check-portfolio.sh $YIELD_ID <address>"

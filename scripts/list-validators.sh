#!/bin/bash

# Yield.xyz Validator Discovery
# Fetches available validators for staking yields that require validator selection
#
# Usage: ./list-validators.sh <yield_id> [limit]
# Example: ./list-validators.sh ethereum-eth-lido-staking
# Example: ./list-validators.sh cosmos-atom-cosmoshub-staking 50
#
# When to use:
#   If a yield has requiresValidatorSelection: true in its mechanics,
#   you must pick a validator before building the transaction.
#   Run this script to discover validators, then include the address
#   in the arguments_json for enter-position.sh.
#
# Output: validator name, address, APY, commission, status

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

API_KEY="${YIELDS_API_KEY:-$(jq -r '.apiKey' "${CONFIG_DIR}/config.json")}"
API_URL="${YIELDS_API_URL:-$(jq -r '.apiUrl' "${CONFIG_DIR}/config.json")}"

YIELD_ID=$1
LIMIT=${2:-20}

if [ -z "$YIELD_ID" ]; then
  echo "Validator Discovery for Yield.xyz Staking"
  echo ""
  echo "Usage: ./list-validators.sh <yield_id> [limit]"
  echo ""
  echo "Examples:"
  echo "  ./list-validators.sh ethereum-eth-lido-staking"
  echo "  ./list-validators.sh cosmos-atom-cosmoshub-staking 50"
  echo ""
  echo "Then include the validator address in enter-position.sh arguments:"
  echo "  ./enter-position.sh <yield_id> <address> '{\"amount\":\"100\",\"validatorAddress\":\"...\"}'"
  exit 1
fi

RESPONSE=$(curl -s -w "\n%{http_code}" -X GET \
  "${API_URL}/v1/yields/${YIELD_ID}/validators?limit=${LIMIT}" \
  -H "x-api-key: ${API_KEY}" \
  -H "Content-Type: application/json")

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" != "200" ]; then
  ERROR=$(echo "$BODY" | jq -r '.message // .error // "Unknown error"' 2>/dev/null)
  echo "Error ($HTTP_CODE): $ERROR"
  echo ""
  echo "Common causes:"
  echo "  - This yield may not require validator selection"
  echo "  - Invalid yield ID (use find-yields.sh to discover valid IDs)"
  echo "  - API key issue (check config.json or YIELDS_API_KEY env var)"
  echo ""
  echo "Tip: Run ./get-yield-info.sh $YIELD_ID to check if this yield needs validators"
  exit 1
fi

VALIDATOR_COUNT=$(echo "$BODY" | jq '.items | length' 2>/dev/null)

if [ "$VALIDATOR_COUNT" = "0" ] || [ "$VALIDATOR_COUNT" = "null" ] || [ -z "$VALIDATOR_COUNT" ]; then
  echo "No validators found for $YIELD_ID"
  echo ""
  echo "This yield may not require validator selection."
  echo "Try entering without a validator:"
  echo "  ./enter-position.sh $YIELD_ID <address> '{\"amount\":\"100\"}'"
  exit 0
fi

echo "=== Validators for $YIELD_ID ==="
echo "Found: $VALIDATOR_COUNT validators (limit: $LIMIT)"
echo ""

echo "$BODY" | jq -r '.items[] | "Name:       \(.name // "Unnamed")\nAddress:    \(.address // "N/A")\nAPY:        \(.rewardRate.total // .apy // "N/A")\nCommission: \(.commission // "N/A")\nStatus:     \(.status // "active")\nStaked:     \(.stakedBalance // "N/A")\n---"'

echo ""
echo "Usage: ./enter-position.sh $YIELD_ID <address> '{\"amount\":\"100\",\"validatorAddress\":\"<address_from_above>\"}'"

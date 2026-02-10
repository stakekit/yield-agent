#!/bin/bash

# Yield.xyz Discovery Script
# Usage: ./find-yields.sh <network> [token] [limit] [offset] [--summary]
# Example: ./find-yields.sh base USDC
# Example: ./find-yields.sh ethereum
# Example: ./find-yields.sh base USDC 50 0
# Example: ./find-yields.sh base USDC --summary

# Auto-detect config path: local (extracted ZIP) or installed (OpenClaw/ClawHub/Clawdbot)
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

# Load config (supports env var overrides)
API_KEY="${YIELDS_API_KEY:-$(jq -r '.apiKey' "${CONFIG_DIR}/config.json")}"
API_URL="${YIELDS_API_URL:-$(jq -r '.apiUrl' "${CONFIG_DIR}/config.json")}"

# Check for --summary flag in any position
SUMMARY=false
ARGS=()
for arg in "$@"; do
  if [ "$arg" = "--summary" ]; then
    SUMMARY=true
  else
    ARGS+=("$arg")
  fi
done

# Parse arguments (excluding --summary)
NETWORK="${ARGS[0]:-${YIELD_NETWORK:-$(jq -r '.defaultNetwork // "base"' "${CONFIG_DIR}/config.json")}}"
TOKEN=${ARGS[1]:-}
LIMIT=${ARGS[2]:-20}
OFFSET=${ARGS[3]:-0}

if [ -z "$NETWORK" ]; then
  echo "Error: Network required"
  echo "Usage: ./find-yields.sh <network> [token] [limit] [offset] [--summary]"
  echo "Example: ./find-yields.sh base USDC"
  echo "Example: ./find-yields.sh base USDC --summary"
  echo "Networks: ethereum, base, arbitrum, optimism, polygon, solana, avalanche-c, and 80+ more"
  echo ""
  echo "Flags:"
  echo "  --summary  Show condensed table with ID, APY, decimals, and min deposit"
  exit 1
fi

# Build query string
QUERY="network=${NETWORK}&limit=${LIMIT}&offset=${OFFSET}"
if [ ! -z "$TOKEN" ]; then
  QUERY="${QUERY}&token=${TOKEN}"
fi

# Call API
# Returns: { items: YieldDto[], total: number }
RESPONSE=$(curl -s -X GET "${API_URL}/v1/yields?${QUERY}" \
  -H "x-api-key: ${API_KEY}" \
  -H "Content-Type: application/json")

# Better error handling
if echo "$RESPONSE" | jq -e '.error // .message' > /dev/null 2>&1; then
  ERROR_MSG=$(echo "$RESPONSE" | jq -r '.message // .error // "Unknown error"')
  echo "Error from Yield.xyz API: $ERROR_MSG"
  echo ""
  echo "Common causes:"
  echo "  - Invalid network name (use: ethereum, base, arbitrum, polygon, etc.)"
  echo "  - API key issue (check config.json or YIELDS_API_KEY env var)"
  exit 1
fi

if [ "$SUMMARY" = true ]; then
  TOTAL=$(echo "$RESPONSE" | jq -r '.total // 0')
  COUNT=$(echo "$RESPONSE" | jq '.items | length')
  echo "Yields on $NETWORK${TOKEN:+ for $TOKEN} (showing $COUNT of $TOTAL)"
  echo ""
  printf "%-55s | %-8s | %-8s | %-4s | %s\n" "ID" "Type" "APY" "Dec" "Min Deposit"
  printf "%-55s-+-%-8s-+-%-8s-+-%-4s-+-%s\n" "-------------------------------------------------------" "--------" "--------" "----" "------------"

  echo "$RESPONSE" | jq -r '.items[] |
    [
      .id,
      (.type // "?"),
      (if .apy then (.apy * 100 | tostring | split(".") | .[0] + "." + (.[1] // "00" | .[:2]) + "%") else "N/A" end),
      (.token.decimals // "?" | tostring),
      (.args.enter.args.amount.minimum // "none")
    ] | @tsv' | while IFS=$'\t' read -r ID TYPE APY DECIMALS MIN; do
    printf "%-55s | %-8s | %8s | %4s | %s\n" "$ID" "$TYPE" "$APY" "$DECIMALS" "$MIN"
  done
else
  echo "$RESPONSE" | jq '.'
fi

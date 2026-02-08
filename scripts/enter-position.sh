#!/bin/bash

# Yield.xyz Transaction Builder (Enter Position)
# Usage: ./enter-position.sh <yield_id> <address> <amount> [validator_address] [--dry-run]
# Example: ./enter-position.sh base-usdc-aave-v3-lending 0x742d... 100000000
# Example: ./enter-position.sh ethereum-eth-lido-staking 0x742d... 1000000000000000000 0xValidator
# Example: ./enter-position.sh base-usdc-aave-v3-lending 0x742d... 100000000 --dry-run

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

# Check for --dry-run flag in any position
DRY_RUN=false
VALIDATOR=""
for arg in "$@"; do
  if [ "$arg" = "--dry-run" ]; then
    DRY_RUN=true
  fi
done

# Validator is $4 unless it's --dry-run
if [ ! -z "$4" ] && [ "$4" != "--dry-run" ]; then
  VALIDATOR=$4
fi

# Validation
if [ -z "$YIELD_ID" ] || [ -z "$ADDRESS" ] || [ -z "$AMOUNT" ]; then
  echo "Error: Missing required arguments"
  echo "Usage: ./enter-position.sh <yield_id> <address> <amount> [validator_address] [--dry-run]"
  echo "Example: ./enter-position.sh base-usdc-aave-v3-lending 0x742d... 100000000"
  echo ""
  echo "Note: Amount must be a raw integer string (e.g., '100000000' for 100 USDC)"
  echo "      Formula: raw_amount = human_amount * 10^decimals (USDC=6, ETH=18)"
  echo "Optional: validator_address for staking yields that require validator selection"
  echo "Optional: --dry-run to validate without building the transaction"
  exit 1
fi

# Safety Check: Validate Amount Format (must be raw integer string)
if ! [[ "$AMOUNT" =~ ^[0-9]+$ ]]; then
  echo "Error: Amount must be a raw integer string (e.g., '100000000' not '100' or '1.5')"
  echo "Formula: raw_amount = human_amount * 10^decimals"
  echo "  100 USDC (6 decimals) = 100000000"
  echo "  1 ETH (18 decimals)   = 1000000000000000000"
  exit 1
fi

# Dry-run: validate inputs and check yield metadata
if [ "$DRY_RUN" = true ]; then
  echo "=== DRY RUN (no transaction will be built) ==="
  echo ""
  echo "Yield ID: $YIELD_ID"
  echo "Address:  $ADDRESS"
  echo "Amount:   $AMOUNT (raw)"
  if [ ! -z "$VALIDATOR" ]; then
    echo "Validator: $VALIDATOR"
  fi
  echo ""

  # Fetch yield metadata to validate
  echo "Fetching yield metadata..."
  YIELD_META=$(curl -s -X GET "${API_URL}/yields/${YIELD_ID}" \
    -H "x-api-key: ${API_KEY}" \
    -H "Content-Type: application/json")

  if echo "$YIELD_META" | jq -e '.error // .message' > /dev/null 2>&1; then
    ERROR=$(echo "$YIELD_META" | jq -r '.message // .error // "Unknown error"')
    echo "Error: Yield not found - $ERROR"
    exit 1
  fi

  TOKEN_SYMBOL=$(echo "$YIELD_META" | jq -r '.token.symbol // "UNKNOWN"')
  TOKEN_DECIMALS=$(echo "$YIELD_META" | jq -r '.token.decimals // "N/A"')
  APY=$(echo "$YIELD_META" | jq -r '.apy // "N/A"')
  PROTOCOL=$(echo "$YIELD_META" | jq -r '.metadata.name // .metadata.protocol // "Unknown"')
  TYPE=$(echo "$YIELD_META" | jq -r '.type // "Unknown"')
  NETWORK=$(echo "$YIELD_META" | jq -r '.network // "Unknown"')

  # Check minimum deposit
  MIN_AMOUNT=$(echo "$YIELD_META" | jq -r '.args.enter.args.amount.minimum // "0"' 2>/dev/null)
  if [ "$MIN_AMOUNT" = "null" ] || [ -z "$MIN_AMOUNT" ]; then
    MIN_AMOUNT="0"
  fi

  echo ""
  echo "Yield Details:"
  echo "  Protocol: $PROTOCOL"
  echo "  Type:     $TYPE"
  echo "  Network:  $NETWORK"
  echo "  Token:    $TOKEN_SYMBOL ($TOKEN_DECIMALS decimals)"
  echo "  APY:      $APY"
  echo ""

  # Convert amounts for display if possible
  if command -v python3 &> /dev/null && [ "$TOKEN_DECIMALS" != "N/A" ]; then
    HUMAN_AMOUNT=$(python3 -c "print(f'{int(\"$AMOUNT\") / (10 ** $TOKEN_DECIMALS):.6f}')" 2>/dev/null)
    echo "  Deposit: $HUMAN_AMOUNT $TOKEN_SYMBOL ($AMOUNT raw)"
    if [ "$MIN_AMOUNT" != "0" ]; then
      HUMAN_MIN=$(python3 -c "print(f'{int(\"$MIN_AMOUNT\") / (10 ** $TOKEN_DECIMALS):.6f}')" 2>/dev/null)
      echo "  Minimum: $HUMAN_MIN $TOKEN_SYMBOL ($MIN_AMOUNT raw)"
      if python3 -c "exit(0 if int('$AMOUNT') >= int('$MIN_AMOUNT') else 1)" 2>/dev/null; then
        echo "  Status:  PASS - amount meets minimum"
      else
        echo "  Status:  FAIL - amount is below minimum deposit!"
        echo ""
        echo "Increase your amount to at least $MIN_AMOUNT raw ($HUMAN_MIN $TOKEN_SYMBOL)"
        exit 1
      fi
    else
      echo "  Minimum: No minimum specified"
    fi
  else
    echo "  Deposit: $AMOUNT raw"
    if [ "$MIN_AMOUNT" != "0" ]; then
      echo "  Minimum: $MIN_AMOUNT raw"
      if [ "$AMOUNT" -lt "$MIN_AMOUNT" ] 2>/dev/null; then
        echo "  Status:  FAIL - amount is below minimum deposit!"
        exit 1
      fi
    fi
  fi

  echo ""
  echo "=== Validation passed. Remove --dry-run to build the transaction. ==="
  exit 0
fi

# Pre-validation: Check minimum deposit amount (non-dry-run)
YIELD_META=$(curl -s -X GET "${API_URL}/yields/${YIELD_ID}" \
  -H "x-api-key: ${API_KEY}" \
  -H "Content-Type: application/json" 2>/dev/null)

if echo "$YIELD_META" | jq -e '.args.enter.args.amount.minimum' > /dev/null 2>&1; then
  MIN_AMOUNT=$(echo "$YIELD_META" | jq -r '.args.enter.args.amount.minimum')
  if [ ! -z "$MIN_AMOUNT" ] && [ "$MIN_AMOUNT" != "null" ] && [ "$MIN_AMOUNT" != "0" ]; then
    if command -v python3 &> /dev/null; then
      BELOW_MIN=$(python3 -c "print('yes' if int('$AMOUNT') < int('$MIN_AMOUNT') else 'no')" 2>/dev/null)
    else
      BELOW_MIN=$([ "$AMOUNT" -lt "$MIN_AMOUNT" ] 2>/dev/null && echo "yes" || echo "no")
    fi
    if [ "$BELOW_MIN" = "yes" ]; then
      TOKEN_SYMBOL=$(echo "$YIELD_META" | jq -r '.token.symbol // "tokens"')
      TOKEN_DECIMALS=$(echo "$YIELD_META" | jq -r '.token.decimals // 0')
      if command -v python3 &> /dev/null; then
        HUMAN_MIN=$(python3 -c "print(f'{int(\"$MIN_AMOUNT\") / (10 ** $TOKEN_DECIMALS):.6f}')" 2>/dev/null)
        HUMAN_AMT=$(python3 -c "print(f'{int(\"$AMOUNT\") / (10 ** $TOKEN_DECIMALS):.6f}')" 2>/dev/null)
        echo "Error: Amount below minimum deposit"
        echo "  Minimum: $HUMAN_MIN $TOKEN_SYMBOL ($MIN_AMOUNT raw)"
        echo "  You tried: $HUMAN_AMT $TOKEN_SYMBOL ($AMOUNT raw)"
      else
        echo "Error: Amount $AMOUNT is below minimum deposit of $MIN_AMOUNT"
      fi
      echo ""
      echo "Use --dry-run to validate before building: ./enter-position.sh $YIELD_ID $ADDRESS $AMOUNT --dry-run"
      exit 1
    fi
  fi
fi

# Build payload with optional validator
if [ ! -z "$VALIDATOR" ]; then
  PAYLOAD=$(jq -n \
    --arg yieldId "$YIELD_ID" \
    --arg address "$ADDRESS" \
    --arg amount "$AMOUNT" \
    --arg validator "$VALIDATOR" \
    '{yieldId: $yieldId, address: $address, arguments: {amount: $amount, validatorAddress: $validator}}')
else
  PAYLOAD=$(jq -n \
    --arg yieldId "$YIELD_ID" \
    --arg address "$ADDRESS" \
    --arg amount "$AMOUNT" \
    '{yieldId: $yieldId, address: $address, arguments: {amount: $amount}}')
fi

# Call API
# Returns: Action { id, intent, type, yieldId, address, amount, amountRaw, amountUsd, status, executionPattern, transactions: Transaction[], createdAt, completedAt }
# Each Transaction: { id, title, network, status, type, hash, unsignedTransaction (JSON string), stepIndex, gasEstimate (JSON string), createdAt, broadcastedAt, signedTransaction }
# IMPORTANT: unsignedTransaction is a JSON STRING, not an object! Parse it: jq -r '.unsignedTransaction' | jq '.'
RESPONSE=$(curl -s -X POST "${API_URL}/actions/enter" \
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
  echo "  - Amount too low (check minimum deposit with --dry-run)"
  echo "  - Invalid yield ID (use find-yields.sh to discover valid IDs)"
  echo "  - Invalid address format (must be 0x... for EVM chains)"
  echo "  - API key issue (check config.json or YIELDS_API_KEY env var)"
  exit 1
fi

echo "$RESPONSE" | jq '.'

---
name: yield-agent
displayName: YieldAgent
description: AI-powered on-chain yield discovery, transaction building, and portfolio management across 80+ networks
version: 1.0.0
author: yield-xyz
metadata:
  clawhub:
    icon: "yield"
    homepage: "https://yield.xyz"
    requires:
      bins: ["curl", "jq"]
    tools:
      - name: find-yields
        description: Discover yield opportunities by network and token
        entry: scripts/find-yields.sh
        args:
          - name: network
            description: The blockchain network (e.g., base, ethereum, arbitrum, solana)
            required: true
          - name: token
            description: The token symbol (e.g., USDC, ETH). Optional - omit to see all yields on network.
            required: false
          - name: limit
            description: Items per page (default 20, max 100)
            required: false
          - name: offset
            description: Pagination offset (default 0)
            required: false
      - name: enter-position
        description: Enter a yield position. Fetch the yield first (GET /v1/yields/{yieldId}) to discover required arguments from mechanics.arguments.enter
        entry: scripts/enter-position.sh
        args:
          - name: yieldId
            description: The unique yield identifier (e.g., base-usdc-aave-v3-lending)
            required: true
          - name: address
            description: The user wallet address
            required: true
          - name: arguments_json
            description: JSON string of arguments from the yield's mechanics.arguments.enter schema. Always includes "amount". Other fields (validatorAddress, inputToken, etc.) depend on the yield.
            required: true
      - name: exit-position
        description: Exit a yield position. Fetch the yield first (GET /v1/yields/{yieldId}) to discover required arguments from mechanics.arguments.exit
        entry: scripts/exit-position.sh
        args:
          - name: yieldId
            description: The unique yield identifier to exit from
            required: true
          - name: address
            description: The user wallet address
            required: true
          - name: arguments_json
            description: JSON string of arguments from the yield's mechanics.arguments.exit schema. Always includes "amount". Other fields depend on the yield.
            required: true
      - name: manage-position
        description: Manage a yield position (claim, restake, redelegate, etc.). Discover available actions from pendingActions[] in the balances response.
        entry: scripts/manage-position.sh
        args:
          - name: yieldId
            description: The unique yield identifier
            required: true
          - name: address
            description: The user wallet address
            required: true
          - name: action
            description: The action type from pendingActions[].type in the balances response
            required: true
          - name: passthrough
            description: The passthrough string from pendingActions[].passthrough in the balances response
            required: true
          - name: arguments_json
            description: JSON string of arguments from pendingActions[].arguments schema, if the action requires additional input
            required: false
      - name: check-portfolio
        description: Check yield balances for a specific yield position
        entry: scripts/check-portfolio.sh
        args:
          - name: yieldId
            description: The unique yield identifier to check balances for (e.g., base-usdc-aave-v3-lending)
            required: true
          - name: address
            description: The user wallet address to check balances for
            required: true
      - name: get-yield-info
        description: Fetch full yield metadata including required arguments schema, entry limits, validator requirements, and token details
        entry: scripts/get-yield-info.sh
        args:
          - name: yieldId
            description: The unique yield identifier to inspect (e.g., base-usdc-aave-v3-lending)
            required: true
      - name: list-validators
        description: List available validators for staking yields that require validator selection
        entry: scripts/list-validators.sh
        args:
          - name: yieldId
            description: The unique yield identifier to list validators for
            required: true
          - name: limit
            description: Maximum validators to return (default 20)
            required: false
---

# YieldAgent by Yield.xyz

Access the complete on-chain yield landscape through Yield.xyz's unified API. Discover 2600+ yields across staking, lending, vaults, restaking, and liquidity pools. Build transactions and manage positions across 80+ networks.

> **For exact types, schemas, enums, and request/response shapes, consult `references/openapi.yaml`.** It is the source of truth for the API. This SKILL.md describes how to use the tools and flows — the OpenAPI spec defines the precise contract.

## Key Rules

> **The API is self-documenting.** Every yield describes its own requirements through the `YieldDto`. Before taking any action, always fetch the yield and inspect it. The `mechanics` field tells you everything: what arguments are needed (`mechanics.arguments.enter`, `.exit`), entry limits (`mechanics.entryLimits`), and what tokens are accepted (`inputTokens[]`). Never assume — always check the yield first.

1. **Always fetch the yield before calling an action.** Call `GET /v1/yields/{yieldId}` and read `mechanics.arguments.enter` (or `.exit`) to discover the exact fields required. Each yield is different — the schema is the contract. Do not guess or hardcode arguments.

   Each field in the schema (`ArgumentFieldDto`) tells you:
   - `name`: the field name (e.g., `amount`, `validatorAddress`, `inputToken`)
   - `type`: the value type (`string`, `number`, `address`, `enum`, `boolean`)
   - `required`: whether it must be provided
   - `options`: static choices for enum fields (e.g., `["individual", "batched"]`)
   - `optionsRef`: a dynamic API endpoint to fetch choices (e.g., `/api/v1/validators?integrationId=...`) — if present, call it to get the valid options (validators, providers, etc.)
   - `minimum` / `maximum`: value constraints
   - `isArray`: whether the field expects an array

   If a field has `optionsRef`, you must call that endpoint to get the valid values. This is how validators, providers, and other dynamic options are discovered.

2. **For manage actions, always fetch balances first.** Call `POST /v1/yields/{yieldId}/balances` and read `pendingActions[]` on each balance. Each pending action tells you its `type`, `passthrough`, and optional `arguments` schema. Only call manage with values from this response.

3. **Amounts are human-readable.** `"100"` means 100 USDC. `"1"` means 1 ETH. `"0.5"` means 0.5 SOL. Do NOT convert to wei or raw integers — the API handles decimals internally.

4. **Set `inputToken` to what the user wants to deposit** — but only if `inputToken` appears in the yield's `mechanics.arguments.enter` schema. The API handles the full flow (swaps, wrapping, routing) to get the user into the position.

5. **Always submit the transaction hash after broadcasting.** For every transaction: sign, broadcast, then submit the hash via `PUT /v1/transactions/{txId}/submit-hash`. Balances will not appear on the balances endpoint until the hash is submitted.

6. **Execute transactions in exact order.** If an action has multiple transactions, they are ordered by `stepIndex`. Wait for `CONFIRMED` before proceeding to the next. Never skip or reorder.

7. **Consult `references/openapi.yaml` for types.** All enums, DTOs, and schemas are defined there. Do not hardcode values.

> **CRITICAL: `unsignedTransaction` format varies by chain!**
> The `unsignedTransaction` field is typed `string | object | null`. Its encoding depends on the chain family:
> - **EVM chains** (Ethereum, Base, Arbitrum, etc.): JSON string — must be parsed with `JSON.parse()` / `jq -r`
> - **Cosmos chains**: Hex-encoded SignDoc bytes (string)
> - **Solana**: Hex-encoded (legacy) or Base64-encoded (versioned) serialized transaction
> - **Substrate** (Polkadot, Kusama): JSON object (not a string — no parsing needed)
> - **Other chains**: See "Unsigned Transaction Formats by Chain" section below
>
> ```bash
> # EVM chains — parse the JSON string first
> echo "$TX" | jq -r '.unsignedTransaction' | jq '.to'
>
> # Substrate chains — it's already an object, access directly
> echo "$TX" | jq '.unsignedTransaction.tx.method'
>
> # Solana/Cosmos/Near — it's an opaque encoded string, pass directly to signing SDK
> echo "$TX" | jq -r '.unsignedTransaction'
> ```

## I Just Want to Deposit USDC (10-Line Quick Start)

```bash
cd yield-agent && chmod +x scripts/*.sh

# 1. Find the best yields
./scripts/find-yields.sh base USDC

# 2. Enter a position (amounts are human-readable — "100" means 100 USDC)
./scripts/enter-position.sh base-usdc-aave-v3-lending 0xYOUR_WALLET '{"amount":"100"}'

# 3. The response contains unsigned transaction(s) to pass to your wallet skill for signing
```

## Amounts

Amounts are **human-readable strings**. Use the amount as the user would say it:

- `"1"` for 1 ETH
- `"100"` for 100 USDC
- `"0.5"` for 0.5 SOL

Do not convert to wei, raw integers, or smallest units. The API handles decimal conversion internally.

## Setup

#### Option A: OpenClaw (Recommended)
Tell your OpenClaw agent:
```
install the yield-agent skill from https://github.com/yield-xyz/openclaw-skills
```

#### Option B: ClawHub / Manual
1. Get API key from [dashboard.yield.xyz](https://dashboard.yield.xyz)
2. Configure (scripts auto-detect `~/.openclaw/`, `~/.clawhub/`, or `~/.clawdbot/`):

```bash
mkdir -p ~/.clawhub/skills/yield-agent
cp -r yield-agent/* ~/.clawhub/skills/yield-agent/
# A free API key is already included in config.json
# For your own key later, visit dashboard.yield.xyz
```

## Capabilities

### Read Operations (NO GAS)

- `find-yields.sh`: Query the yield metadata database. No on-chain interaction.
- `check-portfolio.sh`: Read on-chain balances for a specific yield via API. No transaction needed.
- `get-yield-info.sh`: Fetch full yield metadata including required arguments, entry limits, and validator requirements.
- `list-validators.sh`: List available validators for staking yields with APY and commission.

### Write Operations (REQUIRES GAS)

- `enter-position.sh` (Enter): Generates unsigned transactions for entering yield positions.
- `exit-position.sh` (Exit): Generates unsigned transactions for exiting yield positions.
- `manage-position.sh` (Manage): Generates unsigned transactions for claiming, restaking, redelegating, etc. Requires passthrough from balances.

> All write operations produce unsigned transactions. Signing is always handled by a separate wallet skill.

## Core Capabilities

### 1. Discover Yields

Find yield opportunities across networks.

**Examples:**
- "Find USDC yields on Base"
- "What's the best ETH staking rate?"
- "Show me safe stablecoin yields"
- "Compare Morpho vs Aave on Ethereum"

**API Call:**
```bash
curl -X GET "$API_URL/yields?network=base&token=USDC&limit=20&offset=0" \
  -H "x-api-key: $API_KEY"
```

**All query parameters (from OpenAPI spec):**

| Parameter | Type | Description |
|-----------|------|-------------|
| network | string | Filter by single network (e.g., `base`, `ethereum`) |
| networks | string | Filter by multiple networks (comma separated) |
| chainId | string | Filter by EVM chain ID (e.g., `1`=Ethereum, `137`=Polygon) |
| token | string | Filter by token symbol or address |
| inputToken | string | Filter by input token symbol or address |
| inputTokens | string | Filter by multiple input tokens (comma separated) |
| type | string | Filter by yield type: `staking`, `restaking`, `lending`, `vault`, `fixed_yield`, `real_world_asset`, `concentrated_liquidity_pool`, `liquidity_pool` |
| types | string[] | Filter by multiple yield types |
| provider | string | Filter by provider ID (e.g., `morpho`, `aave`, `lido`) |
| providers | string[] | Filter by multiple provider IDs |
| yieldId | string | Filter by specific yield ID |
| yieldIds | string[] | Filter by multiple yield IDs (max 100) |
| search | string | Search by yield name |
| hasCooldownPeriod | boolean | Filter yields with/without cooldown periods |
| hasWarmupPeriod | boolean | Filter yields with/without warmup periods |
| sort | string | Sort: `statusEnterAsc`, `statusEnterDesc`, `statusExitAsc`, `statusExitDesc` |
| limit | number | Items per page (default 20, max 100) |
| offset | number | Pagination offset (default 0) |

**Response format:**
```json
{
  "items": [
    {
      "id": "base-usdc-aave-v3-lending",
      "network": "base",
      "chainId": "8453",
      "token": { "symbol": "USDC", "name": "USD Coin", "decimals": 6, "network": "base", "address": "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913", "logoURI": "https://assets.stakek.it/tokens/usdc.svg", "isPoints": false },
      "inputTokens": [{ "symbol": "USDC", "name": "USD Coin", "decimals": 6, "network": "base", "address": "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913", "isPoints": false }],
      "tokens": [{ "symbol": "USDC", "name": "USD Coin", "decimals": 6, "network": "base" }],
      "outputToken": { "symbol": "aBaseUSDC", "name": "Aave Base USDC", "decimals": 6, "network": "base" },
      "providerId": "aave",
      "rewardRate": {
        "total": 0.042,
        "rateType": "APR",
        "components": [
          { "rate": 0.042, "rateType": "APR", "token": { "symbol": "USDC" }, "yieldSource": "lending", "description": "Lending interest" }
        ]
      },
      "status": { "enter": true, "exit": true },
      "metadata": {
        "name": "Aave V3 USDC Lending",
        "logoURI": "https://...",
        "description": "Earn yield by lending USDC on Aave V3",
        "underMaintenance": false,
        "deprecated": false
      },
      "mechanics": {
        "type": "lending",
        "requiresValidatorSelection": false,
        "rewardClaiming": "automatic",
        "entryLimits": { "minimum": "1000000", "maximum": null }
      },
      "tags": ["stablecoin", "lending"],
      "statistics": { "tvlUsd": "15000000", "tvl": "15000000", "tvlRaw": "15000000000000", "uniqueUsers": 1200, "averagePositionSizeUsd": "12500", "averagePositionSize": "12500.000000" }
    }
  ],
  "total": 56,
  "offset": 0,
  "limit": 20
}
```

### 2. Enter Positions

Construct unsigned transactions for entering yield positions.

**Examples:**
- "Stake 1 ETH with Lido"
- "Deposit 100 USDC into Aave on Base"
- "Enter this yield: base-usdc-aave-v3-lending"

**API Call:**
```bash
curl -X POST "$API_URL/actions/enter" \
  -H "x-api-key: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "yieldId": "base-usdc-aave-v3-lending",
    "address": "0xUserWallet",
    "arguments": {
      "amount": "100",
      "inputToken": "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913"
    }
  }'
```

**Discover required arguments from the yield itself:**

Each yield declares its required arguments under `mechanics.arguments.enter`, `.exit`, and `.manage`. Fetch the yield details first:

```bash
# Get the yield schema — shows required arguments, entry limits, validator requirements
./scripts/get-yield-info.sh base-usdc-aave-v3-lending
# Look at: mechanics.arguments.enter.fields[], mechanics.requiresValidatorSelection, mechanics.entryLimits
# Look at: inputTokens[] to see which tokens the yield accepts
```

The schema defines field names, types, whether required, default values, and dynamic references (e.g., `optionsRef` for validator lists). Always read the yield details before calling an action.

**`inputToken`**: If the yield's `mechanics.arguments.enter` schema includes an `inputToken` field, set it to the token address the user wants to deposit. The API handles all intermediate steps (swaps, wrapping, bridging) to get the user into the position. If the field is not in the schema, the yield only accepts its canonical token — check `inputTokens[]` on the yield to see what's accepted.

See `references/openapi.yaml` → `ActionArgumentsDto` for the full type definition.

**Response (ActionDto):**
```json
{
  "id": "a2090424-4b43-4767-a61e-d7bbb395ab38",
  "intent": "enter",
  "type": "STAKE",
  "yieldId": "base-usdc-aave-v3-lending",
  "address": "0xUserWallet",
  "amount": "100",
  "amountRaw": "100000000",
  "amountUsd": "100.00",
  "status": "CREATED",
  "executionPattern": "synchronous",
  "transactions": [
    {
      "id": "bf69c86f-bc3a-42a0-8a51-24230943ae9e",
      "title": "Approve USDC",
      "description": "Approve USDC for staking",
      "network": "base",
      "status": "CREATED",
      "type": "APPROVAL",
      "hash": null,
      "createdAt": "2025-01-15T10:30:00Z",
      "broadcastedAt": null,
      "signedTransaction": null,
      "unsignedTransaction": "{\"from\":\"0xUserWallet\",\"to\":\"0xUSDCContract\",\"data\":\"0x095ea7b3...\",\"value\":\"0\",\"gasLimit\":\"50000\",\"nonce\":0,\"chainId\":8453,\"maxFeePerGas\":\"107500073\",\"maxPriorityFeePerGas\":\"109421\",\"type\":2}",
      "stepIndex": 0,
      "gasEstimate": "{\"amount\":\"0.000032250021900000\",\"gasLimit\":\"50000\",\"token\":{\"network\":\"base\",\"name\":\"Ethereum\",\"symbol\":\"ETH\",\"decimals\":18}}",
      "isMessage": false,
      "explorerUrl": null,
      "annotatedTransaction": null,
      "structuredTransaction": null
    },
    {
      "id": "c3180424-5b54-4878-b72f-e8ccc406bc49",
      "title": "STAKE Transaction",
      "description": "Deposit USDC into Aave V3",
      "network": "base",
      "status": "WAITING_FOR_SIGNATURE",
      "type": "STAKE",
      "hash": null,
      "createdAt": "2025-01-15T10:30:00Z",
      "broadcastedAt": null,
      "signedTransaction": null,
      "unsignedTransaction": "{\"from\":\"0xUserWallet\",\"to\":\"0xAavePool\",\"data\":\"0xd0e30db0...\",\"value\":\"0\",\"gasLimit\":\"200000\",\"nonce\":1,\"chainId\":8453,\"maxFeePerGas\":\"107500073\",\"maxPriorityFeePerGas\":\"109421\",\"type\":2}",
      "stepIndex": 1,
      "gasEstimate": "{\"amount\":\"0.000129000087600000\",\"gasLimit\":\"200000\",\"token\":{\"network\":\"base\",\"name\":\"Ethereum\",\"symbol\":\"ETH\",\"decimals\":18}}",
      "isMessage": false,
      "explorerUrl": null,
      "annotatedTransaction": null,
      "structuredTransaction": null
    }
  ],
  "rawArguments": { "amount": "100" },
  "createdAt": "2025-01-15T10:30:00Z",
  "completedAt": null
}
```


### 3. Exit Positions

Generate transactions to withdraw from yield positions.

**Examples:**
- "Exit my Aave position"
- "Unstake 0.5 ETH from Lido"
- "Withdraw all from base-usdc-aave-v3-lending"

**API Call:**
```bash
curl -X POST "$API_URL/actions/exit" \
  -H "x-api-key: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "yieldId": "base-usdc-aave-v3-lending",
    "address": "0xUserWallet",
    "arguments": { "amount": "50" }
  }'
```

### 4. Manage Positions

Claim rewards, restake, or perform other management actions.

**Examples:**
- "Claim my Lido rewards"
- "Restake rewards automatically"
- "Show pending actions"

**API Call:**
```bash
curl -X POST "$API_URL/actions/manage" \
  -H "x-api-key: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "yieldId": "ethereum-eth-lido-staking",
    "address": "0xUserWallet",
    "action": "CLAIM_REWARDS",
    "passthrough": "passthroughStringFromBalances",
    "arguments": {}
  }'
```

**Workflow:**
1. Check your position: `./scripts/check-portfolio.sh <yield_id> <address>`
2. Look for `pendingActions[]` in the output — each has `{ type, passthrough, arguments? }`
3. Use the `type` and `passthrough` from the pending action: `./scripts/manage-position.sh <yield_id> <address> CLAIM_REWARDS "eyJhbGci..."`
4. If the pending action has an `arguments` schema, pass matching JSON as the 5th arg
5. The response contains unsigned transactions to sign

### 4b. Yield Info & Validator Discovery

Before entering any yield, fetch its metadata to discover required arguments, entry limits, and whether validators are needed.

**Check yield requirements:**
```bash
./scripts/get-yield-info.sh ethereum-eth-lido-staking
# Shows: required args, entry limits, validator requirements, token details
```

**List validators (for staking yields):**
```bash
./scripts/list-validators.sh cosmos-atom-cosmoshub-staking
# Shows: name, address, APY, commission, status
```

Then use the validator address when building the transaction:
```bash
./scripts/enter-position.sh cosmos-atom-cosmoshub-staking 0xWallet '{"amount":"1000","validatorAddress":"cosmosvaloper1..."}'
```

### 5. Check Balances

View balances for a specific yield position.

**Examples:**
- "Check my Aave balance"
- "What's my balance in Lido?"
- "Show pending actions for my staking position"

**API Call:**
```bash
curl -X POST "$API_URL/yields/base-usdc-aave-v3-lending/balances" \
  -H "x-api-key: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"address": "0xUserWallet"}'
```

## Compatible With

| Platform | Status | Notes |
|----------|--------|-------|
| OpenClaw | Native | Full support with Bankr wallet for signing |
| ClawHub | Native | Primary distribution via clawhub.ai |
| Claude Code | Compatible | Install via `npx skills add yield-agent` |
| Cursor / Codex / Copilot | Compatible | Install via `npx skills add yield-agent` |
| Any agent framework | Compatible | Point agent at SKILL.md |

## Integration with Wallet Skills

After building transactions, hand off to any wallet skill for signing. The action response contains `transactions[]` — pass each transaction's `unsignedTransaction` to your wallet for signing and broadcasting. After broadcast, submit the transaction hash via `PUT /v1/transactions/{txId}/submit-hash` so the API can track status.

### Bankr Integration (OpenClaw Native)

If using Bankr as your wallet, submit unsigned transactions directly via Bankr's API:

```bash
# 1. Build unsigned transaction with yield-agent
ACTION=$(./scripts/enter-position.sh base-usdc-aave-v3-lending 0xBankrWallet '{"amount":"100"}')

# 2. Extract the unsigned transaction from the ActionDto response
UNSIGNED_TX=$(echo "$ACTION" | jq -r '.transactions[0].unsignedTransaction')

# 3. Submit to Bankr for signing and broadcasting
curl -X POST "https://api.bankr.bot/agent/submit" \
  -H "Authorization: Bearer $BANKR_API_KEY" \
  -H "Content-Type: application/json" \
  -d "{\"transaction\": $UNSIGNED_TX}"
```

### User Flow (12 Steps)

1. User: "Lend 100 USDC on Aave Base"
2. Yield skill discovers yields: `./scripts/find-yields.sh base USDC`
3. User selects: "base-usdc-aave-v3-lending"
4. Yield skill enters position: `./scripts/enter-position.sh base-usdc-aave-v3-lending 0xWallet '{"amount":"100"}'`
5. Yield skill returns Action with unsigned transaction(s)
6. AI agent detects transactions need signing
7. AI loads appropriate wallet skill (Bankr, Privy, circle-wallet, etc.)
8. For each transaction in sequence: pass `unsignedTransaction` to wallet (format varies by chain)
9. Wallet skill signs and broadcasts the transaction
10. Submit the tx hash: `PUT /v1/transactions/{txId}/submit-hash` with `{ "hash": "0x..." }`
11. Poll `GET /v1/transactions/{txId}` until status is CONFIRMED or FAILED
12. User can view status on block explorer via `explorerUrl`

### Supported Wallet Solutions

This skill produces unsigned transactions compatible with any wallet. Recommended options with integration support levels:

| Wallet | Tier | Integration | Signs Arbitrary Tx | Agent Framework | How It Connects |
|--------|------|-------------|-------------------|-----------------|-----------------|
| **Bankr** | Platform | Native | Yes | Yes | Zero config on OpenClaw. Submit endpoint accepts unsigned tx directly from yield-agent output. |
| **Privy** | Enterprise | Skill | Yes | Yes | `clawhub install privy-agentic-wallets`. Configure PRIVY_APP_ID + PRIVY_APP_SECRET. Policy engine enforces spending limits, chain restrictions, contract allowlists. |
| **Coinbase AgentKit** | Enterprise | SDK | Yes | Yes | SDK provides wallet send/sign methods for parsed unsigned tx. Smart Wallets support tx batching. Gasless on Base. |
| **Crossmint** | Enterprise | SDK | Yes | Yes | GOAT SDK provides DeFi protocol plugins. Custodial wallet API supports tx signing. On-chain spending limits. |
| **eth-agent** | Enterprise | SDK | Yes | No | Lightweight TypeScript SDK wrapping ethers.js. Configurable spending limits per-transaction and daily. 2 deps. |
| **circle-wallet** | Verified | Skill | Yes | No | ClawHub skill install. Circle Developer-Controlled Wallets handle signing via MPC. Gas Station pays gas in USDC. |
| **Agent Wallet** | Community | Skill | Yes | No | ClawHub skill install. Supports EVM transaction signing via skill interface. Suitable for dev/testing. |
| **Molt Wallet** | Caution | Manual | No | No | Solana-only CLI. No programmatic signing API. Not compatible with EVM yield transactions. |

**Integration Level Key:**
- **Native** = Zero-config, works out of the box (OpenClaw only)
- **SDK** = Import their library, call their signing function with the unsigned tx
- **Skill** = Install as a ClawHub skill, passes unsigned tx via skill interface
- **Manual** = Requires manual steps, no programmatic signing API

### Privy Agentic Wallets Setup (Recommended for Production)

Privy provides server wallets with policy-based guardrails, ideal for securing yield transactions. The OpenClaw integration is experimental and not officially supported by Privy.

**Installation:**
```bash
clawhub install privy-agentic-wallets
# Or clone: git clone https://github.com/privy-io/privy-agentic-wallets-skill.git ~/.openclaw/workspace/skills/privy
```

**Configure credentials** in `~/.openclaw/openclaw.json`:
```json
{
  "env": {
    "vars": {
      "PRIVY_APP_ID": "your-app-id",
      "PRIVY_APP_SECRET": "your-app-secret"
    }
  }
}
```

Get credentials from [dashboard.privy.io](https://dashboard.privy.io). Then restart: `openclaw gateway restart`

**Policy examples for yield transactions:**

Spending limit (max 0.1 ETH per tx):
```json
{
  "name": "Max 0.1 ETH per tx",
  "method": "eth_sendTransaction",
  "conditions": [
    { "field_source": "ethereum_transaction", "field": "value", "operator": "lte", "value": "100000000000000000" }
  ],
  "action": "ALLOW"
}
```

Chain restriction (Base mainnet only - good for yield farming on Base):
```json
{
  "name": "Base mainnet only",
  "method": "eth_sendTransaction",
  "conditions": [
    { "field_source": "ethereum_transaction", "field": "chain_id", "operator": "eq", "value": "8453" }
  ],
  "action": "ALLOW"
}
```

Contract allowlist (restrict to specific yield protocol contracts):
```json
{
  "name": "Only approved yield contracts",
  "method": "eth_sendTransaction",
  "conditions": [
    { "field_source": "ethereum_transaction", "field": "to", "operator": "in", "value": ["0xYieldContractAddress1", "0xYieldContractAddress2"] }
  ],
  "action": "ALLOW"
}
```

**Workflow:** Create wallet -> Create policy -> Attach policy to wallet -> Execute yield transactions within policy constraints.

**Supported chains:** Ethereum, Base, Polygon, Arbitrum, Optimism, Solana. Also supports Cosmos, Stellar, Sui, Aptos, Tron, Bitcoin, NEAR, TON, Starknet.

**Security:** Your PRIVY_APP_SECRET grants full access to create wallets and sign transactions. Never commit to version control. Credentials stored in plaintext in openclaw.json - ensure machine is secure. Start with testnet (Base Sepolia, chain ID 84532) before mainnet. Only fund wallets with amounts you can afford to lose.

**If compromised:** Rotate App Secret at dashboard.privy.io -> Rotate authorization keys -> Review wallet activity -> Transfer remaining funds -> Audit setup.

See full docs: [docs.privy.io/recipes/agent-integrations/openclaw-agentic-wallets](https://docs.privy.io/recipes/agent-integrations/openclaw-agentic-wallets)

### What Gets Passed to Wallet Skill

Each transaction in the action response has:
- `unsignedTransaction`: the data to sign (format varies by chain — see "Unsigned Transaction Formats by Chain")
- `network`: which chain it's for
- `stepIndex`: execution order
- `id`: the transaction ID (needed for `PUT /v1/transactions/{id}/submit-hash` after broadcasting)

The wallet skill is responsible for signing, gas management, nonce handling, and broadcasting.

## Unsigned Transaction Formats by Chain

The `unsignedTransaction` field in the API response is encoded differently for each blockchain family. This section documents the **exact format** returned by the API, derived from the `libs/chains` source code.

### EVM Chains (Ethereum, Base, Arbitrum, Optimism, Polygon, Avalanche, BSC, Linea, zkSync, Sonic, etc.)

**Encoding:** JSON string (serialized via `JSON.stringify(tx, bigIntReplacer)`)
**Must parse:** Yes — `JSON.parse(unsignedTransaction)`

```json
{
  "from": "0xUserWallet",
  "to": "0xContractAddress",
  "data": "0xEncodedCallData...",
  "value": "0",
  "gasLimit": "200000",
  "nonce": 42,
  "chainId": 8453,
  "maxFeePerGas": "107500073",
  "maxPriorityFeePerGas": "109421",
  "type": 2
}
```

| Field | Type | Description |
|-------|------|-------------|
| from | string | Sender address |
| to | string | Contract/recipient address |
| data | string | Hex-encoded calldata |
| value | string | Amount in wei (usually "0" for token operations) |
| gasLimit | string | Gas limit (add 30% safety margin before signing) |
| nonce | number | Transaction nonce |
| chainId | number | Network chain ID (e.g., 1=Ethereum, 8453=Base, 42161=Arbitrum) |
| maxFeePerGas | string | EIP-1559 max fee per gas (type 2 only) |
| maxPriorityFeePerGas | string | EIP-1559 priority fee (type 2 only) |
| gasPrice | string | Legacy gas price (type 0 only) |
| type | number | 0=legacy, 2=EIP-1559 |

**Note:** BigInt values are serialized as strings by the `bigIntReplacer` utility.

### Cosmos Chains (Cosmos Hub, Osmosis, Celestia, dYdX, Injective, Sei, etc.)

**Encoding:** Hex-encoded SignDoc bytes (string)
**Must parse:** No — pass hex string directly to Cosmos signing SDK

```
"0a92010a8f010a2f2f636f736d6f732e7374616b696e672e763162657461312e4d736744656c6567617465125c0a2d..."
```

The hex string encodes a Protobuf `SignDoc` containing:
- `bodyBytes`: Encoded `TxBody` (messages, memo, timeout)
- `authInfoBytes`: Encoded `AuthInfo` (signer, fee, gas)
- `chainId`: Chain identifier (e.g., "cosmoshub-4")
- `accountNumber`: Account number on chain

**Chain-specific argument:** `cosmosPubKey` is required in action arguments for Cosmos staking.

### Solana

**Encoding:** Hex-encoded bytes (legacy) or Base64-encoded bytes (versioned transactions)
**Must parse:** No — decode hex/base64 and pass to Solana signing SDK

```
"01000103ab4f6f7b4e3c8f2d1a..."
```

Legacy transactions are hex-encoded serialized `Transaction` objects. Versioned transactions (v0) are Base64-encoded wire format. The signing SDK (`@solana/web3.js`) handles both.

### Substrate (Polkadot, Kusama, Westend)

**Encoding:** JSON object (NOT a string — already parsed)
**Must parse:** No — it's already a JSON object in the response

```json
{
  "tx": {
    "address": "5GrwvaEF5zXb26Fz9rcQpDWS57CtERHpNehXCPcNoHGKutQY",
    "blockHash": "0x...",
    "blockNumber": 12345678,
    "eraPeriod": 64,
    "genesisHash": "0x91b171bb158e2d3848fa23a9f1c25182fb8e20313b2c1eb49219da7a70ce90c3",
    "method": "0x0700...",
    "nonce": 5,
    "specVersion": 1002000,
    "tip": 0,
    "transactionVersion": 26
  },
  "specName": "polkadot",
  "specVersion": 1002000,
  "metadataRpc": "0x..."
}
```

**Note:** Substrate transactions include chain metadata (`metadataRpc`) needed for offline signing with `@substrate/txwrapper-polkadot`.

### Tezos

**Encoding:** Hex-encoded forged operation bytes (string)
**Must parse:** No — pass hex string to Tezos signing SDK

```
"6c00fbe8..."
```

For Ledger Wallet API compatibility (when `ledgerWalletApiCompatible: true` in arguments), the format changes to a JSON string:

```json
{
  "family": "tezos",
  "mode": "delegate",
  "amount": "1000000",
  "recipient": "tz1...",
  "fees": "1420",
  "gasLimit": "10600"
}
```

**Chain-specific argument:** `tezosPubKey` is required in action arguments for Tezos staking.

### TON

**Encoding:** JSON string (serialized message object)
**Must parse:** Yes — `JSON.parse(unsignedTransaction)`

```json
{
  "to": "EQ...",
  "value": "1000000000",
  "body": "te6cckEBAQEADgAAGEhfZccAAAAAAAAAAIA6ig=="
}
```

For Ledger Wallet API compatibility, the format changes to:

```json
{
  "family": "ton",
  "amount": "1000000000",
  "recipient": "EQ...",
  "fees": "10000000",
  "comment": { "text": "d:pool_address", "isEncrypted": false }
}
```

### Near

**Encoding:** Hex-encoded serialized `Transaction` bytes (string)
**Must parse:** No — decode hex and pass to Near signing SDK (`near-api-js`)

```
"09000000736f6d652e6e656172..."
```

The hex string encodes a serialized `Transaction` containing:
- `signerId`: Sender account ID
- `publicKey`: Sender's public key
- `nonce`: Transaction nonce
- `receiverId`: Recipient account ID
- `actions`: Array of actions (stake, transfer, etc.)
- `blockHash`: Recent block hash

### Sui

**Encoding:** Base64-encoded JSON (string)
**Must parse:** No — decode base64, then pass to Sui signing SDK (`@mysten/sui`)

```
"eyJ0eXBlIjoiY2FsbCIsInRhcmdldCI6IjB4Li4uIiwiYXJncyI6Wy4uLl19..."
```

Built using the `Transaction` class from `@mysten/sui/transactions`, serialized via `tx.toJSON()` then Base64-encoded.

### Aptos

**Encoding:** Base64-encoded BCS (Binary Canonical Serialization) bytes (string)
**Must parse:** No — decode base64, then pass to Aptos signing SDK (`@aptos-labs/ts-sdk`)

```
"AAAAAAAAAAAAAAABAgAAAAAAAAAAAAAAAAAAAAAAAAAAAAABBHN0YWtl..."
```

The Base64 string encodes a `RawTransaction` containing:
- `sender`: Sender address
- `sequenceNumber`: Account sequence number
- `payload`: Transaction payload (entry function call)
- `maxGasAmount`: Maximum gas units
- `gasUnitPrice`: Gas unit price in APT
- `expirationTimestampSecs`: Transaction expiration
- `chainId`: Network chain ID

### Cardano

**Encoding:** CBOR hex string (string)
**Must parse:** No — pass hex to Cardano signing SDK (`@meshsdk/core`)

```
"84a50081825820abc123...ff"
```

Built using `MeshTxBuilder` from `@meshsdk/core`. The CBOR-encoded transaction contains inputs, outputs, fees, and certificates for staking operations.

### Stellar

**Encoding:** XDR string (string)
**Must parse:** No — pass XDR to Stellar signing SDK (`@stellar/stellar-sdk`)

```
"AAAAAgAAAABk..."
```

Built using `TransactionBuilder` from `@stellar/stellar-sdk`. The XDR string is produced by `transaction.toXDR()`.

### Tron

**Encoding:** JSON string (same as EVM format)
**Must parse:** Yes — `JSON.parse(unsignedTransaction)`

Tron is EVM-compatible, so the format follows the EVM structure. Uses `ethers.ContractTransaction` serialized as a JSON string.

**Chain-specific argument:** `tronResource` (`BANDWIDTH` or `ENERGY`) is required for Tron staking.

### Quick Reference Table

| Chain Family | Encoding | Type in Response | Parse Before Signing? | Signing SDK |
|-------------|----------|------------------|-----------------------|-------------|
| EVM | JSON string | `string` | Yes (`JSON.parse`) | ethers.js / viem |
| Cosmos | Hex bytes | `string` | No (hex decode) | @cosmjs/stargate |
| Solana | Hex/Base64 bytes | `string` | No (hex/base64 decode) | @solana/web3.js |
| Substrate | JSON object | `object` | No (already parsed) | @substrate/txwrapper |
| Tezos | Hex bytes / JSON | `string` | Depends on mode | @taquito/taquito |
| TON | JSON string | `string` | Yes (`JSON.parse`) | @ton/ton |
| Near | Hex bytes | `string` | No (hex decode) | near-api-js |
| Sui | Base64 JSON | `string` | No (base64 decode) | @mysten/sui |
| Aptos | Base64 BCS | `string` | No (base64 decode) | @aptos-labs/ts-sdk |
| Cardano | CBOR hex | `string` | No (hex decode) | @meshsdk/core |
| Stellar | XDR | `string` | No (XDR decode) | @stellar/stellar-sdk |
| Tron | JSON string | `string` | Yes (`JSON.parse`) | ethers.js / TronWeb |

### Transaction Submission Flow

After signing and broadcasting each transaction, submit the **transaction hash** to the API for tracking:

```bash
curl -X PUT "$API_URL/transactions/{transactionId}/submit-hash" \
  -H "x-api-key: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"hash": "0xTransactionHash..."}'
```

Then poll for confirmation:
```bash
curl -X GET "$API_URL/transactions/{transactionId}" \
  -H "x-api-key: $API_KEY"
```

Poll until status reaches `CONFIRMED` (success) or `FAILED` (error). Full status enum is in `references/openapi.yaml` → `TransactionStatus`.


## When to Use Wallet Skills

After constructing transactions via `enter-position.sh`, the AI should:

1. Present the transaction details to the user
2. Ask for confirmation
3. If user confirms, say: "I'll prepare this transaction for your wallet to sign."
4. The AI will automatically detect that a wallet skill is needed
5. User's configured wallet skill will handle signing (Bankr, Privy, circle-wallet, etc.)

**Do NOT attempt to sign transactions yourself.**
The Yield.xyz skill only builds unsigned transactions.
Wallet skills like Bankr, Privy, or circle-wallet handle all signing.

## Response Formats

### YieldDto Response

```json
{
  "items": [
    {
      "id": "base-usdc-aave-v3-lending",
      "network": "base",
      "chainId": "8453",
      "token": { "symbol": "USDC", "name": "USD Coin", "decimals": 6, "network": "base", "address": "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913", "logoURI": "https://assets.stakek.it/tokens/usdc.svg", "isPoints": false },
      "inputTokens": [{ "symbol": "USDC", "name": "USD Coin", "decimals": 6, "network": "base", "address": "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913", "isPoints": false }],
      "tokens": [{ "symbol": "USDC", "name": "USD Coin", "decimals": 6, "network": "base" }],
      "outputToken": { "symbol": "aBaseUSDC", "name": "Aave Base USDC", "decimals": 6, "network": "base" },
      "providerId": "aave",
      "rewardRate": {
        "total": 0.042,
        "rateType": "APR",
        "components": [
          { "rate": 0.042, "rateType": "APR", "token": { "symbol": "USDC" }, "yieldSource": "lending", "description": "Lending interest" }
        ]
      },
      "metadata": {
        "name": "Aave V3 USDC Lending",
        "logoURI": "https://...",
        "description": "Earn yield by lending USDC on Aave V3",
        "underMaintenance": false,
        "deprecated": false
      },
      "mechanics": {
        "type": "lending",
        "requiresValidatorSelection": false,
        "rewardSchedule": "block",
        "rewardClaiming": "automatic",
        "entryLimits": { "minimum": "1000000", "maximum": null }
      },
      "status": { "enter": true, "exit": true },
      "tags": ["stablecoin", "lending"],
      "statistics": { "tvlUsd": "15000000", "tvl": "15000000", "tvlRaw": "15000000000000", "uniqueUsers": 1200, "averagePositionSizeUsd": "12500", "averagePositionSize": "12500.000000" }
    }
  ],
  "total": 56,
  "offset": 0,
  "limit": 20
}
```

### ActionDto Response (Enter/Exit/Manage)

```json
{
  "id": "a2090424-4b43-4767-a61e-d7bbb395ab38",
  "intent": "enter",
  "type": "STAKE",
  "yieldId": "base-usdc-aave-v3-lending",
  "address": "0xUserWallet",
  "amount": "100",
  "amountRaw": "100000000",
  "amountUsd": "100.00",
  "status": "CREATED",
  "executionPattern": "synchronous",
  "transactions": [
    {
      "id": "bf69c86f-bc3a-42a0-8a51-24230943ae9e",
      "title": "Approve USDC",
      "description": "Approve USDC for staking",
      "network": "base",
      "status": "CREATED",
      "type": "APPROVAL",
      "hash": null,
      "createdAt": "2025-01-15T10:30:00Z",
      "broadcastedAt": null,
      "signedTransaction": null,
      "unsignedTransaction": "{\"from\":\"0xUserWallet\",\"to\":\"0xUSDCContract\",\"data\":\"0x095ea7b3...\",\"value\":\"0\",\"gasLimit\":\"50000\",\"nonce\":0,\"chainId\":8453,\"maxFeePerGas\":\"107500073\",\"maxPriorityFeePerGas\":\"109421\",\"type\":2}",
      "stepIndex": 0,
      "gasEstimate": "{\"amount\":\"0.000032250021900000\",\"gasLimit\":\"50000\",\"token\":{\"network\":\"base\",\"name\":\"Ethereum\",\"symbol\":\"ETH\",\"decimals\":18}}",
      "isMessage": false,
      "explorerUrl": null,
      "annotatedTransaction": null,
      "structuredTransaction": null
    },
    {
      "id": "c3180424-5b54-4878-b72f-e8ccc406bc49",
      "title": "STAKE Transaction",
      "description": "Deposit USDC into Aave V3",
      "network": "base",
      "status": "WAITING_FOR_SIGNATURE",
      "type": "STAKE",
      "hash": null,
      "createdAt": "2025-01-15T10:30:00Z",
      "broadcastedAt": null,
      "signedTransaction": null,
      "unsignedTransaction": "{\"from\":\"0xUserWallet\",\"to\":\"0xAavePool\",\"data\":\"0xd0e30db0...\",\"value\":\"0\",\"gasLimit\":\"200000\",\"nonce\":1,\"chainId\":8453,\"maxFeePerGas\":\"107500073\",\"maxPriorityFeePerGas\":\"109421\",\"type\":2}",
      "stepIndex": 1,
      "gasEstimate": "{\"amount\":\"0.000129000087600000\",\"gasLimit\":\"200000\",\"token\":{\"network\":\"base\",\"name\":\"Ethereum\",\"symbol\":\"ETH\",\"decimals\":18}}",
      "isMessage": false,
      "explorerUrl": null,
      "annotatedTransaction": null,
      "structuredTransaction": null
    }
  ],
  "rawArguments": { "amount": "100" },
  "createdAt": "2025-01-15T10:30:00Z",
  "completedAt": null
}
```

### TransactionDto Field Reference

| Field | Type | Description |
|-------|------|-------------|
| id | string | Unique transaction identifier (UUID) |
| title | string | Display title (e.g., "Approve USDC", "STAKE Transaction") |
| description | string? | User-friendly description of what this transaction does |
| network | string | Network enum value (ethereum, base, arbitrum, etc.) |
| status | TransactionStatus | Current status (see below) |
| type | TransactionType | Operation type (see below) |
| hash | string \| null | Transaction hash (available after broadcast) |
| createdAt | Date | When the transaction was created |
| broadcastedAt | Date \| null | When broadcasted to the network |
| signedTransaction | string \| null | Signed transaction data (after signing) |
| unsignedTransaction | string \| object \| null | Unsigned tx data — **format varies by chain** |
| stepIndex | number? | Zero-based index in the action flow |
| error | string? | Error message if the transaction failed |
| gasEstimate | string? | JSON string with gas cost estimate |
| isMessage | boolean? | Whether this is a message rather than a value transfer |
| explorerUrl | string? | Link to blockchain explorer for this transaction |
| annotatedTransaction | object? | Human-readable breakdown of the transaction |
| structuredTransaction | object? | Detailed transaction data for client-side validation |

All enum values (`TransactionType`, `TransactionStatus`, `ActionStatus`, `ActionTypes`, `ExecutionPattern`, `BalanceType`, etc.) are defined in the OpenAPI spec at `references/openapi.yaml`. Key notes:

- Transaction type for approvals is `APPROVAL` (not `APPROVE`)
- Execution pattern is usually `synchronous` — submit transactions one by one, wait for each to confirm before submitting the next
- Poll `GET /v1/transactions/{id}` until status reaches a terminal state (`CONFIRMED` or `FAILED`)

### YieldBalancesDto Response

```json
{
  "yieldId": "base-usdc-aave-v3-lending",
  "balances": [
    {
      "address": "0xUserWallet",
      "type": "active",
      "amount": "100.500000",
      "amountRaw": "100500000",
      "amountUsd": "100.50",
      "token": { "symbol": "USDC", "name": "USD Coin", "decimals": 6, "network": "base", "logoURI": "https://assets.stakek.it/tokens/usdc.svg", "coinGeckoId": "usd-coin", "isPoints": false },
      "pendingActions": [
        {
          "intent": "manage",
          "type": "CLAIM_REWARDS",
          "passthrough": "eyJhbGciOi...",
          "arguments": null,
          "amount": "0.5"
        }
      ],
      "validator": null,
      "isEarning": true
    }
  ]
}
```

Balance types are defined in `references/openapi.yaml` → `BalanceType`.

### Aggregate Balances (cross-yield scanning)

**POST** `/v1/yields/balances` — scan balances across multiple yields and networks in a single call.

```bash
curl -X POST "$API_URL/yields/balances" \
  -H "x-api-key: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "balanceRequests": [
      { "address": "0xUserWallet", "network": "base" },
      { "address": "0xUserWallet", "network": "ethereum", "yieldId": "ethereum-eth-lido-staking" }
    ]
  }'
```

### ValidatorDto Response

```json
{
  "items": [
    {
      "address": "cosmosvaloper1...",
      "preferred": true,
      "name": "Luganodes",
      "logoURI": "https://assets.stakek.it/validators/luganodes.png",
      "website": "https://luganodes.com/",
      "rewardRate": { "total": 0.1499, "rateType": "APR" },
      "commission": 0.10,
      "votingPower": 0.0000808767558989335,
      "status": "active",
      "providerId": "luganodes",
      "tvl": "23966.560861000000000000",
      "tvlRaw": "23966560861"
    }
  ],
  "total": 605,
  "limit": 100,
  "offset": 0
}
```

## Supported Networks

80+ networks. Discover them via `GET /v1/networks` — returns each network's `id`, `name`, `category` (evm/cosmos/substrate/misc), and `logoURI`.

## Best Practices

1. Always fetch the yield and read its schema before calling any action
2. Check balance before entering positions
3. Start with small amounts to test
4. Amounts are human-readable strings ("100" for 100 USDC, "1" for 1 ETH)
5. Execute transactions in exact `stepIndex` order — wait for CONFIRMED before proceeding to next
6. Signing and gas management are the wallet skill's responsibility, not this skill's

## Common Patterns

### Research -> Enter Flow
1. Discover yields: `find-yields.sh base USDC`
2. Inspect the yield: `get-yield-info.sh <yieldId>` — read `mechanics.arguments.enter`
3. Enter position: `enter-position.sh <yieldId> <address> '{"amount":"100"}'`
4. Wallet skill signs each transaction in `stepIndex` order
5. Submit signed transactions, poll for confirmation

### Portfolio Check
1. "Check my Aave balance" → `./check-portfolio.sh base-usdc-aave-v3-lending 0xWallet`
2. Review balances and pending actions
3. "Claim rewards" → use passthrough from pendingActions

### Full Position Lifecycle
1. Discover yields (find-yields.sh)
2. Enter position (enter-position.sh)
3. Check balances (check-portfolio.sh)
4. Claim rewards (manage-position.sh with passthrough)
5. Exit position (exit-position.sh)

## Error Handling

The API returns structured error responses with `message`, `error`, and `statusCode` fields. Read the `message` — it tells you exactly what went wrong. Error response shapes are documented in `references/openapi.yaml` under each endpoint's error responses (400, 401, 404, 429, 500).

When a 429 (rate limit) is returned, respect the `retry-after` and `x-ratelimit-reset` headers before retrying.

## Complete API Endpoint Reference

All endpoints from the OpenAPI spec (`references/openapi.yaml`):

### Discovery
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/v1/yields` | List yield opportunities (with filters) |
| GET | `/v1/yields/{yieldId}` | Get yield metadata |
| GET | `/v1/yields/{yieldId}/risk` | Get risk parameters for a yield |
| GET | `/v1/yields/{yieldId}/validators` | List validators for staking yields |
| GET | `/v1/networks` | List all supported networks (with `id`, `name`, `category`, `logoURI`) |
| GET | `/v1/providers` | List all providers (paginated) |
| GET | `/v1/providers/{providerId}` | Get provider details |

### Actions
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/v1/actions/enter` | Enter a yield position |
| POST | `/v1/actions/exit` | Exit a yield position |
| POST | `/v1/actions/manage` | Manage position (claim, restake, etc.) |
| GET | `/v1/actions` | List user actions (requires `address` query param) |
| GET | `/v1/actions/{actionId}` | Get specific action details |

### Transactions
| Method | Endpoint | Description |
|--------|----------|-------------|
| PUT | `/v1/transactions/{transactionId}/submit-hash` | Submit the tx hash after broadcasting |
| POST | `/v1/transactions/{transactionId}/submit` | Submit full signed transaction for API to broadcast |
| GET | `/v1/transactions/{transactionId}` | Get transaction status |

### Portfolio
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/v1/yields/{yieldId}/balances` | Get balances for a specific yield |
| POST | `/v1/yields/balances` | Aggregate balances across multiple yields/networks |

### Network Categories

Networks are categorized into families (from `NetworkDto.category`):
- **evm**: Ethereum, Base, Arbitrum, Optimism, Polygon, Avalanche-C, Binance, etc.
- **cosmos**: Cosmos, Osmosis, Celestia, dYdX, Injective, Sei, etc.
- **substrate**: Polkadot, Kusama, Westend
- **misc**: Solana, Aptos, Sui, Near, Tezos, TON, Tron, Cardano, Stellar, Bittensor

## Important Request Details

- **Amounts**: Human-readable strings ("100" for 100 USDC, "1" for 1 ETH). The API handles decimal conversion.
- **Addresses**: Must be valid checksummed addresses for EVM chains.
- **Base URL**: https://api.yield.xyz
- **Content-Type**: application/json for all POST/PUT requests.
- **Auth Header**: x-api-key (lowercase)
- **unsignedTransaction**: `string | object | null` — encoding varies by chain family (see "Unsigned Transaction Formats by Chain").

## Configuration Reference

| Field | Env Override | Required | Description |
|-------|-------------|----------|-------------|
| apiKey | YIELDS_API_KEY | Yes | Production API key from dashboard.yield.xyz |
| apiUrl | YIELDS_API_URL | No | Default: https://api.yield.xyz |
| defaultNetwork | YIELD_NETWORK | No | Default network filter (e.g., base) |
| slippage | YIELD_SLIPPAGE | No | Basis points (Default: 50 = 0.5%) |

## Troubleshooting

Read the API error `message` — it tells you exactly what went wrong. Common issues:

- **Empty yield list:** Check network spelling (`base` not `Base`). IDs are always lowercase.
- **Action fails:** Did you read `mechanics.arguments` first? Pass only the fields the schema requires.
- **Multi-transaction actions fail:** Execute transactions in exact `stepIndex` order. Wait for each to reach `CONFIRMED` before submitting the next.

## Constraints

1. **NO Private Keys:** Never ask for or handle user private keys.
2. **Wallet Handoff:** After building a TX, pass the JSON output to the Wallet Skill.
3. **Safety:** Always check user balance before building Enter transactions. See safety.md.
4. **Do NOT attempt to sign transactions yourself.** The Yield.xyz skill only builds unsigned transactions.
5. Wallet skills like Agent Wallet or circle-wallet handle all signing.
6. **Sequential Transactions:** Process multi-transaction actions in order, waiting for confirmation between each.

## Resources

- API Docs: https://docs.yield.xyz
- API Recipes: https://github.com/stakekit/api-recipes
- Get API Key: https://dashboard.yield.xyz
- Supported Yields: https://yield.xyz/opportunities

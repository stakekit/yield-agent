---
name: yield-agent
displayName: YieldAgent
description: On-chain yield discovery, transaction building, and portfolio management via the Yield.xyz API. Use when the user wants to find yields, stake, lend, deposit into vaults, check balances, claim rewards, exit positions, compare APYs, or manage any on-chain yield across 80+ networks.
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

7. **NEVER modify `unsignedTransaction`.** Sign exactly what the API returns. Do not alter gas, nonce, value, data, or any field. Modifying a transaction can result in loss of funds. If something looks wrong, throw an error — do not attempt to fix it.

8. **Consult `{baseDir}/references/openapi.yaml` for types.** All enums, DTOs, and schemas are defined there. Do not hardcode values.

## Quick Start

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

The API handles decimal conversion internally.

## Scripts

| Script | Purpose |
|--------|---------|
| `find-yields.sh` | Discover yields by network/token |
| `get-yield-info.sh` | Inspect yield schema, limits, token details |
| `list-validators.sh` | List validators for staking yields |
| `enter-position.sh` | Enter a yield position |
| `exit-position.sh` | Exit a yield position |
| `manage-position.sh` | Claim, restake, redelegate, etc. |
| `check-portfolio.sh` | Check balances and pending actions |

## Common Patterns

### Enter a Position
1. Discover yields: `find-yields.sh base USDC`
2. Inspect the yield: `get-yield-info.sh <yieldId>` — read `mechanics.arguments.enter`
3. Enter: `enter-position.sh <yieldId> <address> '{"amount":"100"}'`
4. Wallet signs each transaction in `stepIndex` order
5. Submit hash: `PUT /v1/transactions/{txId}/submit-hash`

### Manage a Position
1. Check balances: `check-portfolio.sh <yieldId> <address>`
2. Read `pendingActions[]` — each has `{ type, passthrough, arguments? }`
3. Manage: `manage-position.sh <yieldId> <address> <action> <passthrough>`

### Full Lifecycle
1. Discover → 2. Enter → 3. Check balances → 4. Claim rewards → 5. Exit

## Transaction Flow

After any action (enter/exit/manage), the response contains `transactions[]`. For each:

1. Pass `unsignedTransaction` to wallet skill for signing and broadcasting
2. Submit the hash: `PUT /v1/transactions/{txId}/submit-hash` with `{ "hash": "0x..." }`
3. Poll `GET /v1/transactions/{txId}` until `CONFIRMED` or `FAILED`
4. Proceed to next transaction

`unsignedTransaction` format varies by chain. See `{baseDir}/references/chain-formats.md` for details.

## API Endpoints

All endpoints documented in `{baseDir}/references/openapi.yaml`. Quick reference:

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/v1/yields` | List yields (with filters) |
| GET | `/v1/yields/{yieldId}` | Get yield metadata (schema, limits, tokens) |
| GET | `/v1/yields/{yieldId}/validators` | List validators |
| POST | `/v1/actions/enter` | Enter a position |
| POST | `/v1/actions/exit` | Exit a position |
| POST | `/v1/actions/manage` | Manage a position |
| POST | `/v1/yields/{yieldId}/balances` | Get balances for a yield |
| POST | `/v1/yields/balances` | Aggregate balances across yields/networks |
| PUT | `/v1/transactions/{txId}/submit-hash` | Submit tx hash after broadcasting |
| GET | `/v1/transactions/{txId}` | Get transaction status |
| GET | `/v1/networks` | List all supported networks |
| GET | `/v1/providers` | List all providers |

## References

Detailed reference files — read on demand when you need specifics.

- **API types and schemas:** `{baseDir}/references/openapi.yaml` — source of truth for all DTOs, enums, request/response shapes
- **Chain transaction formats:** `{baseDir}/references/chain-formats.md` — `unsignedTransaction` encoding per chain family (EVM, Cosmos, Solana, Substrate, etc.)
- **Wallet integration:** `{baseDir}/references/wallet-integration.md` — Bankr, Privy, Coinbase AgentKit, signing flow, wallet setup
- **Agent conversation examples:** `{baseDir}/references/examples.md` — 10 conversation patterns with real yield IDs
- **Safety checks:** `{baseDir}/references/safety.md` — pre-execution checks, constraints

## Error Handling

The API returns structured errors with `message`, `error`, and `statusCode`. Read the `message`. Error shapes are in `{baseDir}/references/openapi.yaml`. Respect `retry-after` on 429s.

## Constraints

1. **NO Private Keys.** Never ask for or handle user private keys.
2. **Wallet Handoff.** Pass unsigned transactions to the wallet skill. Never sign yourself.
3. **Always submit hash.** Balances won't update until you submit the tx hash.
4. **Sequential execution.** Process transactions in `stepIndex` order.
5. **Read the schema.** Always fetch the yield and read `mechanics.arguments` before calling any action.

## Add-on Modules

Modular instructions that extend core functionality. Read when relevant.

- `{baseDir}/HEARTBEAT.md` — Periodic position monitoring, rate alerts, reward claiming prompts
- `{baseDir}/references/superskill.md` — 40 advanced capabilities: rate monitoring, cross-chain comparison, portfolio diversification, rotation workflows, reward harvesting, scheduled checks

## Resources

- API Docs: https://docs.yield.xyz
- API Recipes: https://github.com/stakekit/api-recipes
- Get API Key: https://dashboard.yield.xyz

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


**Integration Level Key:**
- **Native** = Zero-config, works out of the box (OpenClaw only)
- **SDK** = Import their library, call their signing function with the unsigned tx
- **Skill** = Install as a ClawHub skill, passes unsigned tx via skill interface
- **Manual** = Requires manual steps, no programmatic signing API

### Privy Agentic Wallets Setup

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

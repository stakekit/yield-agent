## Integration with Wallet Skills

After building transactions, hand off to any wallet skill for signing. The action response contains `transactions[]` — pass each transaction's `unsignedTransaction` to your wallet unmodified for signing and broadcasting. After broadcast, submit the transaction hash via `PUT /v1/transactions/{txId}/submit-hash`.

### User Flow

1. User: "Deposit 100 USDC into Aave on Base"
2. Yield skill discovers yields: `find-yields.sh base USDC`
3. Yield skill fetches schema: `get-yield-info.sh base-usdc-aave-v3-lending`
4. Yield skill enters position: `enter-position.sh base-usdc-aave-v3-lending 0xWallet '{"amount":"100"}'`
5. Response contains unsigned transaction(s)
6. Agent loads wallet skill
7. For each transaction in `stepIndex` order: pass `unsignedTransaction` to wallet
8. Wallet signs and broadcasts
9. Submit hash: `PUT /v1/transactions/{txId}/submit-hash` with `{ "hash": "0x..." }`
10. Poll `GET /v1/transactions/{txId}` until `CONFIRMED` or `FAILED`

### What Gets Passed to Wallet Skill

Each transaction in the action response has:
- `unsignedTransaction`: the data to sign (format varies by chain — see chain-formats.md)
- `network`: which chain it's for
- `stepIndex`: execution order
- `id`: the transaction ID (needed for `PUT /v1/transactions/{id}/submit-hash`)

The wallet skill handles signing, gas, nonce, and broadcasting. Never modify `unsignedTransaction`.

### Supported Wallet Solutions

| Wallet | Integration | How It Connects |
|--------|-------------|-----------------|
| **Privy** | Skill | `clawhub install privy`. Server wallets with policy guardrails. Signs and broadcasts transactions. |
| **Bankr** | Native | Zero config on OpenClaw. Signs and broadcasts unsigned transactions. |
| **Coinbase AgentKit** | SDK | Signs and broadcasts. Smart Wallets support tx batching. Gasless on Base. |
| **Crossmint** | SDK | Signs and broadcasts via custodial wallet API. |

### Privy Agentic Wallets Setup

Privy provides server wallets with policy-based guardrails for securing yield transactions.

Full docs: [docs.privy.io/recipes/agent-integrations/openclaw-agentic-wallets](https://docs.privy.io/recipes/agent-integrations/openclaw-agentic-wallets)

**Install from ClawHub:**
```bash
clawhub install privy
```

**Or clone from GitHub:**
```bash
git clone https://github.com/privy-io/privy-agentic-wallets-skill.git ~/.openclaw/workspace/skills/privy
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

**Policy examples:**

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

Chain restriction (Base mainnet only):
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

Contract allowlist:
```json
{
  "name": "Only approved contracts",
  "method": "eth_sendTransaction",
  "conditions": [
    { "field_source": "ethereum_transaction", "field": "to", "operator": "in", "value": ["0xContractAddress1", "0xContractAddress2"] }
  ],
  "action": "ALLOW"
}
```

**Workflow:** Create wallet → Create policy → Attach policy to wallet → Execute transactions within constraints.

**Supported chains:** Ethereum, Base, Polygon, Arbitrum, Optimism, Solana. Also: Cosmos, Stellar, Sui, Aptos, Tron, Bitcoin, NEAR, TON, Starknet.

**Security:** PRIVY_APP_SECRET grants full access. Never commit to version control. Start with testnet (Base Sepolia, chain ID 84532) before mainnet. Only fund wallets with amounts you can afford to lose.

**If compromised:** Rotate App Secret at dashboard.privy.io → Rotate authorization keys → Review wallet activity → Transfer remaining funds.

### Bankr Integration

```bash
# 1. Build unsigned transaction
ACTION=$(./scripts/enter-position.sh base-usdc-aave-v3-lending 0xBankrWallet '{"amount":"100"}')

# 2. Extract the unsigned transaction
UNSIGNED_TX=$(echo "$ACTION" | jq -r '.transactions[0].unsignedTransaction')

# 3. Submit to Bankr for signing and broadcasting
curl -X POST "https://api.bankr.bot/agent/submit" \
  -H "Authorization: Bearer $BANKR_API_KEY" \
  -H "Content-Type: application/json" \
  -d "$(jq -n --arg tx "$UNSIGNED_TX" '{transaction: $tx}')"
```

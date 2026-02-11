# YieldAgent by Yield.xyz

**The yield layer for the agent era.**

2,988 yield opportunities. 75+ chains. One unified interface. Staking, lending, vaults, restaking, and liquidity pools — all via the Yield.xyz API. Secure, controlled access to on-chain yield for agents.

Non-custodial. Schema-driven. Agent-native.

[agent.yield.xyz](https://agent.yield.xyz) · [ClawHub](https://clawhub.ai/apurvmishra/yield-agent) · [GitHub](https://github.com/stakekit/yield-agent)

### Core Capabilities

| Capability | Description |
|-----------|-------------|
| **Discover** | Query yields across every protocol and chain |
| **Enter** | Build unsigned transactions to deposit — your wallet signs |
| **Track** | View balances, accrued interest, pending actions |
| **Manage** | Claim rewards, restake, redelegate |
| **Exit** | Withdraw in one command |

---

## Quick Start

### Install

```bash
npx clawhub@latest install yield-agent
```

Or manually:
```bash
git clone https://github.com/stakekit/yield-agent.git ~/.openclaw/skills/yield-agent
chmod +x ~/.openclaw/skills/yield-agent/scripts/*.sh
```

### Use

```bash
# Find yields
./scripts/find-yields.sh base USDC

# Inspect a yield's schema
./scripts/get-yield-info.sh base-usdc-aave-v3-lending

# Enter a position
./scripts/enter-position.sh base-usdc-aave-v3-lending 0xYOUR_ADDRESS '{"amount":"100"}'

# Check balances
./scripts/check-portfolio.sh base-usdc-aave-v3-lending 0xYOUR_ADDRESS
```

A free shared API key is included in `skill.json`. For production, get your own from [dashboard.yield.xyz](https://dashboard.yield.xyz) or set `YIELDS_API_KEY` env var.

---

## Scripts

| Script | Endpoint | Description |
|--------|----------|-------------|
| `find-yields.sh` | `GET /v1/yields` | Discover yields by network and token |
| `get-yield-info.sh` | `GET /v1/yields/{id}` | Inspect yield schema, limits, tokens |
| `list-validators.sh` | `GET /v1/yields/{id}/validators` | List validators for staking |
| `enter-position.sh` | `POST /v1/actions/enter` | Enter a yield position |
| `exit-position.sh` | `POST /v1/actions/exit` | Exit a yield position |
| `manage-position.sh` | `POST /v1/actions/manage` | Claim, restake, redelegate |
| `check-portfolio.sh` | `POST /v1/yields/{id}/balances` | Check balances and pending actions |

---

## Project Structure

```
yield-agent/
├── SKILL.md                          # Main skill definition (agent reads this)
├── skill.json                        # Manifest, API config, triggers
├── scripts/                          # 7 bash scripts wrapping the API
├── references/
│   ├── openapi.yaml                  # OpenAPI spec (source of truth for types)
│   ├── safety.md                     # Safety checks and guardrails
│   ├── superskill.md                 # 40 advanced agent capabilities
│   ├── chain-formats.md              # Unsigned tx formats per chain
│   ├── wallet-integration.md         # Wallet setup and signing flow
│   └── examples.md                   # Agent conversation patterns
```

---

## Key Rules

1. **Always fetch the yield schema before calling an action** — the API is self-documenting
2. **Amounts are human-readable** — `"100"` = 100 USDC, `"1"` = 1 ETH
3. **Always submit the tx hash after broadcasting** — `PUT /v1/transactions/{txId}/submit-hash`
4. **Never modify `unsignedTransaction`** — sign exactly what the API returns
5. **Execute transactions in `stepIndex` order** — wait for CONFIRMED between each

---

## Requirements

- `curl` and `jq`
- A wallet for signing (Crossmint, Portal, Turnkey, Privy, or any compatible wallet)

---

## Security

Yield.xyz is **SOC 2 compliant** ([trust.yield.xyz](https://trust.yield.xyz/)). A safe, controlled environment for AI agents to access on-chain yields.

---

## Links

- [agent.yield.xyz](https://agent.yield.xyz)
- [ClawHub](https://clawhub.ai/apurvmishra/yield-agent)
- [GitHub](https://github.com/stakekit/yield-agent)
- [API Docs](https://docs.yield.xyz)
- [API Recipes](https://github.com/stakekit/api-recipes)
- [Get API Key](https://dashboard.yield.xyz)
- [Yield.xyz](https://yield.xyz)

---

## License

Apache 2.0

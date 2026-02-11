# 📈 YieldAgent: On-Chain Yield Skill for AI Agents

**Discover, enter, exit, and manage on-chain yield positions across 2,600+ opportunities on 80+ networks.**

Built by [Yield.xyz](https://yield.xyz) · [ClawHub](https://clawhub.ai/apurvmishra/yield-agent) · [API Docs](https://docs.yield.xyz) · [GitHub](https://github.com/stakekit/yield-agent)

---

## What is YieldAgent?

YieldAgent is an AI agent skill that provides full access to the Yield.xyz API for on-chain yield operations. It builds unsigned transactions — your wallet skill handles signing.

### Core Capabilities

| Capability | Description |
|-----------|-------------|
| **Discovery** | Find yields by network, token, provider, type across 80+ chains |
| **Enter** | Build unsigned transactions to deposit into any yield |
| **Exit** | Build unsigned transactions to withdraw from any yield |
| **Manage** | Claim rewards, restake, redelegate, and more |
| **Balances** | Check positions, pending actions, and rewards |
| **Schema-driven** | Every yield describes its own arguments — the agent reads the schema, never guesses |

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
./scripts/enter-position.sh base-usdc-aave-v3-lending 0xWallet '{"amount":"100"}'

# Check balances
./scripts/check-portfolio.sh base-usdc-aave-v3-lending 0xWallet
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
- A wallet skill for signing (Crossmint, Privy, Bankr, or any EVM/multi-chain wallet)

---

## Security

Yield.xyz is **SOC 2 compliant** ([trust.yield.xyz](https://trust.yield.xyz/)). A safe, controlled environment for AI agents to access on-chain yields.

---

## Links

- [ClawHub](https://clawhub.ai/apurvmishra/yield-agent)
- [GitHub](https://github.com/stakekit/yield-agent)
- [API Docs](https://docs.yield.xyz)
- [API Recipes](https://github.com/stakekit/api-recipes)
- [Get API Key](https://dashboard.yield.xyz)
- [Yield.xyz](https://yield.xyz)

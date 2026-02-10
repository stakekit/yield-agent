# YieldAgent by Yield.xyz

AI-powered on-chain yield discovery, transaction building, and portfolio management across 2,600+ opportunities on 80+ networks.

## Quick Start

```bash
cd yield-agent && chmod +x scripts/*.sh

# Find yields
./scripts/find-yields.sh base USDC

# Enter a yield position
./scripts/enter-position.sh base-usdc-aave-v3-lending 0xYOUR_ADDRESS '{"amount":"100"}'
```

A free API key is included in `skill.json`.

## Requirements

- `curl` and `jq` must be installed
- A wallet skill for signing transactions (see SKILL.md)

## Scripts

| Script | Purpose |
|--------|---------|
| `find-yields.sh` | Discover yield opportunities |
| `enter-position.sh` | Enter a yield position |
| `exit-position.sh` | Exit a yield position |
| `manage-position.sh` | Claim rewards, restake, etc. |
| `check-portfolio.sh` | Check position balances |
| `get-yield-info.sh` | Inspect yield metadata/limits |
| `list-validators.sh` | List validators for staking |

## Files

- `SKILL.md` — Main skill definition (agent reads this first)
- `references/safety.md` — Safety checks and constraints
- `HEARTBEAT.md` — Periodic position monitoring add-on
- `references/superskill.md` — 40 advanced agent capabilities add-on
- `skill.json` — API key and settings
- `references/openapi.yaml` — OpenAPI spec (source of truth for types)
- `references/chain-formats.md` — Unsigned transaction formats per chain
- `references/wallet-integration.md` — Wallet setup and signing flow
- `references/examples.md` — Agent conversation patterns

## Links

- [Yield.xyz API Docs](https://docs.yield.xyz)
- [API Recipes](https://github.com/stakekit/api-recipes)
- [Get API Key](https://dashboard.yield.xyz)

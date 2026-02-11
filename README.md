# YieldAgent by Yield.xyz

AI-powered on-chain yield discovery, transaction building, and portfolio management across 2,600+ opportunities on 80+ networks.

## Install

```bash
git clone https://github.com/stakekit/yield-agent.git ~/.openclaw/skills/yield-agent
```

Or one-line:
```bash
git clone https://github.com/stakekit/yield-agent.git ~/.openclaw/skills/yield-agent && chmod +x ~/.openclaw/skills/yield-agent/scripts/*.sh
```

## Quick Start

```bash
# Find yields
./scripts/find-yields.sh base USDC

# Enter a yield position
./scripts/enter-position.sh base-usdc-aave-v3-lending 0xYOUR_ADDRESS '{"amount":"100"}'
```

A free shared API key is included in `skill.json` for getting started. For production, replace it with your own from [dashboard.yield.xyz](https://dashboard.yield.xyz) or set `YIELDS_API_KEY` env var.

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
- `skill.json` — Manifest, API key, triggers
- `HEARTBEAT.md` — Periodic monitoring add-on
- `scripts/` — 7 bash scripts
- `references/openapi.yaml` — OpenAPI spec (source of truth for types)
- `references/safety.md` — Safety checks and guardrails
- `references/superskill.md` — 40 advanced agent capabilities
- `references/chain-formats.md` — Unsigned transaction formats per chain
- `references/wallet-integration.md` — Wallet setup and signing flow
- `references/examples.md` — Agent conversation patterns

## Links

- [Yield.xyz API Docs](https://docs.yield.xyz)
- [API Recipes](https://github.com/stakekit/api-recipes)
- [Get API Key](https://dashboard.yield.xyz)

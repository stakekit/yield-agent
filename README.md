# YieldAgent by Yield.xyz

AI-powered DeFi yield discovery, transaction building, and portfolio management across 2,600+ opportunities on 80+ networks.

## Quick Start

```bash
# 1. Unzip and enter the directory
cd yield-finder

# 2. Make scripts executable
chmod +x scripts/*.sh

# 3. Find yields (API key is included - ready to go)
./scripts/find-yields.sh base USDC

# 4. Build a transaction
./scripts/enter-position.sh base-usdc-aave-v3-lending 0xYOUR_ADDRESS 100000000
```

A free API key is included in `config.json`. No setup needed.

## Version

Check `config.json` for the current version. See `CHANGELOG.md` for release history.

## Requirements

- `curl` and `jq` must be installed
- A wallet solution for signing transactions (see SKILL.md for options)

## Scripts

| Script | Purpose | Example |
|--------|---------|---------|
| `find-yields.sh` | Discover yield opportunities | `./scripts/find-yields.sh base USDC` |
| `enter-position.sh` | Enter a yield position | `./scripts/enter-position.sh <yield_id> <address> <amount>` |
| `exit-position.sh` | Exit a yield position | `./scripts/exit-position.sh <yield_id> <address> <amount>` |
| `manage-position.sh` | Claim rewards, restake, etc. | `./scripts/manage-position.sh <yield_id> <address> CLAIM_REWARDS` |
| `check-portfolio.sh` | Check position balances | `./scripts/check-portfolio.sh <yield_id> <address>` |
| `get-yield-info.sh` | Inspect yield metadata/limits | `./scripts/get-yield-info.sh <yield_id>` |
| `list-validators.sh` | List validators for staking | `./scripts/list-validators.sh <yield_id>` |

## Install to ClawHub

```bash
mkdir -p ~/.clawhub/skills/yield-finder
cp -r * ~/.clawhub/skills/yield-finder/
```

Scripts auto-detect `~/.openclaw/`, `~/.clawhub/`, or `~/.clawdbot/` paths.

## Files

- `SKILL.md` - Main skill definition (agent reads this first)
- `config.json` - API key and settings
- `safety.md` - Safety checks and constraints
- `scripts/` - 7 bash scripts (5 core + 2 helpers)
- `references/openapi.yaml` - Full OpenAPI spec (source of truth for types and schemas)
- `references/examples.md` - Agent conversation patterns

## Links

- [Yield.xyz API Docs](https://docs.yield.xyz)
- [ClawHub](https://clawhub.ai)
- [Get your own API key](https://dashboard.yield.xyz)

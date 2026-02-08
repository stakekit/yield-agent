# YieldAgent Changelog

All notable changes to the YieldAgent skill package will be documented in this file.
Format follows [Semantic Versioning](https://semver.org/).

---

## [1.2.0] - 2026-02-08

### Added (schema-driven discovery & nonce management)
- `get-yield-info.sh` - Schema discovery: fetches full yield metadata including required arguments, entry limits, validator requirements, token details, and available manage actions
- `list-validators.sh` - Validator discovery: lists available validators for staking yields with APY, commission, status, and staked balance
- Nonce management in `deposit-with-bankr.sh` - Automatically increments nonce for sequential transactions (APPROVE + STAKE) to prevent nonce conflicts

### Improved
- `manage-position.sh` - Step-by-step passthrough workflow documentation: explains how to discover pending actions via check-portfolio.sh, extract passthrough values, and execute manage actions
- `deposit-with-bankr.sh` - Nonce offset tracking for multi-transaction batches (handles both hex and decimal nonce formats)
- Updated tool count from 9 to 11 in YAML frontmatter

### Changed
- Skill package now contains 20 files (was 18): 11 scripts + 4 references + 5 core files

---

## [1.1.0] - 2026-02-08

### Added (based on OpenClaw field testing feedback)
- `convert-amount.sh` - Amount conversion helper with full reference table (human-readable to raw integer)
- `deposit-with-bankr.sh` - End-to-end deposit flow: build tx, parse unsigned tx, add gas buffer, sign with Bankr, poll for confirmation
- `check-all-positions.sh` - Portfolio scanner: scan all yields on a network to find active positions for any address
- `poll-transaction.sh` - Transaction status poller: polls every N seconds until CONFIRMED or FAILED
- `--dry-run` flag for `build-transaction.sh` - Validates yield ID, amount, and minimum deposit without building a transaction
- `--summary` flag for `find-yields.sh` - Condensed table output with ID, type, APY, decimals, and minimum deposit
- Amount Conversion Reference table in SKILL.md with 12 common token/amount combinations
- "I Just Want to Deposit USDC" 10-line quick start at top of SKILL.md
- Minimum deposit pre-validation in `build-transaction.sh` (checks `args.enter.args.amount.minimum` before API call)

### Fixed
- Added prominent `unsignedTransaction` JSON string warning in SKILL.md and safety.md (it's a string, not an object - must parse before use)
- Better error handling in all 5 original scripts with actionable error messages and common cause suggestions
- All scripts now reference `convert-amount.sh` in their error output for amount format errors
- `check-portfolio.sh` now references `check-all-positions.sh` for portfolio-wide scanning
- Updated tool count from 5 to 9 in YAML frontmatter

### Changed
- Skill package now contains 18 files (was 14): 9 scripts + 4 references + 5 core files
- All error messages now include specific remediation steps

## [1.0.0] - 2026-02-08

### Added
- 5 executable scripts: find-yields, build-transaction, exit-position, manage-position, check-portfolio
- 21 curated Base network yields with 2%+ APY (Morpho, Aave, Compound, Euler, KelpDAO, Renzo, Angle)
- Bankr wallet integration (OpenClaw native) with unsigned tx handoff
- Privy agentic wallets setup guide with policy examples
- 8 wallet options across 5 security tiers (Platform, Enterprise, Verified, Community, Caution)
- 10 agent conversation patterns with real yield IDs
- Yield types reference with live API metadata for all 6 categories
- Safety system: 5 pre-execution checks, 30% gas buffer, nonce management, tx polling
- Cross-skill safety rules for Bankr composability
- Path auto-detection: `./`, `~/.openclaw/`, `~/.clawhub/`, `~/.clawdbot/`
- Environment variable overrides: YIELDS_API_KEY, YIELDS_API_URL, YIELD_NETWORK
- Amount format validation (raw integer strings only)
- Action validation for manage-position (7 valid actions)
- ZIP download with all 14 skill files
- Testing guide with smoke test and validation checklist

### Verified
- All 21 yield IDs confirmed live against Yield.xyz API
- 27 end-to-end tests passed (discovery, build tx, balance, exit, validation)
- Full ZIP extraction simulation: 10 cross-checks passed
- Both API endpoints working: api.yield.xyz and api.stakek.it

# YieldAgent Changelog

## [1.0.0] - 2026-02-10

### Initial Release

- 7 scripts: find-yields, enter-position, exit-position, manage-position, check-portfolio, get-yield-info, list-validators
- Schema-driven actions — arguments discovered from `mechanics.arguments` on each yield
- Human-readable amounts ("100" for 100 USDC, "1" for 1 ETH)
- Unsigned transaction formats for 12 chain families (EVM, Cosmos, Solana, Substrate, Tezos, TON, Near, Sui, Aptos, Cardano, Stellar, Tron)
- Hash submission flow via `PUT /v1/transactions/{txId}/submit-hash`
- OpenAPI spec included as source of truth for types and schemas
- Transaction execution in exact `stepIndex` order
- Safety checks: balance verification, network validation, amount format, sequential execution
- Config via `config.json` or environment variables (YIELDS_API_KEY, YIELDS_API_URL, YIELD_NETWORK)

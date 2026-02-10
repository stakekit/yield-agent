# Safety System

> **Critical: The agent must NEVER bypass safety checks.**

Every write operation (enter, exit, manage) should follow these checks.

## Pre-Execution Checks

### 1. Read the Yield Schema

Before calling any action, fetch the yield via `GET /v1/yields/{yieldId}` and read `mechanics.arguments`. Do not guess what arguments are needed — the API is self-documenting.

### 2. Balance Verification

Does the user have the token balance they are trying to deposit?

```bash
./scripts/check-portfolio.sh <yield_id> <address>
# If balance < amount, abort and inform the user
```

**Why:** Prevents failed transactions that waste gas.

### 3. Network Validation

The yield ID encodes its network (e.g., `base-usdc-aave-v3-lending` = Base). Ensure the wallet is connected to the correct network before submitting transactions.

### 4. Amount Format

Amounts are human-readable strings. `"100"` means 100 USDC. `"1"` means 1 ETH. The API handles decimal conversion internally.

```bash
# CORRECT:
"100"     # 100 USDC
"1"       # 1 ETH
"0.5"     # 0.5 SOL

# INCORRECT:
"1e18"           # Scientific notation
"100,000"        # Commas
```

### 5. Transaction Execution Order

After signing and broadcasting every transaction, **always submit the hash via `PUT /v1/transactions/{txId}/submit-hash`**. Balances will not appear on the balances endpoint until the hash is submitted.

If an action produces multiple transactions (e.g., APPROVAL + STAKE), execute them in exact `stepIndex` order. Wait for `CONFIRMED` before proceeding to the next. Never skip or reorder.

## Safety Rules

1. **NO Private Keys:** Never ask for, store, or log private keys. This skill only builds unsigned transactions.
2. **Wallet Handoff:** Pass each transaction's `unsignedTransaction` to the wallet skill. Never attempt to sign.
3. **Balance Check First:** Verify user balance before entering positions.
4. **User Confirmation:** Present transaction details and get user approval before signing.
5. **Rate Limits:** Respect the `retry-after` header on 429 responses.
6. **Key Security:** API keys should be in config.json or YIELDS_API_KEY env var, not in code.
7. **Sequential Processing:** Never submit multiple transactions simultaneously. Wait for confirmation between each.
8. **Passthrough Integrity:** Never modify the `passthrough` string from `pendingActions[]`. It is opaque.

## Cross-Skill Safety

When combining yield-agent with wallet skills:

1. **Address match:** Ensure the address passed to yield-agent matches the wallet's address.
2. **Chain alignment:** Verify the yield's network is supported by the wallet.
3. **Sequential operations:** When chaining workflows (e.g., swap then deposit), wait for each step's confirmation before proceeding.
4. **Single signer:** Each unsigned transaction should be signed by exactly one wallet.

## Golden Rule

> This skill is a **Transaction Builder**, not a **Signer**.
>
> The Yield.xyz skill constructs unsigned transactions. Signing and broadcasting
> is always delegated to the wallet skill. This separation ensures private keys
> are never exposed to yield logic.

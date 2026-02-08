# Safety System

> **Critical: The agent must NEVER bypass safety checks.**

> **CRITICAL: `unsignedTransaction` format varies by chain.**
> The field is typed `string | object | null`. For EVM chains it's a JSON string that must be parsed. For Substrate chains it's already an object. For Cosmos/Solana/Near it's an opaque encoded string. See the "Unsigned Transaction Formats by Chain" section in SKILL.md.

Every write operation (enter, exit, manage) must pass these 5 pre-execution checks before constructing a transaction.

## Pre-Execution Safety Checks

### 1. Balance Verification

Does the user actually have the token balance they are trying to stake/deposit?

```bash
# Check user balance before entering a position
./scripts/check-portfolio.sh <yield_id> 0xUserWallet

# Verify the token balance covers the intended deposit amount
# If balance < amount, abort and inform the user
```

**Why:** Prevents failed transactions that waste gas fees on reverted calls.

### 2. Gas Estimation

Does the user have enough native token (ETH, SOL, MATIC, etc.) to pay for gas?

| Network | Native Token | Typical Gas Cost |
|---------|-------------|-----------------|
| Base | ETH | Very Low (~$0.01) |
| Arbitrum | ETH | Low (~$0.05) |
| Polygon | MATIC | Low (~$0.01) |
| Ethereum | ETH | High (~$5-50) |
| Optimism | ETH | Low (~$0.05) |
| Solana | SOL | Very Low (~$0.001) |

**Gas Safety Margin:** Always increase `gasLimit` by 30% before signing. The official SDK does `Math.floor(Number(gasLimit) * 1.3)` to prevent out-of-gas failures.

**Why:** Transactions without sufficient gas fail silently or revert, wasting the approval transaction's gas.

### 3. Network Validation

Is the Yield ID valid for the current network context?

```bash
# Yield IDs encode their network: base-usdc-aave-v3-lending = Base network
# ethereum-eth-lido-staking = Ethereum network

# Ensure the wallet is connected to the correct network
# before submitting the transaction
```

**Why:** Sending a Base transaction to Ethereum mainnet will fail or send funds to wrong contracts.

### 4. Amount Format Validation

Is the amount a raw integer string? Scientific notation causes reverts.

```bash
# CORRECT formats:
"100000000"          # 100 USDC (6 decimals)
"1000000000000000000" # 1 ETH (18 decimals)

# INCORRECT formats (will cause reverts):
"1.5"                # Decimal not allowed
"1e18"               # Scientific notation not allowed
100000000            # Number type not allowed (must be string)
"100,000,000"        # Commas not allowed
```

**Common decimal references:**

| Token | Decimals | 1 Token Raw Value |
|-------|----------|-------------------|
| USDC | 6 | "1000000" |
| USDT | 6 | "1000000" |
| DAI | 18 | "1000000000000000000" |
| ETH | 18 | "1000000000000000000" |
| WBTC | 8 | "100000000" |
| SOL | 9 | "1000000000" |

**Why:** The API requires raw integer strings for precision. Malformed amounts cause smart contract reverts.

### 5. Wallet Connection

Is the Wallet Skill available and ready to receive the transaction?

```bash
# Before building a transaction, verify:
# 1. A wallet skill is installed (Agent Wallet, circle-wallet, etc.)
# 2. The wallet is connected and responsive
# 3. The wallet supports the target network

# The agent should check for wallet skill availability:
wallet_skill=$(openclaw.skills.load 'wallet-skill')
# If this fails, inform the user they need to install a wallet skill
```

**Why:** Building a transaction without a wallet to sign it wastes API calls and confuses the user.

## Transaction Safety

### Multi-Transaction Actions

Some actions (e.g., entering a vault) produce multiple transactions (APPROVE + STAKE). These must be processed sequentially:

1. Parse the first `unsignedTransaction` JSON string
2. Increase `gasLimit` by 30%
3. Set the correct nonce
4. Sign and submit: `POST /v1/transactions/{txId}/submit` with `{ signedTransaction: "0x..." }`
5. Poll `GET /v1/transactions/{txId}` every 2 seconds until CONFIRMED
6. Increment nonce by 1
7. Process the next transaction

**Never submit multiple transactions simultaneously.** Wait for each CONFIRMED status before proceeding.

### Nonce Management

When an Action contains multiple transactions, manage nonces sequentially:

```
Transaction 1 (APPROVE): nonce = current_nonce
Transaction 2 (STAKE):   nonce = current_nonce + 1
Transaction 3 (if any):  nonce = current_nonce + 2
```

### Confirmation Polling

After submitting a signed transaction, poll for status:

```bash
# Poll every 2 seconds, max 60 attempts (2 minute timeout)
while status != "CONFIRMED" && attempts < 60:
  GET /v1/transactions/{txId}
  if status == "FAILED": abort and report error
  if status == "CONFIRMED": proceed to next transaction
  wait 2 seconds
```

## Safety Rules

1. **NO Private Keys:** Never ask for, store, or log private keys. The skill only builds unsigned transactions.
2. **Wallet Handoff:** After building a TX, pass the parsed `unsignedTransaction` to the Wallet Skill. Never attempt to sign.
3. **Balance Check First:** Always verify user balance before building Enter transactions.
4. **Amount Validation:** Validate amount format locally before making API calls.
5. **User Confirmation:** Always present transaction details and get user confirmation before signing.
6. **Logging Safety:** Do not log full API responses containing sensitive user balances in plain text.
7. **Rate Limits:** Respect the `Retry-After` header to avoid API bans.
8. **Key Security:** API keys should be stored in config.json (not committed) or YIELDS_API_KEY environment variable.
9. **Gas Buffer:** Always add 30% to gasLimit before signing to prevent out-of-gas failures.
10. **Sequential Processing:** Never submit multiple transactions simultaneously. Wait for confirmation between each.

## Cross-Skill Safety (OpenClaw Composability)

When combining yield-finder with other skills (like Bankr), follow these additional safety rules:

### Bankr Integration Safety

1. **Verify wallet address matches.** When building transactions with yield-finder, ensure the address argument matches your Bankr wallet address. Mismatched addresses will produce transactions that cannot be signed.

2. **Confirm chain alignment.** Bankr supports Base, Ethereum, Polygon, Unichain, and Solana. Verify the yield's network matches a Bankr-supported chain before building the transaction.

3. **Sequential operations only.** When chaining swap-then-yield workflows (Bankr swap followed by yield-finder enter), wait for the swap confirmation before building the yield transaction. The yield transaction depends on the swapped balance being available.

4. **Single skill per transaction.** Each unsigned transaction should be signed by exactly one wallet skill. Do not pass the same unsigned transaction to multiple wallets.

5. **Passthrough integrity.** When using `manage-position.sh` with passthrough values from `check-portfolio.sh`, do not modify the passthrough string. It is an opaque token required by the API.

### Multi-Skill Workflow Checklist

- [ ] All skills use the same wallet address
- [ ] Chain/network is supported by both the yield and the signing wallet
- [ ] Each step waits for the previous step's confirmation
- [ ] Unsigned transactions are not modified between skills
- [ ] Gas buffer (30%) applied before submitting to wallet skill

## Golden Rule

> This skill is a **Transaction Builder**, not a **Signer**.
>
> The Yield.xyz skill constructs unsigned transactions. Signing and broadcasting
> is always delegated to secure wallet skills (Bankr, Privy, circle-wallet, etc.).
> This separation ensures private keys are never exposed to yield logic.

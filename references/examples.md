# Yield.xyz Usage Examples

## OpenClaw Agent Conversations

These are real conversation flows showing how an agent uses the yield-finder skill on OpenClaw. Each example shows the user prompt, what the agent does behind the scenes, and how it responds. All yield IDs are real and verified against the live Yield.xyz API on Base network.

---

### Conversation 1: First-Time Discovery

**User:** "What yield opportunities are available for USDC on Base?"

**Agent thinks:** I'll search for USDC yields on Base using the yield-finder skill.

**Agent runs:**
```bash
./scripts/find-yields.sh base USDC
```

**Agent responds:**

> I found several **USDC yield opportunities** on Base. Here are the top options by APY:
>
> | Protocol | Type | APY | Yield ID |
> |----------|------|-----|----------|
> | Morpho (Flagship) | Vault | 5.72% | `base-usdc-cousdc-0x1d3b1cd0a0f242d598834b3f2d126dc6bd774657-4626-vault` |
> | Morpho (MEV Capital) | Vault | 4.91% | `base-usdc-mevfusdc-0x8773447e6369472d9b72f064ea62e405216e9084-4626-vault` |
> | Morpho (Gauntlet) | Vault | 4.36% | `base-usdc-gtusdcf-0x236919f11ff9ea9550a4287696c2fc9e18e6e890-4626-vault` |
> | Aave v3 | Lending | 3.82% | `base-usdc-aave-v3-lending` |
> | Compound v3 | Lending | 3.19% | `base-usdc-compound-v3-lending` |
>
> The **Morpho Flagship vault** at 5.72% is the highest. Morpho vaults are curated by professional risk managers and auto-optimize across lending markets. Aave and Compound are simpler lending protocols — lower APY but more battle-tested.
>
> Would you like me to deposit into any of these? I'll need your wallet address and the amount.

---

### Conversation 2: Depositing into Morpho Flagship

**User:** "Deposit 500 USDC into the Morpho flagship vault. My wallet is 0x742d35Cc6634C0532925a3b844Bc454e4438f44e"

**Agent thinks:** 500 USDC = 500,000,000 (6 decimals). I'll build the transaction for the Morpho flagship vault.

**Agent runs:**
```bash
./scripts/enter-position.sh base-usdc-cousdc-0x1d3b1cd0a0f242d598834b3f2d126dc6bd774657-4626-vault 0x742d35Cc6634C0532925a3b844Bc454e4438f44e 500000000
```

**Agent responds:**

> I've prepared your deposit of **500 USDC** into the Morpho Flagship USDC vault on Base.
>
> **Transaction Summary:**
> - Action: Deposit (Enter)
> - Amount: 500 USDC ($500.00)
> - Protocol: Morpho (Flagship vault)
> - Network: Base
> - Current APY: 5.72%
> - Estimated Annual Earnings: ~$28.60
>
> The transaction is ready for signing. There are **2 steps**:
> 1. Approve USDC spending (if not already approved)
> 2. Deposit into Morpho vault
>
> Shall I sign and submit this with your wallet?

**Illustrative API Response (actual IDs and data will vary):**
```json
{
  "id": "<action-uuid>",
  "intent": "enter",
  "type": "SUPPLY",
  "yieldId": "base-usdc-cousdc-0x1d3b1cd0a0f242d598834b3f2d126dc6bd774657-4626-vault",
  "address": "0x742d...",
  "amount": "500.000000",
  "amountRaw": "500000000",
  "status": "CREATED",
  "transactions": [
    {
      "id": "<tx-uuid-1>",
      "title": "Approve Transaction",
      "network": "base",
      "status": "CREATED",
      "type": "APPROVAL",
      "unsignedTransaction": "<JSON string - parse before signing>",
      "stepIndex": 0,
      "gasEstimate": "<JSON string with amount and gasLimit>"
    },
    {
      "id": "<tx-uuid-2>",
      "title": "SUPPLY Transaction",
      "network": "base",
      "status": "CREATED",
      "type": "SUPPLY",
      "unsignedTransaction": "<JSON string - parse before signing>",
      "stepIndex": 1,
      "gasEstimate": "<JSON string with amount and gasLimit>"
    }
  ]
}
```

**Transaction signing flow:**
```bash
# 1. Parse each unsignedTransaction JSON string
# 2. Increase gasLimit by 30% for safety margin
# 3. Sign with wallet (Bankr, Privy, or other)
# 4. Submit: POST /v1/transactions/{txId}/submit { "signedTransaction": "0x..." }
# 5. Poll: GET /v1/transactions/{txId} until status = "CONFIRMED"
# 6. Repeat for next transaction in sequence (increment nonce)
```

---

### Conversation 3: Checking a Position

**User:** "How is my Morpho USDC position doing?"

**Agent thinks:** I'll check the balance for their Morpho flagship USDC vault position.

**Agent runs:**
```bash
./scripts/check-portfolio.sh base-usdc-cousdc-0x1d3b1cd0a0f242d598834b3f2d126dc6bd774657-4626-vault 0x742d35Cc6634C0532925a3b844Bc454e4438f44e
```

**Agent responds:**

> Your **Morpho Flagship USDC** vault position on Base:
>
> | | Amount | Value |
> |---|--------|-------|
> | Deposited | 502.35 USDC | $502.35 |
> | Status | Earning | Active |
>
> You've earned **$2.35 in interest** since your deposit. Your position is actively earning at the current 5.72% APY.
>
> At this rate, you'd earn approximately:
> - **$28.73** per year
> - **$2.39** per month
>
> Would you like to add more, withdraw some, or check other positions?

**Illustrative API Response (actual values will vary):**
```json
{
  "yieldId": "base-usdc-cousdc-0x1d3b1cd0a0f242d598834b3f2d126dc6bd774657-4626-vault",
  "balances": [
    {
      "address": "0x742d...",
      "type": "active",
      "amount": "502.350000",
      "amountRaw": "502350000",
      "amountUsd": "502.35",
      "token": { "symbol": "USDC", "decimals": 6, "network": "base" },
      "pendingActions": [],
      "isEarning": true
    }
  ]
}
```

---

### Conversation 4: Claiming Rewards

**User:** "Do I have any rewards to claim on my Cosmos staking?"

**Agent thinks:** I'll check balances for their ATOM staking position and look for pendingActions in the response.

**Agent runs:**
```bash
./scripts/check-portfolio.sh cosmos-atom-native-staking 0x742d35Cc6634C0532925a3b844Bc454e4438f44e
```

**Agent responds:**

> Your **ATOM Native Staking** position on Cosmos:
>
> | | Amount | Value |
> |---|--------|-------|
> | Staked | 100 ATOM | $850.00 |
> | Claimable Rewards | 2.5 ATOM | $21.25 |
>
> You have **2.5 ATOM ($21.25)** in claimable staking rewards. Would you like me to claim them?
>
> *Note: Cosmos staking distributes rewards separately from your staked balance. You need to explicitly claim them.*

**User:** "Yes, claim my rewards"

**Agent thinks:** I'll use the passthrough value from the pendingActions in the balance response.

**Agent runs:**
```bash
# The passthrough value comes from the pendingActions array in the balance response
./scripts/manage-position.sh cosmos-atom-native-staking 0x742d35Cc6634C0532925a3b844Bc454e4438f44e CLAIM_REWARDS "<passthrough-from-balances>"
```

**Agent responds:**

> Reward claim submitted for **2.5 ATOM ($21.25)** from your Cosmos staking position.
>
> Transaction confirmed. The ATOM has been sent to your wallet.
>
> Would you like to restake these rewards to compound your earnings, or keep them liquid?
>
> *Tip: Not all staking protocols require manual claiming. Lido (ETH) and other liquid staking protocols auto-compound rewards into your staked balance. Cosmos, Polkadot, and similar PoS chains require explicit reward claims.*

---

### Conversation 5: Withdrawing from a Vault

**User:** "I want to withdraw 200 USDC from my Morpho vault"

**Agent thinks:** 200 USDC = 200,000,000 raw. I'll build the exit transaction.

**Agent runs:**
```bash
./scripts/exit-position.sh base-usdc-cousdc-0x1d3b1cd0a0f242d598834b3f2d126dc6bd774657-4626-vault 0x742d35Cc6634C0532925a3b844Bc454e4438f44e 200000000
```

**Agent responds:**

> Withdrawal prepared for **200 USDC** from Morpho Flagship vault on Base.
>
> **Transaction Summary:**
> - Action: Withdraw (Exit)
> - Amount: 200 USDC ($200.00)
> - Network: Base
> - Estimated Gas: ~0.000028 ETH ($0.07)
>
> After this withdrawal, your remaining position will be approximately **302.35 USDC** continuing to earn 5.72% APY.
>
> Ready to sign and submit?

---

### Conversation 6: Comparing ETH Yields on Base

**User:** "Where can I get the best yield for my ETH on Base?"

**Agent thinks:** I'll search ETH/WETH yields on Base to compare protocols.

**Agent runs:**
```bash
./scripts/find-yields.sh base ETH 10
./scripts/find-yields.sh base WETH 10
```

**Agent responds:**

> Here are the best **ETH yield opportunities on Base**, all above 2% APY:
>
> | Protocol | Type | APY | Token | Yield ID |
> |----------|------|-----|-------|----------|
> | Morpho (9Summits Core) | Vault | 7.06% | WETH | `base-weth-9sethcore-0x5496b...-4626-vault` |
> | KelpDAO | Restaking | 2.95% | ETH | `base-kelpdao-rseth-staking` |
> | Morpho (Steakhouse) | Vault | 2.77% | WETH | `base-weth-cseth-0x0983...-4626-vault` |
> | Renzo | Restaking | 2.68% | ETH | `base-renzo-ezeth-staking` |
> | Morpho | Vault | 2.31% | WETH | `base-weth-exmweth-0x5a32...-4626-vault` |
>
> **My recommendation:** The **Morpho 9Summits Core vault** at 7.06% APY is the highest. It's a curated Morpho vault — higher APY but involves smart contract risk across multiple lending markets.
>
> For lower risk, **KelpDAO Restaking** at 2.95% earns you restaking rewards on top of ETH staking yield. **Renzo** is similar at 2.68%.
>
> Which option interests you?

---

### Conversation 7: Portfolio Rebalance — Compound to Morpho

**User:** "Move my USDC from Compound to wherever the APY is higher"

**Agent thinks:** I'll check their Compound position, find better yields, then execute the move.

**Agent runs:**
```bash
# Step 1: Check current position
./scripts/check-portfolio.sh base-usdc-compound-v3-lending 0x742d35Cc6634C0532925a3b844Bc454e4438f44e

# Step 2: Find better yields
./scripts/find-yields.sh base USDC
```

**Agent responds:**

> Your **Compound v3** position: **200 USDC** earning **3.19% APY**.
>
> I found better options on Base:
>
> | Protocol | APY | Improvement |
> |----------|-----|-------------|
> | Morpho Flagship | 5.72% | +2.53% |
> | Morpho (MEV Capital) | 4.91% | +1.72% |
> | Aave v3 | 3.82% | +0.63% |
>
> **Rebalance plan** (moving to Morpho Flagship at 5.72%):
> 1. Withdraw 200 USDC from Compound v3 (gas: ~$0.05)
> 2. Deposit 200 USDC into Morpho Flagship vault (gas: ~$0.08)
> 3. Total gas cost: ~$0.13
>
> This would increase your annual earnings from **$6.38 to $11.44** (+$5.06/year).
>
> The extra yield covers the gas cost **immediately**. Want me to proceed?

**User:** "Yes, do it"

**Agent runs:**
```bash
# Exit Compound
./scripts/exit-position.sh base-usdc-compound-v3-lending 0x742d35Cc6634C0532925a3b844Bc454e4438f44e 200000000
# Sign + submit + confirm

# Enter Morpho Flagship
./scripts/enter-position.sh base-usdc-cousdc-0x1d3b1cd0a0f242d598834b3f2d126dc6bd774657-4626-vault 0x742d35Cc6634C0532925a3b844Bc454e4438f44e 200000000
# Sign + submit + confirm
```

**Agent responds:**

> Done! Your USDC has been moved:
>
> - Withdrew **200 USDC** from Compound v3
> - Deposited **200 USDC** into Morpho Flagship vault
> - Total gas used: **$0.11**
>
> You're now earning **5.72% APY** instead of 3.19%. Your new position is active and earning.

---

### Conversation 8: Staking with Validator Selection

**User:** "I want to stake my ATOM on Cosmos"

**Agent thinks:** Cosmos staking requires validator selection. I'll find yields first, then fetch available validators.

**Agent runs:**
```bash
# Step 1: Find the staking yield
./scripts/find-yields.sh cosmos ATOM

# Step 2: Fetch available validators for this yield
curl -s -X GET "https://api.stakek.it/v1/yields/cosmos-atom-native-staking/validators?limit=10" \
  -H "x-api-key: $(jq -r '.apiKey' config.json)" | jq '.items[] | {name, address, commission, stakedBalance, status}'
```

**Agent responds:**

> I found **ATOM staking on Cosmos** with an APY of approximately **15-20%** depending on the validator.
>
> This type of staking **requires you to choose a validator**. I fetched the top validators for you:
>
> | Validator | Commission | Status |
> |-----------|------------|--------|
> | Chorus One | 7.5% | Active |
> | Figment | 9.0% | Active |
> | Everstake | 5.0% | Active |
>
> Lower commission means more rewards for you. How much ATOM would you like to stake, and which validator do you prefer?

**User:** "Stake 100 ATOM with Everstake"

**Agent runs:**
```bash
./scripts/enter-position.sh cosmos-atom-native-staking 0x742d... 100000000 cosmos1everstakevalidatoraddress
```

**Agent responds:**

> Staking transaction prepared for **100 ATOM** with Everstake (5% commission).
>
> **Expected earnings:** ~15-20 ATOM per year at current rates.
>
> Note: Unstaking ATOM has a **21-day cooldown period**. During this time, your tokens won't earn rewards and can't be transferred.
>
> Ready to sign?

---

### Conversation 9: Bankr Swap-Then-Yield (OpenClaw)

**User:** "I have ETH but I want to earn yield on USDC. Can you handle the swap and deposit?"

**Agent thinks:** I'll use Bankr to swap ETH to USDC, then enter a high-yield vault position.

**Agent responds:**

> Sure! Here's what I'll do:
>
> 1. Swap your ETH to USDC on Base using Bankr (low gas)
> 2. Deposit the USDC into the highest-yielding vault (Morpho Flagship at 5.72%)
>
> How much ETH would you like to convert?

**User:** "0.5 ETH"

**Agent runs:**
```bash
# Step 1: Swap via Bankr
scripts/bankr.sh "Swap 0.5 ETH to USDC on Base"
# Result: ~1,300 USDC received

# Step 2: Find best yield
./scripts/find-yields.sh base USDC

# Step 3: Enter Morpho Flagship vault
./scripts/enter-position.sh base-usdc-cousdc-0x1d3b1cd0a0f242d598834b3f2d126dc6bd774657-4626-vault 0xBankrWallet 1300000000
# Sign via Bankr
```

**Agent responds:**

> All done! Here's what happened:
>
> 1. Swapped **0.5 ETH** to **1,300 USDC** on Base
> 2. Deposited **1,300 USDC** into Morpho Flagship vault at **5.72% APY**
> 3. Estimated annual earnings: **$74.36**
>
> Your USDC is now earning yield automatically. You can check your position or withdraw anytime.

---

### Conversation 10: Safety Guardrails in Action

**User:** "Deposit all my USDC into the highest APY vault"

**Agent thinks:** Safety checks: I should verify the amount, check the protocol, and warn about concentration risk.

**Agent runs:**
```bash
./scripts/check-portfolio.sh base-usdc-aave-v3-lending 0xWallet
./scripts/find-yields.sh base USDC
```

**Agent responds:**

> Before I proceed, a few safety notes:
>
> Your wallet has **5,000 USDC**. The highest APY vault I found on Base is the **Morpho Flagship** at **5.72% APY**. Here are some things to consider:
>
> 1. **Concentration risk** — Putting all funds in one vault is risky. Consider splitting across 2-3 protocols.
> 2. **APY volatility** — Vault APYs fluctuate as capital flows in and out.
> 3. **Smart contract risk** — Morpho vaults interact with multiple lending markets, adding layers of smart contract risk.
>
> **My suggestion — split across two trusted protocols:**
> - 3,000 USDC into Morpho Flagship (5.72% APY, curated vault)
> - 2,000 USDC into Aave v3 (3.82% APY, battle-tested lending)
>
> **Blended APY: ~4.96%** | Estimated annual earnings: **~$248**
>
> This gives you diversification across a curated vault and an established lending protocol. What would you prefer?

---

## Curated Base Yields (2%+ APY, Verified Live)

These are the top trusted yield opportunities on Base, verified against the live Yield.xyz API. All support easy deposit and exit.

### USDC Yields

| Protocol | APY | Yield ID | Type | Fee |
|----------|-----|----------|------|-----|
| Morpho (Flagship) | 5.72% | `base-usdc-cousdc-0x1d3b1cd0a0f242d598834b3f2d126dc6bd774657-4626-vault` | Vault | 10% perf |
| Morpho (MEV Capital) | 4.91% | `base-usdc-mevfusdc-0x8773447e6369472d9b72f064ea62e405216e9084-4626-vault` | Vault | 10% perf |
| Morpho (ExtraFi) | 4.80% | `base-usdc-exmusdc-0x23479229e52ab6aad312d0b03df9f33b46753b5e-4626-vault` | Vault | 10% perf |
| Morpho (Gauntlet) | 4.36% | `base-usdc-gtusdcf-0x236919f11ff9ea9550a4287696c2fc9e18e6e890-4626-vault` | Vault | 10% perf |
| Morpho (Apostle) | 4.32% | `base-usdc-apusdc-0x75e1a1f9535c01cdce25e51ea4aff0d171337e1f-4626-vault` | Vault | 10% perf |
| Morpho (CSBOR) | 4.32% | `base-usdc-csborusdc-0x43e623ff7d14d5b105f7be9c488f36dbf11d1f46-4626-vault` | Vault | 10% perf |
| Morpho (RE7) | 3.87% | `base-usdc-re7usdc-0x12afdefb2237a5963e7bab3e2d46ad0eee70406e-4626-vault` | Vault | 10% perf |
| Aave v3 | 3.82% | `base-usdc-aave-v3-lending` | Lending | None |
| Morpho (Spark) | 3.78% | `base-usdc-sparkusdc-0x7bfa7c4f149e7415b73bdedfe609237e29cbf34a-4626-vault` | Vault | 10% perf |
| Compound v3 | 3.19% | `base-usdc-compound-v3-lending` | Lending | None |

### ETH / WETH Yields

| Protocol | APY | Yield ID | Type | Fee |
|----------|-----|----------|------|-----|
| Morpho (9Summits Core) | 7.06% | `base-weth-9sethcore-0x5496b42ad0decebfab0db944d83260e60d54f667-4626-vault` | Vault | 10% perf |
| KelpDAO (rsETH) | 2.95% | `base-kelpdao-rseth-staking` | Restaking | None |
| Morpho (Steakhouse) | 2.77% | `base-weth-cseth-0x09832347586e238841f49149c84d121bc2191c53-4626-vault` | Vault | 10% perf |
| Renzo (ezETH) | 2.68% | `base-renzo-ezeth-staking` | Restaking | None |
| Morpho | 2.31% | `base-weth-exmweth-0x5a32099837d89e3a794a44fb131cbbad41f87a8c-4626-vault` | Vault | 10% perf |

### Other Notable Yields

| Token | Protocol | APY | Yield ID | Type |
|-------|----------|-----|----------|------|
| USDA | Angle (stUSD) | 10.10% | `base-usda-stusd-0x0022228a2cc5e7ef0274a7baa600d44da5ab5776-4626-vault` | Vault |
| USDC | Euler | 5.68% | `base-usdc-eusdc-29-0x085178078796da17b191f9081b5e2fccc79a7ee7-4626-vault` | Vault |
| USDC | Euler | 5.02% | `base-usdc-eusdc-49-0x4c1aeda9b43efcf1da1d1755b18802aabe90f61e-4626-vault` | Vault |
| cbBTC | Euler | 4.02% | `base-cbbtc-ecbbtc-7-0xe72ea97aaf905c5f10040f78887cc8de8eaec7e4-4626-vault` | Vault |
| WETH | Euler (Yo Protocol) | 2.80% | `base-weth-eweth-20-0xf3bb6b0a9beaf9240d7f4a91341d5df6bf37caea-4626-vault` | Vault |
| GHO | Aave v3 | 2.10% | `base-gho-aave-v3-lending` | Lending |

> **Note:** APYs are live snapshots and fluctuate. Morpho vault performance fees (typically 10%) are already deducted from the displayed APY. Use `./scripts/find-yields.sh base <TOKEN>` to get current rates.

---

## API Reference Examples

### Discovery with Pagination

```bash
# First page
./scripts/find-yields.sh base USDC 20 0

# Second page
./scripts/find-yields.sh base USDC 20 20

# All yields on a network (no token filter)
./scripts/find-yields.sh ethereum "" 50
```

### Common Yield IDs

| Yield ID | Network | Token | Protocol | Type |
|----------|---------|-------|----------|------|
| `base-usdc-cousdc-0x1d3b1...-4626-vault` | Base | USDC | Morpho (Flagship) | Vault |
| `base-weth-9sethcore-0x5496b...-4626-vault` | Base | WETH | Morpho (9Summits) | Vault |
| `base-usdc-aave-v3-lending` | Base | USDC | Aave V3 | Lending |
| `base-usdc-compound-v3-lending` | Base | USDC | Compound V3 | Lending |
| `base-kelpdao-rseth-staking` | Base | ETH | KelpDAO | Restaking |
| `base-renzo-ezeth-staking` | Base | ETH | Renzo | Restaking |
| `ethereum-eth-lido-staking` | Ethereum | ETH | Lido | Staking |
| `cosmos-atom-native-staking` | Cosmos | ATOM | Native | Staking |

> Morpho and Euler vault IDs include contract addresses (e.g., `base-usdc-mevfusdc-0x8773...-4626-vault`). Use `find-yields.sh` to discover current IDs.

### Amount Formatting

Amounts must be raw integer strings (not decimals):

| Token | Decimals | 100 tokens | 0.5 tokens |
|-------|----------|------------|------------|
| USDC | 6 | `100000000` | `500000` |
| ETH | 18 | `100000000000000000000` | `500000000000000000` |
| ATOM | 6 | `100000000` | `500000` |
| DAI | 18 | `100000000000000000000` | `500000000000000000` |

### Environment Variable Overrides

Override config.json values without editing the file:

```bash
export YIELDS_API_KEY="your-custom-key"
export YIELDS_API_URL="https://api.stakek.it/v1"
export YIELD_NETWORK="ethereum"

./scripts/find-yields.sh    # Uses env vars instead of config.json
```

---

## Testing Guide

### Quick Smoke Test

Run this immediately after unzipping to verify everything works:

```bash
cd yield-finder
chmod +x scripts/*.sh

# Test 1: Discovery (should return JSON with yields)
echo "=== Test 1: Discovery ==="
./scripts/find-yields.sh base USDC 2

# Test 2: Balance check (should return JSON with balances)
echo "=== Test 2: Balance Check ==="
./scripts/check-portfolio.sh base-usdc-aave-v3-lending 0x0000000000000000000000000000000000000001

# Test 3: Build transaction (should return Action with transactions)
echo "=== Test 3: Build Transaction ==="
./scripts/enter-position.sh base-usdc-aave-v3-lending 0x0000000000000000000000000000000000000001 1000000

# Test 4: Exit position (should return Action with transactions)
echo "=== Test 4: Exit Position ==="
./scripts/exit-position.sh base-usdc-aave-v3-lending 0x0000000000000000000000000000000000000001 500000

# Test 5: Input validation (should show error)
echo "=== Test 5: Input Validation ==="
./scripts/enter-position.sh base-usdc-aave-v3-lending 0x0000000000000000000000000000000000000001 "not-a-number"
```

### Validation Checklist

| Test | Command | Expected |
|------|---------|----------|
| API works | `./scripts/find-yields.sh base` | JSON with `items` array |
| Token filter | `./scripts/find-yields.sh base USDC` | Only USDC yields |
| Balance check | `./scripts/check-portfolio.sh <id> <addr>` | JSON with `balances` |
| Build TX | `./scripts/enter-position.sh <id> <addr> 1000000` | Action with `transactions` |
| Bad amount | `./scripts/enter-position.sh <id> <addr> "abc"` | Error: raw integer |
| No args | `./scripts/find-yields.sh` | Usage message |
| Bad API key | `YIELDS_API_KEY=bad ./scripts/find-yields.sh base` | 401 error |

### Error Handling

```bash
# Invalid API key
YIELDS_API_KEY="invalid" ./scripts/find-yields.sh base USDC
# Expected: 401 Unauthorized

# Invalid yield ID
./scripts/enter-position.sh "nonexistent-yield" "0x..." "1000000"
# Expected: 404 or error message

# Malformed amount (caught locally before API call)
./scripts/enter-position.sh "base-usdc-aave-v3-lending" "0x..." "one hundred"
# Expected: "Error: Amount must be a raw integer string"
```

---

## Transaction Signing Flow

After building a transaction, the agent must:

1. **Parse** each `unsignedTransaction` (it's a JSON string inside the Action response)
2. **Increase gas** limit by 30% for safety margin
3. **Sign** with wallet skill (Bankr, Privy, or other)
4. **Submit** signed transaction:
   ```
   POST /v1/transactions/{txId}/submit
   { "signedTransaction": "0x..." }
   ```
5. **Poll** until confirmed:
   ```
   GET /v1/transactions/{txId}
   # Wait for status: "CONFIRMED"
   ```
6. **Repeat** for next transaction in the Action (increment nonce)

---

## Implementation Checklist

- [ ] API key in config.json (included by default)
- [ ] Scripts executable (`chmod +x scripts/*.sh`)
- [ ] `jq` and `curl` installed
- [ ] Wallet skill configured (Bankr, Privy, or other)
- [ ] Safety checks understood (see safety.md)
- [ ] Amounts formatted as raw integer strings
- [ ] Gas limit increased 30% before signing
- [ ] Sequential transactions use incremented nonces
- [ ] Transaction status polled until CONFIRMED
- [ ] unsignedTransaction parsed as JSON string before signing

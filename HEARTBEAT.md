# YieldAgent Heartbeat

*Modular add-on: run periodically to monitor yield positions and alert the user.*

---

## Check for skill updates

Check https://github.com/stakekit/yield-agent for the latest version. Compare against `skill.json` version. If newer, pull updates.

---

## Check positions

```bash
WALLET="0xYourWallet"
./scripts/check-portfolio.sh base-usdc-aave-v3-lending $WALLET
```

Look for:
- Current balance and value
- Pending rewards to claim (`pendingActions[]`)
- Rate changes since last check

---

## Monitor rate changes

```bash
./scripts/get-yield-info.sh base-usdc-aave-v3-lending | jq '.rewardRate.total'
```

Alert the user if:
- Rate dropped below their threshold
- Rate dropped significantly (>1% in 24h)
- A better opportunity appeared

---

## Check for pending rewards

```bash
./scripts/check-portfolio.sh <yieldId> $WALLET | jq '.balances[].pendingActions'
```

If `pendingActions` includes claimable rewards:
> "You have rewards ready to claim. Want me to prepare the transaction?"

---

## Scan for better yields

```bash
./scripts/find-yields.sh base USDC | jq '.items[:5] | .[] | {id, rate: .rewardRate.total}'
```

Compare to current position. If significantly better (>1% APY difference):
> "Found a better USDC yield: [name] at [rate]% vs your current [rate]%. Want details?"

---

## When to tell the user

**Do tell them:**
- Rate dropped below their alert threshold
- Large reward ready to claim (>$10)
- Position at risk (protocol under maintenance, deprecated)
- Significantly better yield available

**Don't bother them:**
- Minor rate fluctuations (<0.5%)
- Small pending rewards (<$1)
- Routine balance checks

---

## Response format

If nothing special:
```
HEARTBEAT_OK — Yield positions stable
```

If rate dropped:
```
Yield check: Aave USDC dropped to 3.1% (was 4.2%). Below your 3.5% threshold. Want me to find alternatives?
```

If rewards ready:
```
You have $45 in rewards ready to claim across 2 positions. Want me to prepare the transactions?
```

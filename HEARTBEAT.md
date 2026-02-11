# YieldAgent Heartbeat

Check for skill updates by comparing local version against remote.

## Setup

```bash
# Add to crontab — checks daily at midnight
(crontab -l 2>/dev/null; echo "0 0 * * * LOCAL=\$(jq -r .version ~/.openclaw/skills/yield-agent/skill.json) && REMOTE=\$(curl -s https://raw.githubusercontent.com/stakekit/yield-agent/main/skill.json | jq -r .version) && [ \"\$LOCAL\" != \"\$REMOTE\" ] && cd ~/.openclaw/skills/yield-agent && git pull origin main") | crontab -
```

## Manual check

```bash
LOCAL=$(jq -r .version ~/.openclaw/skills/yield-agent/skill.json)
REMOTE=$(curl -s https://raw.githubusercontent.com/stakekit/yield-agent/main/skill.json | jq -r .version)
echo "Local: $LOCAL  Remote: $REMOTE"
[ "$LOCAL" != "$REMOTE" ] && cd ~/.openclaw/skills/yield-agent && git pull origin main || echo "Up to date"
```

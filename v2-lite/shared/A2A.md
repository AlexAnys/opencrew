# A2A Protocol (v2 — Compact)

## Two-Step Trigger
Bot messages are self-ignored in Slack. Cross-agent collab needs:
1. Slack root message (visibility anchor)
2. sessions_send (actual trigger)

## Root Message Format
```
A2A <FROM> → <TO> | <Title> | TID:<YYYYMMDD-HHMM>-<tag>
```

## Session Key
```
agent:<target_id>:slack:channel:<channelId>:thread:<root_ts>
```

## Result & Sync
- Target agent works in thread (isolated session)
- Requesting agent syncs result to own channel
- If delivery fails: mark failed, retry once, escalate

## Anti-Loop (Config-Enforced)
- `agentToAgent.allow`: Only CoS, CTO can initiate
- `maxPingPongTurns`: 4 max
- Subagents: `deny: ["group:sessions"]`

## CoS Flexible Dispatch (v2)
- Architecture decisions → CTO → Builder (default path)
- Simple execution, no architecture decision needed → directly to Builder

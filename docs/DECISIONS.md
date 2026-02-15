# Decision Log (DECISIONS)

Purpose: record *why* we made key choices, so future iterations don’t accidentally erase the original intent.

Format (lightweight): Date · Decision · Context · Rationale · Alternatives

---

## 2026-02-15 · Ship “minimal incremental config snippet”, not full openclaw.json
- **Context**: Non-technical users often already have a working OpenClaw install (auth/models/gateway). Shipping a full config is high-risk.
- **Rationale**: Minimal incremental merge is safer and rollback-friendly.
- **Alternatives**: Provide a one-click setup script (rejected: higher blast radius, brittle paths).

## 2026-02-15 · Make shared/ reliable via symlink recommendation
- **Decision**: Recommend `~/.openclaw/workspace-<agent>/shared -> ~/.openclaw/shared`.
- **Context**: Shared docs are critical, but easy to drift if copied per-workspace.
- **Rationale**: Symlink avoids duplication; increases discoverability for agents/users.

## 2026-02-15 · Default KO/Ops requireMention = false; keep “enable later” guidance
- **Context**: First-time deploy should “just work” without @mentions.
- **Rationale**: Reduce false-negative “KO/Ops not responding” issues.
- **Alternative**: Default to requireMention=true for noise control (kept as optional recommendation).

## 2026-02-15 · Default heartbeat ON for CoS + KO (12h)
- **Context**: Proactive progress is a key OpenCrew promise; many users assume HEARTBEAT.md auto-runs.
- **Rationale**: Make the snippet explicitly enable heartbeat for the two maintenance/coordination roles.
- **Note**: OpenClaw heartbeat behavior changes once any agent has per-agent heartbeat configured.

## 2026-02-15 · Treat patches/ as advanced only
- **Context**: Slack thread routing/session isolation has edge cases; patching is risky for novices.
- **Rationale**: Document known issues; don’t require patches for default onboarding.

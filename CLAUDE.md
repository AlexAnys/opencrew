# OpenCrew — Project Context

> This file is local development context for Claude Code. Do NOT commit to the repo.

## Core Philosophy

OpenCrew is a multi-agent operating system where **agents are the primary operators, humans are strategic decision-makers**. Everything flows from three principles:

### 1. Minimize Human Intervention

Users should be able to quickly identify the absolute minimum manual steps, then delegate everything else.

**What MUST be human:**
- Creating platform apps/bots (Slack/Discord/Feishu) — requires browser auth, OAuth consent
- Granting privileged intents / permissions — platform-level human verification
- Providing credentials (tokens, secrets) — security boundary
- L3 decisions (irreversible: deploy, delete, trade) — Autonomy Ladder enforcement

**What agents handle:**
- Reading DEPLOY.md and executing deployment steps
- Copying workspace files, creating symlinks, directory structure
- Fetching channel/group IDs via API
- Merging config snippets into openclaw.json (incremental, bounded)
- Restarting gateway and verifying connectivity
- All L1/L2 operations (reversible work, impactful-but-rollbackable changes)

### 2. Agent-First Configuration

Remaining setup is done by Tool Agents — but with strict boundaries:

- **Incremental patches, not rewrites**: CONFIG_SNIPPET files define minimal additions to merge, never full config replacements. Agent must not touch auth/models/gateway sections.
- **Config enforces what docs can't**: A2A allowlist, maxPingPongTurns, subagent deny — all in openclaw.json, not just documentation. If a rule can be a config constraint, it must be.
- **Bounded tool use**: Agents modify specific config sections, not broad file rewrites. `rsync --ignore-existing` for workspace files, targeted JSON merges for config.

### 3. Reliable Instruction Following Across Models

Protocols are structured so different LLMs can follow them step-by-step:

- **SOUL.md first**: Identity anchors all decisions. Read before workflow.
- **Fixed read order**: SOUL → AGENTS → USER → MEMORY → shared protocols
- **Explicit state machines**: AGENTS.md specifies exact flowcharts (receive input → classify QAPS → branch), not fuzzy guidelines
- **Fixed-format templates**: Closeout, Checkpoint, Subagent Packet — all have mandatory fields, not suggestions
- **Numerical signals**: Signal score 0-3 in closeouts removes subjective judgment from KO filtering
- **Config > docs**: Hard constraints in openclaw.json trump soft constraints in .md files

## Document Audience Map

| Audience | Documents |
|----------|-----------|
| **Human only** | README, CONCEPTS, ARCHITECTURE, FAQ, KNOWN_ISSUES, JOURNEY, CUSTOMIZATION |
| **Agent only** | SOUL.md, AGENTS.md, USER.md, MEMORY.md, shared/*.md, AGENT_ONBOARDING |
| **Both (bridge)** | DEPLOY.md (human: prerequisites + credentials; agent: execution steps), GETTING_STARTED (human guide referencing agent-executable setup), CONFIG_SNIPPET_*.md (agent reads during deploy, human reviews) |
| **Human → Agent handoff** | Platform setup docs (SLACK_SETUP, DISCORD_SETUP, FEISHU_SETUP): human does platform-side steps, then hands credentials to agent for OpenClaw-side config |

## Architecture Quick Reference

```
Layer 1: Intent Alignment — YOU + CoS (strategic partner, not gateway)
Layer 2: Execution — CTO → Builder, CIO (swappable domain), Research (spawn-only)
Layer 3: Maintenance — KO (knowledge distillation), Ops (audit, governance)
```

- Channel = Role, Thread = Task
- Autonomy Ladder: L0 suggest → L1 reversible → L2 impactful → L3 irreversible
- Task types: Q (query) → A (artifact) → P (project) → S (system change)
- Knowledge pipeline: Raw chat → Closeout (25x compression) → KO extraction

## Working With This Repo

### What belongs in the repo
- Agent-facing protocols (shared/*.md, workspaces/*/SOUL.md etc.)
- Human-facing documentation (docs/*, README, DEPLOY)
- Platform setup guides and config snippets

### What does NOT belong in the repo
- `.claude/` (local Claude Code config and agents)
- `.harness/` (local development harness artifacts)
- `CLAUDE.md` (this file — local project context)
- Research reports, QA reports, architecture drafts (local harness outputs)

### When editing docs
- Platform setup instructions must be verified against official docs (Discord API, Feishu Open Platform, Slack API)
- Config keys must be verified against actual OpenClaw releases — never fabricate
- Update both Chinese and English versions
- Remember: setup docs are a human-agent bridge. Mark clearly which steps are human-manual vs agent-automated
- YAML/JSON examples in code blocks must use ASCII quotes, never typographic quotes

### When proposing architecture changes
- Distinguish config-layer constraints (reliable, system-enforced) from doc-layer constraints (soft, agent-voluntary)
- Favor pushing rules into openclaw.json over adding them to .md files
- Changes to shared/*.md affect ALL agents — review impact across roles
- v2-lite direction: fewer files, more config constraints, simpler protocols

## Active Context

- **Issues**: #31 (Feishu multi-agent), #33 (doc ordering), #34 (Discord routing) — addressed in PR #36
- **A2A Evolution**: Research completed on Slack/Feishu/Discord multi-bot capabilities. Architecture reports in local `.harness/reports/`. Key finding: Slack supports true multi-agent discussion NOW via multi-account + @mention; Feishu limited by platform (bot messages invisible to other bots); Discord blocked by OpenClaw #11199.
- **PR #36**: Documentation fixes only. Local harness/agent files stay local.

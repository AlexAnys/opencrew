[中文](../CONFIG_SNIPPET_FEISHU.md) | **English**

> 📖 [README](../../README.en.md) → [Feishu Setup](FEISHU_SETUP.md) → **Feishu Config Reference**

# OpenCrew Feishu Minimal Incremental Config

> Prerequisite: You already have OpenClaw installed locally and it runs successfully (you can execute `openclaw status`), and Feishu is already connected (you have completed the [Feishu Setup Guide](FEISHU_SETUP.md)).
>
> Principles:
> - We do **not** provide a "complete openclaw.json" (to avoid accidentally overwriting your `auth/models/gateway` settings)
> - We only provide the **minimal incremental changes**: new Agents + Feishu group bindings + A2A restrictions
> - Fully reversible: just remove the snippets we added and delete the new workspace directories

---

## Back up first (strongly recommended)

```bash
cp ~/.openclaw/openclaw.json ~/.openclaw/openclaw.json.bak.$(date +%Y%m%d-%H%M%S)
```

---

## Placeholders you need to prepare

- Feishu Group IDs (format: `oc_xxxxxxxxxxxxxxxx`):
  - `<FEISHU_GROUP_ID_HQ>` (HQ group → CoS)
  - `<FEISHU_GROUP_ID_CTO>` (Tech group → CTO)
  - `<FEISHU_GROUP_ID_BUILD>` (Execution group → Builder)
  - `<FEISHU_GROUP_ID_INVEST>` (Investment group → CIO, optional)
  - `<FEISHU_GROUP_ID_KNOW>` (Knowledge group → KO)
  - `<FEISHU_GROUP_ID_OPS>` (Operations group → Ops)
  - `<FEISHU_GROUP_ID_RESEARCH>` (Research group → Research, optional)

See [Feishu Setup Guide Step 6](FEISHU_SETUP.md#step-6-get-group-chat-ids-two-methods) for how to obtain them.

---

## Minimal incremental changes to add to `~/.openclaw/openclaw.json`

> Note: The snippets below assume you already have your own `openclaw.json`. You only need to **merge these new entries** into it.
>
> If you already have an agent with a conflicting id (e.g., you already have `cos` or `cto`), rename the new one to something unique (e.g., `crew-cos`) and update the bindings to match.

### A) New Agents (`agents.list`)

Append these agents to your existing `agents.list` (do not remove your original `main` agent):

```json
{
  "agents": {
    "list": [
      {
        "id": "cos",
        "name": "Chief of Staff",
        "workspace": "~/.openclaw/workspace-cos",
        "subagents": { "allowAgents": ["cos", "cto", "research", "ko", "builder"] },
        "heartbeat": { "every": "12h", "target": "feishu", "to": "group:<FEISHU_GROUP_ID_HQ>" }
      },
      {
        "id": "cto",
        "name": "CTO / Tech Partner",
        "workspace": "~/.openclaw/workspace-cto",
        "subagents": { "allowAgents": ["cto", "builder", "research", "ko"] }
      },
      {
        "id": "builder",
        "name": "Builder / Executor",
        "workspace": "~/.openclaw/workspace-builder",
        "subagents": { "allowAgents": ["builder"] }
      },
      {
        "id": "cio",
        "name": "CIO / Domain Specialist (Optional)",
        "workspace": "~/.openclaw/workspace-cio",
        "subagents": { "allowAgents": ["cio", "research", "ko"] }
      },
      {
        "id": "ko",
        "name": "Knowledge Officer",
        "workspace": "~/.openclaw/workspace-ko",
        "subagents": { "allowAgents": ["ko"] },
        "heartbeat": { "every": "12h", "target": "feishu", "to": "group:<FEISHU_GROUP_ID_KNOW>" }
      },
      {
        "id": "ops",
        "name": "Operations / Governance",
        "workspace": "~/.openclaw/workspace-ops",
        "subagents": { "allowAgents": ["ops", "ko"] }
      },
      {
        "id": "research",
        "name": "Research Worker (Spawn-only)",
        "workspace": "~/.openclaw/workspace-research",
        "subagents": { "allowAgents": [] }
      }
    ]
  }
}
```

### B) A2A / Sub-agent protection (`tools` + `session`)

```json
{
  "tools": {
    "agentToAgent": { "enabled": true, "allow": ["cos", "cto", "ops"] },
    "subagents": { "tools": { "deny": ["group:sessions"] } }
  },
  "session": {
    "agentToAgent": { "maxPingPongTurns": 4 }
  }
}
```

### C) Feishu group bindings (`bindings`)

```json
{
  "bindings": [
    { "agentId": "cos", "match": { "channel": "feishu", "peer": { "kind": "group", "id": "<FEISHU_GROUP_ID_HQ>" } } },
    { "agentId": "cto", "match": { "channel": "feishu", "peer": { "kind": "group", "id": "<FEISHU_GROUP_ID_CTO>" } } },
    { "agentId": "builder", "match": { "channel": "feishu", "peer": { "kind": "group", "id": "<FEISHU_GROUP_ID_BUILD>" } } },
    { "agentId": "cio", "match": { "channel": "feishu", "peer": { "kind": "group", "id": "<FEISHU_GROUP_ID_INVEST>" } } },
    { "agentId": "ko", "match": { "channel": "feishu", "peer": { "kind": "group", "id": "<FEISHU_GROUP_ID_KNOW>" } } },
    { "agentId": "ops", "match": { "channel": "feishu", "peer": { "kind": "group", "id": "<FEISHU_GROUP_ID_OPS>" } } },
    { "agentId": "research", "match": { "channel": "feishu", "peer": { "kind": "group", "id": "<FEISHU_GROUP_ID_RESEARCH>" } } }
  ]
}
```

### D) Feishu allowlist (`channels.feishu`)

> **Note**: The OpenClaw plugin for Feishu does not currently support thread (topic) isolation. All conversations within the same group are flat -- you cannot isolate different tasks by thread. See [Feishu Setup Guide -- Thread Limitations](FEISHU_SETUP.md#key-differences-from-slack-thread-topics) for details.

```json
{
  "channels": {
    "feishu": {
      "groups": {
        "<FEISHU_GROUP_ID_HQ>": { "allow": true, "requireMention": false },
        "<FEISHU_GROUP_ID_CTO>": { "allow": true, "requireMention": false },
        "<FEISHU_GROUP_ID_BUILD>": { "allow": true, "requireMention": false },
        "<FEISHU_GROUP_ID_INVEST>": { "allow": true, "requireMention": false },
        "<FEISHU_GROUP_ID_KNOW>": { "allow": true, "requireMention": false },
        "<FEISHU_GROUP_ID_OPS>": { "allow": true, "requireMention": false },
        "<FEISHU_GROUP_ID_RESEARCH>": { "allow": true, "requireMention": false }
      }
    }
  }
}
```

### Optional: Enable @mention gate (noise reduction -- recommended after you have everything working)

The open-source defaults set the knowledge group and ops group to `requireMention: false` to make sure things work out of the box.

If you want those groups to be quieter (only responding when you explicitly @mention the bot), change these two entries to `true`:

```json
{
  "channels": {
    "feishu": {
      "groups": {
        "<FEISHU_GROUP_ID_KNOW>": { "allow": true, "requireMention": true },
        "<FEISHU_GROUP_ID_OPS>": { "allow": true, "requireMention": true }
      }
    }
  }
}
```

### E) Heartbeat (recommended -- this snippet already enables it for CoS and KO)

A common misconception is that having a `HEARTBEAT.md` file is enough to run heartbeats. In reality, **heartbeat behavior is controlled by `openclaw.json`**.

In the `agents.list` example above, we already added heartbeat config for `cos` and `ko`:
- `heartbeat.every = "12h"` (roughly twice a day)
- `heartbeat.target = "feishu"` + `to = "group:<...>"`

> Important rule (from the OpenClaw docs):
> If **any** agent in `agents.list[]` has a `heartbeat` block, then **only** agents with an explicit `heartbeat` block will run heartbeats.
> This means: if you previously relied on `agents.defaults.heartbeat` for a "global heartbeat", introducing per-agent heartbeat configs will change that behavior.

If you do not want CoS/KO to run heartbeats, simply remove the `heartbeat` block from those two agent entries.

To check whether heartbeats are running:

```bash
openclaw system heartbeat last
# Manually enable/disable as needed
openclaw system heartbeat enable
openclaw system heartbeat disable
```

### F) Prepare workspace directories (strongly recommended)

OpenCrew workflows use several subdirectories (for daily memory, KO inbox/knowledge, CTO scars/patterns). Create them ahead of time -- this will not affect your existing configuration:

```bash
mkdir -p ~/.openclaw/workspace-{cos,cto,builder,cio,ko,ops,research}/memory
mkdir -p ~/.openclaw/workspace-ko/{inbox,knowledge}
mkdir -p ~/.openclaw/workspace-cto/{scars,patterns}
```

---

## After applying: restart and verify

```bash
openclaw gateway restart
openclaw status
```

Verification checklist:
1. Send a message @mentioning the bot in the tech group -- the CTO agent should respond
2. Have CTO delegate a task to Builder -- Builder should reply in the execution group

---

## How to roll back (important)

1. Restore from backup:

```bash
cp ~/.openclaw/openclaw.json.bak.<timestamp> ~/.openclaw/openclaw.json
openclaw gateway restart
```

2. Or roll back manually:
- Remove the following entries that this snippet added to `openclaw.json`:
  - The new OpenCrew agents in `agents.list`
  - The new `bindings` entries
  - The `channels.feishu.groups` allowlist entries
  - The `tools.agentToAgent` / `session.agentToAgent` additions
- (Optional) Delete the new workspace directories: `~/.openclaw/workspace-{cos,cto,builder,cio,ko,ops,research}`

[中文](../CONFIG_SNIPPET_DISCORD.md) | **English**

> 📖 [README](../../README.en.md) → [Discord Setup](DISCORD_SETUP.md) → **Discord Config Reference**

# OpenCrew Discord Minimal Incremental Config

> Applies to: You already have OpenClaw installed locally and it runs successfully (you can execute `openclaw status`), and Discord is connected (you have completed the [Discord Setup Guide](DISCORD_SETUP.md)).
>
> Principles:
> - We do **not** provide a "complete openclaw.json" (to avoid accidentally overwriting your `auth/models/gateway` settings)
> - We only provide the **minimal incremental changes**: new Agents + Discord channel bindings + A2A restrictions
> - Fully reversible: just remove the snippets we added and delete the new workspace directories

---

## Back up first (strongly recommended)

```bash
cp ~/.openclaw/openclaw.json ~/.openclaw/openclaw.json.bak.$(date +%Y%m%d-%H%M%S)
```

---

## Placeholders you need to prepare

- **Discord Guild ID** (server ID): `<DISCORD_GUILD_ID>`
- Discord Channel IDs:
  - `<DISCORD_CHANNEL_ID_HQ>` (#hq → CoS)
  - `<DISCORD_CHANNEL_ID_CTO>` (#cto → CTO)
  - `<DISCORD_CHANNEL_ID_BUILD>` (#build → Builder)
  - `<DISCORD_CHANNEL_ID_INVEST>` (#invest → CIO, optional)
  - `<DISCORD_CHANNEL_ID_KNOW>` (#know → KO)
  - `<DISCORD_CHANNEL_ID_OPS>` (#ops → Ops)
  - `<DISCORD_CHANNEL_ID_RESEARCH>` (#research → Research, optional)

See [Discord Setup Guide Step 6](DISCORD_SETUP.md#step-6-get-channel-ids-two-methods) for how to obtain them.

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
        "heartbeat": { "every": "12h", "target": "discord", "to": "channel:<DISCORD_CHANNEL_ID_HQ>" }
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
        "heartbeat": { "every": "12h", "target": "discord", "to": "channel:<DISCORD_CHANNEL_ID_KNOW>" }
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

### C) Discord channel bindings (`bindings`)

Discord uses a Guild ID + Channel ID routing model. Each binding assigns one Agent to one Discord channel:

```json
{
  "bindings": [
    { "agentId": "cos", "match": { "channel": "discord", "guildId": "<DISCORD_GUILD_ID>", "peer": { "kind": "channel", "id": "<DISCORD_CHANNEL_ID_HQ>" } } },
    { "agentId": "cto", "match": { "channel": "discord", "guildId": "<DISCORD_GUILD_ID>", "peer": { "kind": "channel", "id": "<DISCORD_CHANNEL_ID_CTO>" } } },
    { "agentId": "builder", "match": { "channel": "discord", "guildId": "<DISCORD_GUILD_ID>", "peer": { "kind": "channel", "id": "<DISCORD_CHANNEL_ID_BUILD>" } } },
    { "agentId": "cio", "match": { "channel": "discord", "guildId": "<DISCORD_GUILD_ID>", "peer": { "kind": "channel", "id": "<DISCORD_CHANNEL_ID_INVEST>" } } },
    { "agentId": "ko", "match": { "channel": "discord", "guildId": "<DISCORD_GUILD_ID>", "peer": { "kind": "channel", "id": "<DISCORD_CHANNEL_ID_KNOW>" } } },
    { "agentId": "ops", "match": { "channel": "discord", "guildId": "<DISCORD_GUILD_ID>", "peer": { "kind": "channel", "id": "<DISCORD_CHANNEL_ID_OPS>" } } },
    { "agentId": "research", "match": { "channel": "discord", "guildId": "<DISCORD_GUILD_ID>", "peer": { "kind": "channel", "id": "<DISCORD_CHANNEL_ID_RESEARCH>" } } }
  ]
}
```

### D) Discord allowlist + thread isolation (`channels.discord`)

Discord threads automatically inherit the configuration of their parent channel (agent binding, requireMention, etc.) unless you configure a specific thread ID separately.

```json
{
  "channels": {
    "discord": {
      "groupPolicy": "allowlist",
      "guilds": {
        "<DISCORD_GUILD_ID>": {
          "requireMention": false,
          "channels": {
            "<DISCORD_CHANNEL_ID_HQ>": { "allow": true },
            "<DISCORD_CHANNEL_ID_CTO>": { "allow": true },
            "<DISCORD_CHANNEL_ID_BUILD>": { "allow": true },
            "<DISCORD_CHANNEL_ID_INVEST>": { "allow": true },
            "<DISCORD_CHANNEL_ID_KNOW>": { "allow": true },
            "<DISCORD_CHANNEL_ID_OPS>": { "allow": true },
            "<DISCORD_CHANNEL_ID_RESEARCH>": { "allow": true }
          }
        }
      }
    }
  }
}
```

> **About bot appearance**: All Agents share the same Discord Bot avatar and display name. If you want different Agents to appear with different identities, you can use a webhook relay approach (advanced configuration -- see [openclaw-discord-spoof-avatar](https://github.com/Yvvvan/openclaw-discord-spoof-avatar)).

### Optional: Enable @mention gate (noise reduction -- recommended after you have everything working)

The open-source default sets `requireMention: false` to prioritize getting things working out of the box.

If you want certain channels to be quieter (only responding when @mentioned), set `requireMention: true` at the guild level or per channel:

```json
{
  "channels": {
    "discord": {
      "guilds": {
        "<DISCORD_GUILD_ID>": {
          "channels": {
            "<DISCORD_CHANNEL_ID_KNOW>": { "allow": true, "requireMention": true },
            "<DISCORD_CHANNEL_ID_OPS>": { "allow": true, "requireMention": true }
          }
        }
      }
    }
  }
}
```

### E) Heartbeat (recommended -- this snippet already enables it for CoS and KO)

A common misconception is that having a `HEARTBEAT.md` file is enough to run heartbeats. In reality, **heartbeat behavior is controlled by `openclaw.json`**.

In the `agents.list` example above, we already added heartbeat config for `cos` and `ko`:
- `heartbeat.every = "12h"` (roughly twice a day)
- `heartbeat.target = "discord"` + `to = "channel:<...>"`

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
1. Post a message in #cto -- the CTO agent should respond
2. Have CTO open a new thread in #build and delegate to Builder (a two-step A2A flow) -- Builder should reply within the thread

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
  - The `channels.discord.guilds` allowlist entries
  - The `tools.agentToAgent` / `session.agentToAgent` additions
- (Optional) Delete the new workspace directories: `~/.openclaw/workspace-{cos,cto,builder,cio,ko,ops,research}`

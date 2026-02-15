[中文](../CUSTOMIZATION.md) | **English**

# Customization Guide — Adding, Removing, and Modifying Agents

## Adding a New Domain Agent

Using CIO (Chief Investment Officer) as an example, here's how to add any domain expert Agent.

### Step 1: Create a Workspace Directory

```bash
mkdir -p ~/.openclaw/workspace-<your-agent-id>
```

### Step 2: Create Profile Files

You need at least 3 files:

**IDENTITY.md**
```markdown
# <Agent Name>
Emoji: <pick one>
One-liner: <One sentence describing what this role does>
```

**SOUL.md** (most important)
```markdown
# <Agent Name> — Role Directives

## Role
<What domain this Agent is responsible for>

## Core Principles
- <Principle 1>
- <Principle 2>

## Autonomy
- <What it can do on its own>
- <What requires confirmation (L3)>

## Spawn Capability
- Research (if research capability is needed)
```

**AGENTS.md**
```markdown
# <Agent Name> — Workflow

## Session Startup
1. Read SOUL.md
2. Read USER.md
3. Read MEMORY.md

## Task Processing
<Describe how this Agent processes tasks when received>

## Closeout
Use standard CLOSEOUT_TEMPLATE.
```

### Step 3: Modify openclaw.json

Add to `agents.list`:
```json
{
  "id": "<your-agent-id>",
  "name": "<Agent Display Name>",
  "workspace": "~/.openclaw/workspace-<your-agent-id>",
  "allowAgents": ["<your-agent-id>", "research", "ko"]
}
```

Add to `bindings`:
```json
{
  "agentId": "<your-agent-id>",
  "match": { "channel": "slack", "peer": { "kind": "channel", "id": "<YOUR_CHANNEL_ID>" } }
}
```

Add to `channels.slack.channels`:
```json
"<YOUR_CHANNEL_ID>": { "allow": true, "requireMention": false }
```

### Step 4: Restart OpenClaw

```bash
openclaw restart
```

---

## Removing an Agent

### Step 1: Remove from openclaw.json

- Remove the Agent entry from `agents.list`
- Remove the corresponding binding from `bindings`
- Remove the corresponding channel from `channels.slack.channels`
- Remove it from other Agents' `allowAgents` (if referenced)

### Step 2: Restart OpenClaw

The workspace directory can be kept (it won't affect the system) or deleted.

---

## Modifying Agent Behavior

### Change Role Positioning
Edit `workspace-<agent>/SOUL.md` — this is the highest-priority file.

### Change Workflow
Edit `workspace-<agent>/AGENTS.md` — task processing logic lives here.

### Change Long-Term Memory
Edit `workspace-<agent>/MEMORY.md` — stable preferences and principles.

### Change User Profile
Edit `workspace-<agent>/USER.md` — the Agent's understanding of you.

> Tip: You can also have your OpenClaw agent modify these files for you. Just tell it what you want to change, and it will edit the corresponding file.

---

## Minimum Viable Configuration

If 7 Agents is too many, the minimum viable version is **3**:

| Agent | Necessity |
|-------|-----------|
| CoS | Recommended — deep intent alignment + drives tasks on your behalf (not required, you can talk directly to CTO) |
| CTO | Required — tech direction and task breakdown |
| Builder | Required — actual execution |
| KO | Recommended — without knowledge distillation, experience doesn't accumulate |
| Ops | Recommended — without governance, the system will drift |
| Research | Optional — can be replaced with Spawn |
| CIO | Optional — add domain Agents as needed |

---

## Examples: Replacing CIO with Other Domains

### Legal Counsel
```markdown
# Legal — Role Directives
## Role
Legal risk assessment, contract review, compliance advisory.
## Autonomy
- Legal research, risk analysis, contract annotation
- Signing any legal documents, sending legal notices
```

### Head of Marketing
```markdown
# Marketing — Role Directives
## Role
Market analysis, content strategy, competitive research.
## Autonomy
- Market research, content drafts, data analysis
- Publishing content to public channels, running ad campaigns
```

### Product Manager
```markdown
# PM — Role Directives
## Role
Requirements analysis, product planning, user story writing.
## Autonomy
- Requirements documents, prioritization, prototype descriptions
- Publishing product roadmaps externally
```

The key pattern is the same: **L1/L2 proceed autonomously, L3 (irreversible / external-facing) requires confirmation**.

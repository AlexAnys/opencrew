[中文](../GETTING_STARTED.md) | **English**

> 📖 [README](../../README.en.md) → **Getting Started** → [Core Concepts](CONCEPTS.md) → [Architecture](ARCHITECTURE.md) → [Customization](CUSTOMIZATION.md)

# Getting Started — From Zero to Multi-Agent Collaboration

This is a complete step-by-step guide. If you just want the quick path, head back to the [README's 10-Minute Quickstart](../../README.en.md#10-minute-quickstart).

---

## Prerequisites Checklist

Before you begin, go through this checklist:

- [ ] **OpenClaw is installed and working**: Running `openclaw status` shows normal output
- [ ] **A messaging platform is ready**: Slack workspace, Discord server, or Feishu organization -- with admin permissions
- [ ] **Basic command-line skills**: You can copy-paste and run commands in a terminal (or have your existing OpenClaw agent do it for you)
- [ ] **Bot/App created on your platform**: You must create the bot/app FIRST, before connecting it to OpenClaw (see platform-specific guides below)

> Not sure how to install OpenClaw? See the [OpenClaw official docs](https://docs.openclaw.ai/)

### Correct Deployment Order

Follow these steps in order. The most common mistake is trying to configure OpenClaw bindings before the bot is fully set up on the messaging platform.

```
Manual (you do these on the platform):
  1. Create bot/app on your messaging platform (Discord/Slack/Feishu)
  2. Configure permissions and intents/scopes on the platform
  3. Invite the bot to your server/workspace/groups
  4. Create the agent channels/groups

Agent-automated (your OpenClaw agent handles these — see DEPLOY.md):
  5. Connect the platform to OpenClaw (openclaw channels add)
  6. Deploy OpenCrew files (shared protocols + workspaces)
  7. Write OpenClaw config (agent bindings, channel IDs)
  8. Restart the gateway (openclaw gateway restart)
  9. Verify (send test messages)
```

> Steps 5-9 can be fully automated by sending the deployment prompt in [DEPLOY.md](../../DEPLOY.en.md) to your existing OpenClaw agent.

### Platform-Specific Setup Guides

| Platform | Setup Guide | Time Estimate |
|----------|-------------|---------------|
| Slack | [SLACK_SETUP.md](SLACK_SETUP.md) | ~15 min |
| Discord | [DISCORD_SETUP.md](DISCORD_SETUP.md) | ~15 min |
| Feishu | [FEISHU_SETUP.md](FEISHU_SETUP.md) | ~20 min |

> **Tip**: Complete the platform-specific setup guide FIRST (Steps 1-4 above), then return here for Phase 2 onwards.

---

## Phase 1: Slack Setup (~20 minutes)

### 1.1 If You Haven't Connected Slack to OpenClaw Yet

Follow [SLACK_SETUP.md](SLACK_SETUP.md) to create a Slack App (Socket Mode) and obtain two tokens:

- `xapp-...` (App-Level Token)
- `xoxb-...` (Bot Token)

Then run:

```bash
openclaw channels add --channel slack --app-token "xapp-..." --bot-token "xoxb-..."
openclaw gateway restart
```

Verify: @mention your bot in any Slack channel. If it replies, you're good.

### 1.2 Create Agent Channels

Create the following channels in Slack. You can customize the names, but keep them short.

**Minimum setup (3 channels):**

| Channel | Agent | Purpose |
|---------|-------|---------|
| `#hq` | CoS (Chief of Staff) | Your primary conversation window. Strategic alignment. |
| `#cto` | CTO (Technical Co-founder) | Technical direction and task breakdown |
| `#build` | Builder (Executor) | Implementation and delivery |

**Recommended additions (add as needed):**

| Channel | Agent | When to Add |
|---------|-------|-------------|
| `#invest` | CIO (Domain Expert) | When you need specialized roles for investment, legal, marketing, etc. |
| `#know` | KO (Knowledge Officer) | When lessons keep getting lost and you keep making the same mistakes |
| `#ops` | Ops (Operations Officer) | When agent behavior starts drifting off course |
| `#research` | Research (Researcher) | When you need on-demand research tasks |

### 1.3 Invite the Bot and Record Channel IDs

```
1. In each channel, type: /invite @your-bot-name
2. Record each channel's Channel ID:
   Right-click the channel name → View channel details → Channel ID at the bottom (starts with C)
```

> All channels should be **public** — in a single-user workspace there are no privacy concerns, and public channels make auditing and tracking easier.

---

## Phase 2: Deploy OpenCrew Files (~10 minutes)

### 2.1 Copy Shared Protocols + Workspace Files

**Method A: Have your existing OpenClaw agent deploy for you (recommended, zero command-line)**

Send the following message to your existing OpenClaw agent:

```
I want to deploy OpenCrew. Please do the following:

1) Back up ~/.openclaw/openclaw.json (with a timestamp)
2) Copy all .md files from <repo-path>/shared/ to ~/.openclaw/shared/
3) For the cos, cto, and builder agents (minimum setup):
   - Create the ~/.openclaw/workspace-<agent>/memory/ directory
   - Copy files from <repo-path>/workspaces/<agent>/ into it (don't overwrite existing files)
   - Create a symlink: ~/.openclaw/workspace-<agent>/shared → ~/.openclaw/shared
4) Tell me what you did at each step

Boundaries: Do NOT touch my models/auth/gateway configs — only add the OpenCrew increments.
```

**Method B: Manual setup**

```bash
# 0. Back up
cp ~/.openclaw/openclaw.json ~/.openclaw/openclaw.json.bak-$(date +%Y%m%d%H%M)

# 1. Copy global protocols
mkdir -p ~/.openclaw/shared
cp shared/*.md ~/.openclaw/shared/

# 2. Copy workspaces (minimum 3 agents)
for a in cos cto builder; do
  mkdir -p ~/.openclaw/workspace-$a/memory
  rsync -a --ignore-existing "workspaces/$a/" "$HOME/.openclaw/workspace-$a/"
done

# 3. Symlink shared (so agents can read global protocols)
for a in cos cto builder; do
  if [ ! -e "$HOME/.openclaw/workspace-$a/shared" ]; then
    ln -s "$HOME/.openclaw/shared" "$HOME/.openclaw/workspace-$a/shared"
  fi
done

# 4. Verify
ls ~/.openclaw/workspace-cto/SOUL.md && echo "✅ workspace ready"
ls ~/.openclaw/shared/SYSTEM_RULES.md && echo "✅ shared protocols ready"
```

### 2.2 Deploying All 7 Agents

Replace `for a in cos cto builder` with `for a in cos cto builder cio ko ops research`, and also run:

```bash
# Special subdirectories for KO and CIO
mkdir -p ~/.openclaw/workspace-ko/{inbox,knowledge}
mkdir -p ~/.openclaw/workspace-cto/{scars,patterns}
mkdir -p ~/.openclaw/workspace-cio/{decisions,principles,signals,watchlist}
```

---

## Phase 3: Write the Configuration (~5 minutes)

### 3.1 Merge the Minimum Incremental Config

Follow [CONFIG_SNIPPET_2026.2.9.md](CONFIG_SNIPPET_2026.2.9.md). It includes:

- New `agents` entries (IDs, workspace paths)
- Slack channel bindings (Channel ID to Agent)
- Slack allowlist (only these channels trigger agents)
- A2A safeguards (maxPingPongTurns, initiation permissions, subagent limits)

**Key config items explained** (so you understand what each one does):

| Config Item | Purpose | Why It's Needed |
|-------------|---------|-----------------|
| `agents.list` | Registers each agent's ID and workspace | Without this, the agent doesn't exist |
| `bindings` | Maps Channel ID to Agent | Without this, messages in channels won't be routed to agents |
| `channels.slack.channels.allowlist` | Only allows specified channels to trigger agents | Prevents the bot from being accidentally triggered in other channels |
| `maxPingPongTurns = 4` | Caps A2A back-and-forth | Prevents two agents from triggering each other in a message storm |
| `tools.agentToAgent.allow` | Only CoS/CTO/Ops can initiate A2A | Organizational discipline — not everyone can dispatch tasks |
| `thread.historyScope = "thread"` | Isolates history within threads | Keeps each task's context separate |
| `replyToMode = "all"` | All replies go into threads | Keeps channels clean and uncluttered |

### 3.2 Token Security

**Important**: Do not hardcode Slack tokens in config files.

Recommended approach:
- **Local development**: Use a `~/.openclaw/.env` file (permissions set to 600)
- **Production**: Use Bitwarden Secrets Manager or an equivalent tool

```bash
# Create .env
touch ~/.openclaw/.env
chmod 600 ~/.openclaw/.env

# Write tokens (replace with your actual values)
echo 'SLACK_APP_TOKEN=xapp-1-your-token' >> ~/.openclaw/.env
echo 'SLACK_BOT_TOKEN=xoxb-your-token' >> ~/.openclaw/.env
```

### 3.3 Restart

```bash
openclaw gateway restart
openclaw status
```

---

## Phase 4: Verification (~5 minutes)

### Basic Verification

```
Test 1: Send a message in #hq → CoS replies → ✅
Test 2: Send a message in #cto → CTO replies → ✅
Test 3: In #cto, ask CTO to dispatch a task to Builder
        → A thread appears in #build → Builder replies in the thread → ✅
```

### A2A Verification (already covered if Test 3 passed)

In `#cto`, tell the CTO: "Have Builder write a hello world script." Watch for:

1. CTO creates a root message in `#build` (the A2A anchor)
2. Builder replies and executes within that thread
3. CTO syncs Builder's progress back in `#cto`

If all of the above works, congratulations — your multi-agent system is up and running! 🎉

---

## Troubleshooting

### Bot Not Responding

| Check | Command |
|-------|---------|
| Is the gateway online? | `openclaw gateway status` |
| Is the bot invited to the channel? | Check the channel's member list |
| Is the Channel ID correct? | Compare the ID in your config with the one in Slack |
| requireMention setting | `#ops` requires @mention by default |

### not_in_channel Error

The bot hasn't been invited to the target channel. Run `/invite @your-bot-name` in the channel.

### Target Agent Doesn't Reply After A2A Dispatch

This is a known issue ([KNOWN_ISSUES.md](KNOWN_ISSUES.md) P1). Current best practices:

1. Confirm the target agent's channel ID and binding are correct
2. Check that `sessions_send`'s sessionKey includes the correct thread ts
3. If it happens intermittently, the agent usually recovers on the next message

### Variable Expansion Issues in zsh

In zsh, `$variable` inside double quotes gets expanded. Use single quotes around arguments containing `$`.

### Permission Denied

```bash
# Check directory permissions
ls -la ~/.openclaw/
# Fix
sudo chown -R $USER:$USER ~/.openclaw/
```

---

## Common Mistakes

These are the most frequently reported issues from new users:

### 1. Wrong deployment order

**Mistake**: Trying to run `openclaw channels add` or configure bindings before creating the bot on the messaging platform.

**Fix**: Always create and configure the bot/app on your messaging platform first. See [Correct Deployment Order](#correct-deployment-order) above.

### 2. Skipping channel permission isolation (Discord)

**Mistake**: Using a single bot with default permissions, allowing it to send messages in any channel. This causes agent conversations to mix (Issue #34).

**Fix**: Follow the [Channel Permission Isolation](DISCORD_SETUP.md#step-5b-configure-channel-permission-isolation-important) steps in the Discord setup guide.

### 3. Forgetting to restart the gateway

**Mistake**: Changing config or bindings but not restarting. Changes do not take effect until restart.

**Fix**: Always run `openclaw gateway restart` after config changes, then verify with `openclaw status`.

### 4. Channel ID mismatch

**Mistake**: Copying the wrong Channel ID or mixing up IDs between channels.

**Fix**: Double-check each Channel ID against your messaging platform. Use `openclaw channels resolve` to verify.

### 5. Bot not invited to channels

**Mistake**: Creating channels but forgetting to invite the bot (Slack) or add the bot role (Discord).

**Fix**: In Slack, run `/invite @bot-name` in each channel. In Discord, ensure the bot role has View Channel permission. In Feishu, add the bot via group settings.

---

## Quick Reference: Common Commands

```bash
# System status
openclaw status
openclaw gateway status
openclaw gateway restart

# Agent management
openclaw agents list

# Config queries
openclaw config get agents
openclaw config get slack.channels

# Logs
openclaw logs tail -f
```

---

## What to Do After Deployment

1. **Run with 3 agents for a few days** — get a feel for the collaboration rhythm
2. **Watch for Closeout output** — are CTO and Builder writing structured summaries?
3. **Add KO/Ops as needed** — when you notice lessons getting lost or agent behavior drifting
4. **Read [Core Concepts](CONCEPTS.md)** — understand the system's operating logic in depth
5. **Read [Development Journey](JOURNEY.md)** — learn the "why" behind each design decision

---

> 📖 Next → [Core Concepts](CONCEPTS.md) · [Architecture](ARCHITECTURE.md) · [Customize Your Agents](CUSTOMIZATION.md)

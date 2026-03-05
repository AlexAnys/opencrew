[中文](../DISCORD_SETUP.md) | **English**

> 📖 [README](../../README.en.md) → [Getting Started](GETTING_STARTED.md) → **Discord Setup**

# Discord Setup

> Goal: Connect OpenClaw with **a single Discord Bot**, then use a "channel = role" binding for each Agent. Adding or removing Agents later is just a matter of adding/removing channels and updating bindings.

OpenCrew uses the Discord **Gateway** (WebSocket connection) -- no public server required.

---

## What you will have when you are done

After completing these steps you will have:
- One Discord Application (with a bot)
- A **Bot Token** (`MTxxx...`)
- OpenClaw connected to Discord, with the bot in your server

---

## Step 1: Create a Discord application and bot (~5 min)

1. Go to [Discord Developer Portal](https://discord.com/developers/applications) → **New Application**
2. Enter an app name (e.g. "OpenCrew") → agree to terms → **Create**
3. In the left sidebar, click **Bot**
4. Click **Reset Token** → confirm → **copy the Bot Token** and store it securely

> The Bot Token is only shown once. If lost, you will need to reset it again.

---

## Step 2: Enable Privileged Intents (critical!)

Still on the **Bot** page, scroll down to **Privileged Gateway Intents** and enable:

| Intent | Purpose |
|--------|---------|
| **Server Members Intent** | Track member joins/leaves |
| **Presence Intent** | Online status (optional) |
| **Message Content Intent** | **Must enable** -- without this, the bot cannot read message content |

Click **Save Changes**.

> Bots in fewer than 100 servers do not need review -- just toggle and save.

---

## Step 3: Invite the bot to your server (~3 min)

### 3a. Generate the invite URL

Left sidebar → **OAuth2** → **URL Generator**:

1. **Scopes**: check `bot` and `applications.commands`
2. **Bot Permissions**: check the following:

| Permission | Purpose |
|------------|---------|
| View Channels | See channels |
| Send Messages | Send messages in channels |
| Send Messages in Threads | Post inside threads |
| Create Public Threads | Start public threads |
| Create Private Threads | Start private threads |
| Manage Threads | Archive/lock threads |
| Read Message History | Read past messages |
| Manage Channels | Create/manage channels |
| Add Reactions | React to messages |
| Mention Everyone | Use @mentions |

3. Copy the generated **URL** at the bottom

### 3b. Authorize

1. Open the copied URL in your browser
2. Select your Discord server
3. Confirm permissions → complete the CAPTCHA
4. The bot appears in the server member list (shows offline until connected)

---

## Step 4: Connect Discord to OpenClaw

Run in your terminal:

```bash
openclaw channels add --channel discord \
  --bot-token "your_bot_token"
```

> You can also use the interactive method: `openclaw channels add`, select Discord, and paste the token when prompted.

Then restart the gateway:

```bash
openclaw gateway restart
```

Verify that Discord is online:

```bash
openclaw channels status --probe
# or
openclaw status
```

The bot should appear as "Online" in Discord.

---

## Step 5: Create OpenCrew channels

In your Discord server, create channels:

**Minimum setup (3 channels, recommended starting point):**
- `#hq` (CoS -- Chief of Staff)
- `#cto` (CTO -- Tech Partner)
- `#build` (Builder -- Executor)

**Optional extras:**
- `#invest` (CIO -- Domain Expert)
- `#know` (KO -- Knowledge Officer)
- `#ops` (Ops -- Governance)
- `#research` (Research -- On-demand)

> We recommend creating a **channel category** (e.g. "AI Agents") to group all agent channels together.

Make sure the bot has "View Channel" and "Send Messages" permissions in each channel (usually automatic if the bot has Manage Channels permission).

---

## Step 6: Get Channel IDs (two methods)

### Method A (recommended): Enable Developer Mode and copy

1. Discord Settings → **Advanced** → enable **Developer Mode**
2. Right-click a channel name → **Copy Channel ID**

### Method B: Use OpenClaw to resolve

```bash
openclaw channels resolve --channel discord "#hq" --json
```

---

## Advanced: Bot Identity Options

By default, OpenCrew uses a single bot for all agents, with each agent distinguished by its channel. If you want different agents to appear with different names and avatars, Discord supports three approaches:

| Approach | Complexity | Agent Appearance | Slash Commands | Best For |
|----------|-----------|-----------------|----------------|----------|
| Single Bot (default) | Low | Uniform | Shared | Quick start |
| Webhook Relay | Medium | Different name/avatar | Not supported | Visual distinction |
| Multi-Bot | High | Fully independent | Independent | Full experience |

### Webhook Relay

A single bot receives and processes messages, but replies via channel webhooks with different names and avatars. Open-source implementations are available (e.g. [openclaw-discord-spoof-avatar](https://github.com/Yvvvan/openclaw-discord-spoof-avatar)).

Limitations: webhooks can only send (not receive), do not support slash commands, and have no online status indicator.

### Multi-Bot

Create a separate Discord Application for each agent. Each bot gets its own identity, slash commands, and rate limits.

Things to keep in mind:
- Each bot must be invited to the server individually
- Bots in more than 75 servers require a separate Message Content Intent approval
- OpenClaw multi-account support is still in development -- see [PR #3672](https://github.com/open-claw/open-claw/pull/3672)

> **Tip**: Discord servers allow up to 50 bots. OpenCrew's 7 agents are well within this limit. For most users, a single bot with channel routing is sufficient.

---

## FAQ

### Bot not responding to messages?

Most common cause: **Message Content Intent is not enabled**.

Go to [Developer Portal](https://discord.com/developers/applications) → your app → Bot → confirm **Message Content Intent** is on → Save Changes → restart gateway.

### Bot shows offline in the server?

1. **Is the gateway running?** `openclaw gateway status`
2. **Is the token correct?** Double-check the Bot Token
3. **Check logs**: `openclaw logs --follow`

### How do threads work?

Discord threads map to OpenCrew's "task/session" concept. Agents automatically create threads in channels when starting tasks.

Threads auto-archive after a period of inactivity (1 day / 3 days / 7 days). Archived threads can still be viewed and reopened.

### One bot or multiple bots?

OpenCrew defaults to **one bot** for all agents (same model as Slack). If you need different agents to have distinct appearances, see [Advanced: Bot Identity Options](#advanced-bot-identity-options) above.

### Do I need a VPS / public server?

No. The Discord Gateway uses an outbound WebSocket connection -- your computer connects directly to Discord's servers with no public IP required.

---

## Reference

- [Discord Developer Portal](https://discord.com/developers/applications)
- [Discord Bot official docs](https://discord.com/developers/docs/quick-start/getting-started)
- [OpenClaw Discord integration docs](https://docs.openclaw.ai/channels/discord)

---

> 📖 Next → [Getting Started](GETTING_STARTED.md) · [Discord Config Reference](CONFIG_SNIPPET_DISCORD.md)

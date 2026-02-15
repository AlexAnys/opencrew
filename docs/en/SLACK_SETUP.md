[中文](../SLACK_SETUP.md) | **English**

# Slack Setup

> Goal: Connect OpenClaw with **a single Slack App**, then use a "channel = role" binding for each Agent. Adding or removing Agents later is just a matter of adding/removing channels and updating bindings.

OpenCrew uses Slack **Socket Mode** by default -- no public webhook required.

---

## What you will have when you are done

After completing these steps you will have:
- One Slack App (with one bot)
- Two tokens:
  - **App Token**: `xapp-...` (required for Socket Mode)
  - **Bot Token**: `xoxb-...`
- OpenClaw connected to Slack, with the bot invited to every channel you want to use

---

## Step 1: Create a Slack App and enable Socket Mode

1. Go to https://api.slack.com/apps and click **Create New App** (From scratch)
2. Navigate to **Socket Mode** and enable it
3. Go to **Basic Information** then **App-Level Tokens** and click Generate Token and Scopes
   - Add the scope: `connections:write`
   - Generate and copy the **App Token** (`xapp-...`)

---

## Step 2: Configure bot permissions (Scopes) and install to your Workspace

Under **OAuth & Permissions**, add the following Bot Token Scopes (the minimum set recommended by OpenClaw):

- `chat:write`
- `im:write`
- `channels:history`, `groups:history`, `im:history`, `mpim:history`
- `channels:read`, `groups:read`, `im:read`, `mpim:read`
- `users:read`
- `reactions:read`, `reactions:write`
- `pins:read`, `pins:write`
- `emoji:read`
- `files:write`

Then click **Install to Workspace** and copy the **Bot User OAuth Token** (`xoxb-...`).

---

## Step 3: Enable Event Subscriptions

Go to **Event Subscriptions** and enable events. Subscribe to the following (as recommended in the OpenClaw docs):

- `message.*` (includes edits, deletes, and thread broadcasts)
- `app_mention`
- `reaction_added`, `reaction_removed`
- `member_joined_channel`, `member_left_channel`
- `channel_rename`
- `pin_added`, `pin_removed`

---

## Step 4: Connect your Slack account to OpenClaw (CLI recommended)

Run the following in your terminal (replace the tokens with your own):

```bash
openclaw channels add --channel slack \
  --app-token "xapp-..." \
  --bot-token "xoxb-..."
```

> This writes the Slack configuration into `~/.openclaw/openclaw.json` (more reliable than editing by hand).

Then restart the gateway:

```bash
openclaw gateway restart
```

Verify that Slack is online:

```bash
openclaw channels status --probe
# or
openclaw status
```

---

## Step 5: Create OpenCrew channels and invite the bot

We recommend creating 7 channels to start (names are up to you):
- #hq (CoS)
- #cto (CTO)
- #build (Builder)
- #invest (CIO, optional)
- #know (KO)
- #ops (Ops)
- #research (Research, optional)

Then, in each channel, run `/invite @<your-bot-name>`.

> If the bot is not in a channel it usually cannot read history or post messages (unless you additionally grant `chat:write.public`, which is not recommended for beginners).

---

## Step 6: Get Channel IDs (two methods)

### Method A (easiest): Copy link in Slack
Right-click the channel name and select **Copy link**. The `C0XXXXXXXX` portion of the URL is the Channel ID.

### Method B (optional): Use OpenClaw to resolve

```bash
openclaw channels resolve --channel slack "#hq" --json
```

---

## Reference
- OpenClaw Slack documentation (bookmark this): `/opt/homebrew/lib/node_modules/openclaw/docs/zh-CN/channels/slack.md`

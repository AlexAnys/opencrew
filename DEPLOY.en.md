[中文](DEPLOY.md) | **English**

# Deploy Guide

> **This document is designed to be sent directly to your OpenClaw, which will execute the deployment for you.** For a full manual walkthrough (with detailed explanations, common errors, verification checklist), see → [Full Getting Started Guide](docs/en/GETTING_STARTED.md)
>
> Principle: **No "one-click scripts"**, no "complete openclaw.json" handed to you. Use minimal increments + rollback-friendly steps to add OpenCrew into your existing OpenClaw.

---

## 0. Prerequisites (New Users: Follow This Order)

1. You can run OpenClaw normally (on your local machine)
   - You can run: `openclaw status`
2. You have a messaging platform (Slack / Feishu / Discord -- pick one)
3. You plan to use **one App/Bot** to manage all OpenCrew Agents (adding/removing Agents later is just adding/removing channels/groups + config bindings)

If you haven't connected a messaging platform to OpenClaw yet:
- Slack → [`docs/en/SLACK_SETUP.md`](docs/en/SLACK_SETUP.md)
- Feishu → [`docs/en/FEISHU_SETUP.md`](docs/en/FEISHU_SETUP.md)
- Discord → [`docs/en/DISCORD_SETUP.md`](docs/en/DISCORD_SETUP.md)

---

## 1. Create Channels / Groups (Roles)

Create the following channels or groups on your messaging platform (names are customizable):
- #hq / HQ group (CoS)
- #cto / Tech group (CTO)
- #build / Build group (Builder)
- #invest / Invest group (CIO -- optional, swap in your own domain)
- #know / Knowledge group (KO -- consider enabling requireMention to reduce noise; the open-source edition ships with it off by default, so get things running first)
- #ops / Ops group (Ops -- consider enabling requireMention to reduce noise; the open-source edition ships with it off by default, so get things running first)
- #research / Research group (Research -- optional, typically spawn-only)

Then invite the bot:
- Slack: `/invite @<bot>`
- Feishu: Group settings → Add bot
- Discord: Ensure the bot has access to each channel

---

## Execution Prompt for OpenClaw

> The following section is for the OpenClaw agent executing the deployment. If you're reading this as a human, you can skip ahead to Section 2.

When a user asks you to deploy OpenCrew, follow this process:

### Execution Steps

```
Step 1: Back up
  cp ~/.openclaw/openclaw.json ~/.openclaw/openclaw.json.bak.$(date +%s)

Step 2: Copy files (see "Method B" bash commands below, use as-is)
  - shared/*.md → ~/.openclaw/shared/
  - workspaces/<agent>/ → ~/.openclaw/workspace-<agent>/ (don't overwrite existing files)
  - Create symlink for each workspace: shared → ~/.openclaw/shared
  - Create subdirectories: memory/, ko/inbox, ko/knowledge, cto/scars, cto/patterns

Step 3: Fetch channel/group IDs
  Get IDs based on the user's platform:
  - Slack: User has provided the Bot Token. Use the Slack API to auto-fetch:
    curl -s -H "Authorization: Bearer <botToken>" \
      "https://slack.com/api/conversations.list?types=public_channel&limit=200"
    Match channels where is_member=true by name to get the Channel ID.
  - Feishu: Use openclaw channels resolve or get chat_id (oc_xxx format) from logs.
    See docs/en/FEISHU_SETUP.md Step 6.
  - Discord: Enable Developer Mode, right-click channels to copy IDs, or get from logs.
    See docs/en/DISCORD_SETUP.md Step 6.

Step 4: Write platform config
  Write credentials into the platform's channels config:
  - Slack: botToken + appToken → channels.slack (Socket Mode)
  - Feishu: appId + appSecret → channels.feishu
  - Discord: botToken → channels.discord

Step 5: Merge agent config
  Read the config reference matching the user's platform:
  - Slack → docs/en/CONFIG_SNIPPET_2026.2.9.md
  - Feishu → docs/en/CONFIG_SNIPPET_FEISHU.md
  - Discord → docs/en/CONFIG_SNIPPET_DISCORD.md
  Then merge these increments into openclaw.json:
  - agents.list (add new agent entries, preserve user's existing main agent)
  - bindings (channel/group → Agent mapping)
  - channels allowlist (allowlist + requireMention)
  - tools.agentToAgent + session.agentToAgent (A2A protection)

Step 6: Restart and verify
  openclaw gateway restart
  openclaw status (confirm agent count and platform connection status are correct)
```

### Boundaries (what NOT to do)

- **Do not modify** user's `models` / `auth` / `gateway` config
- **Do not delete** user's existing agents, bindings, or channels entries
- If there's a conflict (e.g., user already has an agent with the same id), stop and ask

---

## 2. Copy OpenCrew Files into Your `~/.openclaw/`

You have two options:

### Method A (Recommended): Let Your Existing OpenClaw Handle the Deployment

Send the following to your OpenClaw (replace `<>` with your values):

```
Deploy OpenCrew multi-agent team for me.

Repo: please clone https://github.com/AlexAnys/opencrew.git to /tmp/opencrew
(If already downloaded, repo path: <your local path>)

My platform: <Slack / Feishu / Discord> (pick one)

Platform credentials (write to config, do not echo back):
- Slack: Bot Token (xoxb-) + App Token (xapp-)
- Feishu: App ID (cli_xxx) + App Secret
- Discord: Bot Token

I've created these channels/groups and invited the bot:
- #hq / HQ group → CoS
- #cto / Tech group → CTO
- #build / Build group → Builder

Read DEPLOY.en.md in the repo and follow the deployment process.
Do not touch my models / auth / gateway config — only add the OpenCrew increments.
```

Your OpenClaw will read this file and the CONFIG_SNIPPET file for your platform, then automatically complete: backup, file copy, config merge, restart, and verification.

### Method B: Manual Copy (Transparent, but Requires Some Command Line)

```bash
mkdir -p ~/.openclaw/shared
cp shared/*.md ~/.openclaw/shared/

for a in cos cto builder cio ko ops research; do
  mkdir -p ~/.openclaw/workspace-$a
  rsync -a --ignore-existing "workspaces/$a/" "$HOME/.openclaw/workspace-$a/"
done

for a in cos cto builder cio ko ops research; do
  if [ ! -e "$HOME/.openclaw/workspace-$a/shared" ]; then
    ln -s "$HOME/.openclaw/shared" "$HOME/.openclaw/workspace-$a/shared"
  fi
done

mkdir -p ~/.openclaw/workspace-{cos,cto,builder,cio,ko,ops,research}/memory
mkdir -p ~/.openclaw/workspace-ko/{inbox,knowledge}
mkdir -p ~/.openclaw/workspace-cto/{scars,patterns}
```

> Note: We use `rsync --ignore-existing` to avoid overwriting workspace files you're already using.

---

## 3. Write the Minimal Incremental Config

Choose the config reference for your platform:
- **Slack** → [`docs/en/CONFIG_SNIPPET_2026.2.9.md`](docs/en/CONFIG_SNIPPET_2026.2.9.md)
- **Feishu** → [`docs/en/CONFIG_SNIPPET_FEISHU.md`](docs/en/CONFIG_SNIPPET_FEISHU.md)
- **Discord** → [`docs/en/CONFIG_SNIPPET_DISCORD.md`](docs/en/CONFIG_SNIPPET_DISCORD.md)

Each file covers:
- New agents to add (and their workspace paths)
- Platform channel/group bindings (channel = role)
- Platform allowlist (security: only these channels/groups can trigger agents)
- A2A safeguards (maxPingPongTurns / initiation permissions / subagent session restrictions)
- How to roll back

---

## 4. Restart and Verify

```bash
openclaw gateway restart
openclaw status
```

Verification checklist:
1) Send a message in #hq -- CoS responds
2) Send a message in #cto -- CTO responds
3) In #cto, ask CTO to dispatch an implementation task to Builder -- a thread appears in #build, and Builder replies within the thread

---

## 5. Optional: If You Don't Need CIO / Research

- Don't need CIO: Skip creating #invest, and don't add the CIO binding/allowlist/agent entries.
- Research is typically spawn-only: You can skip binding #research, or add it later when needed.

---

## Important Notes: About "One-Click Scripts" and the Slack Routing Patch

- This repo **does not provide and does not recommend** "one-click scripts that directly modify your system config" (everyone's install path and existing config are different -- too much risk). We recommend using your existing OpenClaw to do a rollback-friendly incremental deployment, step by step.
- Slack's "every root message auto-creates an independent session" behavior currently has no perfect config-level solution. Advanced users can refer to `patches/` (see [docs/en/KNOWN_ISSUES.md](docs/en/KNOWN_ISSUES.md)).

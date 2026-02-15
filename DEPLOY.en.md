[中文](DEPLOY.md) | **English**

# Deploy Guide (Conservative Edition) -- Let Your Existing OpenClaw Deploy OpenCrew for You

> Goal: **No "one-click scripts"**, no "complete openclaw.json" handed to you. Instead, use minimal increments + rollback-friendly steps to add OpenCrew into your existing OpenClaw.
>
> Default shape: **One `.openclaw`, one Gateway, multiple Agents, multiple workspaces** (similar to how your existing setup relates to multi-agent).

---

## 0. Prerequisites (New Users: Follow This Order)

1. You can run OpenClaw normally (on your local machine)
   - You can run: `openclaw status`
2. You have a Slack workspace
3. You plan to use **one Slack App** to manage all OpenCrew Agents (adding/removing Agents later is just adding/removing channels + config bindings)

If you haven't connected Slack to OpenClaw yet: complete [`docs/en/SLACK_SETUP.md`](docs/en/SLACK_SETUP.md) first.

---

## 1. Create Slack Channels (Roles)

We recommend starting with these 7 channels (names are customizable):
- #hq (CoS)
- #cto (CTO)
- #build (Builder)
- #invest (CIO -- optional, swap in your own domain)
- #know (KO -- consider enabling requireMention to reduce noise; the open-source edition ships with it off by default, so get things running first)
- #ops (Ops -- consider enabling requireMention to reduce noise; the open-source edition ships with it off by default, so get things running first)
- #research (Research -- optional, typically spawn-only)

Then invite the bot into each channel: `/invite @<bot>`.

---

## 2. Copy OpenCrew Files into Your `~/.openclaw/`

You have two options:

### Method A (Recommended): Let Your Existing OpenClaw Do the Copying

Send the following message to your OpenClaw (the agent you normally use):

```
I want to deploy OpenCrew (a multi-agent collaboration framework). Please execute the steps below on my local machine, and tell me what you did at each step:

1) Read the OpenCrew repo I downloaded (path: <fill in your local path>)
2) Back up ~/.openclaw/openclaw.json (with a timestamp)
3) Copy shared/*.md from the repo into ~/.openclaw/shared/
4) Copy workspaces/<agent>/*.md from the repo into ~/.openclaw/workspace-<agent>/
   - Create the directory if it doesn't exist
   - Do NOT overwrite any of my existing files with the same name; if there's a conflict, stop and ask me
   - (Recommended) Create a symlink for each workspace: ~/.openclaw/workspace-<agent>/shared -> ~/.openclaw/shared (skip if it already exists)
5) Remind me to provide my Slack Channel IDs, then merge the minimal increment into ~/.openclaw/openclaw.json following docs/en/CONFIG_SNIPPET_2026.2.9.md
6) Restart the openclaw gateway and verify that #cto / #hq respond normally

Boundaries: Do NOT touch my models/auth/gateway configs -- only add the OpenCrew increments.
```

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

## 3. Write the Minimal Incremental Config (OpenClaw 2026.2.9)

Follow this document: [`docs/en/CONFIG_SNIPPET_2026.2.9.md`](docs/en/CONFIG_SNIPPET_2026.2.9.md)

It covers:
- New agents to add (and their workspace paths)
- Slack channel bindings (channel = role)
- Slack allowlist (security: only these channels can trigger agents)
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

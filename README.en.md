[中文](README.md) | **English**

# OpenCrew

> A multi-agent operating system for decision-makers.
> Turn your OpenClaw into a manageable AI team — domain experts each own their lane, experience auto-distills.
> Supports **Slack** · **Feishu** · **Discord** — pick the platform your team already uses.
>
> 🤖 **Agent-Ready Deployment** — Docs are structured and battle-tested for autonomous agent execution. Your OpenClaw reads the repo and deploys for you — minimal manual steps required.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Built on OpenClaw](https://img.shields.io/badge/Built_on-OpenClaw-purple)](https://github.com/openclaw/openclaw)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](docs/CONTRIBUTING.md)

---

## 📢 Status Update (April 2026)

### A2A v2: The Best Way for Agents to Collaborate

We've resolved the biggest architectural limitation since OpenCrew's inception: **Agents can now truly collaborate** — not just dispatch tasks one-way, but discuss, review, and iterate like real colleagues.

**Before**: All Agents share one Slack bot → bot can't trigger itself → Agents could only delegate via `sessions_send`, no discussion possible.

**Now**: Create an independent Slack App for at least one key Agent → invite it into any execution Agent's channel → high-level dialogue in channels + file-based real work + user reviews the final output.

<table>
<tr>
<td width="50%"><img src="docs/OpenCrew-A2A-V2.svg" alt="A2A v2 Architecture"><br><sub><b>Architecture</b>: Orchestrator (independent App) enters execution Agent channels to collaborate</sub></td>
<td width="50%"><img src="assets/screenshots/a2a-v2-discussion-demo.png" alt="A2A v2 In Action"><br><sub><b>In action</b>: Two Agents collaborating in #ops to investigate an issue (zero human intervention)</sub></td>
</tr>
</table>

**Which Agents should be independent?** Pick at least one — add more as needed. Drawing from [Anthropic Harness Design](https://www.anthropic.com/engineering/harness-design-long-running-apps), high-value independent roles include:

| Role | Responsibility | Why Independent? |
|------|---------------|-----------------|
| **CoS (Chief of Staff)** | Represents user intent, drives tasks forward | Needs to enter different Agent channels to ensure alignment with user goals |
| **Planner / Coordinator** | Expands requirements into acceptance criteria, controls pace | Must interact with multiple execution Agents; planning can't be self-served |
| **QA / Evaluator** | Independent quality review | An AI that both executes and self-reviews tends to be lenient on itself — QC must be separated |

> Minimum: pick **one** Agent as an independent App (covering the above roles), and you're ready to collaborate.

**Setup in three steps**: Create an independent Slack App → configure multi-account → invite the bot into target channels. Details → [Discussion Mode Setup Guide](docs/A2A_SETUP_GUIDE.md)

> **Model compatibility**: Collaboration discipline (@mention checking, round counting, NO_REPLY) relies on prompt rules, not system enforcement. Tested stable with Claude Opus 4.6. For other models, test in a low-risk channel first. Details → [Known Limitations](shared/A2A_PROTOCOL.md#7-已知限制)

> Technical details → [A2A Protocol v2](shared/A2A_PROTOCOL.md) · [Core Concepts](docs/en/CONCEPTS.md#4-a2a--native-agent-collaboration)

### Coming Next: Agent Blueprints — On-Demand Agent Onboarding

The author has onboarded ~10 new Agents through the OpenCrew framework for various tasks. An **Agent Blueprint repository** is in development — in the future, you'll just describe your needs + add a Slack channel, and the system will automatically onboard a new Agent into your team.

---

## Table of Contents

- [What Problem Does This Solve](#what-problem-does-this-solve)
- [Architecture at a Glance](#architecture-at-a-glance)
- [Get Started in 10 Minutes](#get-started-in-10-minutes)
- [Core Concepts at a Glance](#core-concepts-at-a-glance)
- [Enable Agent Collaboration](#enable-agent-collaboration)
- [Documentation Guide](#documentation-guide)
- [Stable vs Experimental](#stable-vs-experimental)
- [FAQ](#faq)
- [Contributing](#contributing)
- [The Journey](#the-journey)

---

## What Problem Does This Solve

If you're using OpenClaw, you've probably hit these walls:

| Your Pain Point | Root Cause | How OpenCrew Fixes It |
|----------------|------------|----------------------|
| Your agent gets "dumber" the longer you chat | One agent handles every domain — context bloat | Multiple agents each own their domain, no cross-contamination |
| Juggling multiple projects, constantly switching sessions | No visual task overview | Channel/group = role, thread = task — everything at a glance |
| Every step needs your confirmation — exhausting | Agent doesn't know what it can do on its own | Autonomy Ladder: reversible actions proceed automatically, irreversible ones ask you |
| You hit the same pitfalls again and again | Lessons are scattered across chat history | Three-layer Knowledge Distillation: conversations → structured summaries → reusable knowledge |
| Your agent drifts further off-track over time | Self-adjustments with no audit trail | Dedicated Ops agent handles auditing and drift prevention |

**In one sentence**: The problem isn't that OpenClaw isn't powerful enough — it's that one agent isn't enough. You need a team.

---

## Architecture at a Glance

> Core mental model: **Channel = Role, Thread = Task**

![OpenCrew Architecture](docs/Drawing_2026-02-16_16_58_excalidraw.png)

OpenCrew has three layers, each with clear responsibilities:

**Layer 1: Intent Alignment** — You + CoS (Chief of Staff)

You're the decision-maker. You set direction and sign off on results. CoS is your strategic partner — aligning on your deeper goals and pushing things forward when you're away. CoS is not a gateway; you can jump into any channel and talk to anyone directly.

**Layer 2: Execution** — CTO / Builder / CIO / Research

CTO breaks down work and owns architecture. Builder implements. CIO is the domain expert (defaults to investment, but swap in legal, marketing, or any domain you need). Research investigates on demand.

**Layer 3: System Maintenance** — KO + Ops

KO (Knowledge Officer) distills reusable knowledge from all outputs. Ops (Operations Officer) audits system changes and prevents drift. These two don't do business work — they keep the system healthy.

> Minimum viable setup: CoS + CTO + Builder (3 agents to get running). Add KO / Ops / CIO / Research as needed.

---

## Get Started in 10 Minutes

> Prerequisites: You can already use OpenClaw normally (`openclaw status` works), and your chosen platform is connected.

### Choose Your Platform

| Platform | Setup Guide | Thread (task isolation) | Agent Identity | Best for |
|----------|------------|------------------------|---------------|----------|
| **Slack** | [Slack Setup Guide](docs/en/SLACK_SETUP.md) | ✅ Full support | — Single bot, shared identity | Teams already using Slack |
| **Feishu** | [Feishu Setup Guide](docs/en/FEISHU_SETUP.md) | ⚠️ Not yet supported ([details](docs/en/FEISHU_SETUP.md#key-difference-from-slack-thread-support)) | ✅ Separate bot per agent ([advanced](docs/en/FEISHU_SETUP.md)) | Teams in China / Feishu users |
| **Discord** | [Discord Setup Guide](docs/en/DISCORD_SETUP.md) | ✅ Full support | ✅ Separate bot or webhook relay ([advanced](docs/en/DISCORD_SETUP.md)) | Developer communities / Discord users |

> **Default: Single Bot** — One bot/app joins multiple channels/groups, routing to different agents by channel. Works on all three platforms with the simplest setup.
> **Advanced: Independent Identity** — Feishu and Discord support creating a separate bot per agent (unique name, avatar, API quota). Discord also offers webhook relay (single bot receives + replies with different identities). See the "Advanced" section in each platform's guide.
>
> After completing platform setup, come back to Step 1 below. The walkthrough uses Slack as an example — Feishu and Discord steps are equivalent.

### Step 1: Create Channels/Groups + Invite Bot

Create channels in your Slack workspace, then `/invite @your-bot-name` in each one:

| Channel | Agent | Description |
|---------|-------|-------------|
| `#hq` | CoS (Chief of Staff) | Your main conversation window |
| `#cto` | CTO (Technical Co-founder) | Technical direction and task breakdown |
| `#build` | Builder (Executor) | Implementation and delivery |

> Add more as needed: `#invest` (CIO) `#know` (KO) `#ops` (Ops) `#research` (Research)

### Step 2: Let Your OpenClaw Handle the Deployment

Send the following to your existing OpenClaw (replace `<>` with your values):

```
Deploy OpenCrew multi-agent team for me.

Repo: please clone https://github.com/AlexAnys/opencrew.git to /tmp/opencrew
(If already downloaded, repo path: <your local path>)

Slack tokens (write to config, do not echo back):
- Bot Token: <your xoxb- token>
- App Token: <your xapp- token>

I've created these channels and invited the bot:
- #hq → CoS
- #cto → CTO
- #build → Builder

Read DEPLOY.en.md in the repo and follow the deployment process.
Do not touch my models / auth / gateway config — only add the OpenCrew increments.
```

Your OpenClaw will automatically: back up existing config → copy agent files → fetch Channel IDs → merge config → restart.

<details>
<summary>Using Feishu? Click here for the Feishu deployment prompt</summary>

```
Deploy OpenCrew multi-agent team for me.

Repo: please clone https://github.com/AlexAnys/opencrew.git to /tmp/opencrew
(If already downloaded, repo path: <your local path>)

Feishu credentials (write to config, do not echo back):
- App ID: <your cli_xxx>
- App Secret: <your secret>

I've created these group chats and added the bot:
- HQ group → CoS
- Tech group → CTO
- Build group → Builder

Read DEPLOY.en.md in the repo and follow the deployment process.
Do not touch my models / auth / gateway config — only add the OpenCrew increments.
```
</details>

<details>
<summary>Using Discord? Click here for the Discord deployment prompt</summary>

```
Deploy OpenCrew multi-agent team for me.

Repo: please clone https://github.com/AlexAnys/opencrew.git to /tmp/opencrew
(If already downloaded, repo path: <your local path>)

Discord credentials (write to config, do not echo back):
- Bot Token: <your MTxxx... token>

I've created these channels and invited the bot:
- #hq → CoS
- #cto → CTO
- #build → Builder

Read DEPLOY.en.md in the repo and follow the deployment process.
Do not touch my models / auth / gateway config — only add the OpenCrew increments.
```
</details>

> Prefer manual deployment? → [DEPLOY.en.md](DEPLOY.en.md) has full manual commands.

### Step 3: Verify

Test in your platform:

1. Send a message in the CoS channel/group → CoS replies ✅
2. Send a message in the CTO channel/group → CTO replies ✅
3. Ask CTO to dispatch a task to Builder → Builder replies in their channel/group ✅

> Detailed step-by-step guide (including common errors, troubleshooting checklist) → [Full Getting Started Guide](docs/en/GETTING_STARTED.md)

---

## Core Concepts at a Glance

OpenCrew runs on a few key mechanisms. Here's the 30-second overview — full details at → [Core Concepts Deep Dive](docs/en/CONCEPTS.md)

**Autonomy Ladder** — When should an agent act on its own vs. ask you?

| Level | Meaning | Examples |
|-------|---------|----------|
| L0 | Suggest only, no action | — |
| L1 | Reversible actions, just do it | Write drafts, research, organize docs |
| L2 | Has impact but rollback-able, report after | Open PRs, change configs, write analyses |
| L3 | Irreversible, must get your confirmation | Deploy, trade, delete, send externally |

**Task Classification (QAPS)** — Different task types, different handling rules

| Type | Meaning | Needs Closeout? |
|------|---------|----------------|
| Q | One-off question | No |
| A | Small task with a deliverable | Yes |
| P | Project (multi-step, multi-day) | Yes + Checkpoint |
| S | System change | Yes + Ops audit |

**A2A Two Modes** — How agents collaborate

| Mode | Use Case | Mechanism | Platform |
|------|----------|-----------|----------|
| **Delegation** | Dispatch specific tasks | `sessions_send` two-step trigger | Slack / Discord / Feishu |
| **Discussion** | Multi-party discussion, review, negotiation | Independent Bot @mention conversation | Slack |

Delegation is the foundation -- CTO assigns work to Builder. Discussion is the enhancement -- the Orchestrator walks into CTO's channel, and the two Agents discuss the approach while you watch. Details at → [A2A Protocol v2](shared/A2A_PROTOCOL.md)

**Three-Layer Knowledge Distillation** — How chat history becomes organizational assets

```
Layer 0: Raw conversations (for audit, not directly reused)
Layer 1: Closeouts (10–15 line structured summaries, ~25x compression)
Layer 2: KO-distilled abstract knowledge (principles / patterns / lessons learned)
```

---

## Enable Agent Collaboration

> After deployment, each Agent replying independently does not mean Agents can collaborate with each other.
> A2A (Agent-to-Agent) requires additional configuration.

### Discussion Mode (Recommended) -- True Multi-Agent Collaboration

Pick an Agent as the orchestrator, create an independent Slack App for it -> invite it into execution Agents' channels -> the two Agents collaborate directly in the channel.

**Setup in three steps** (human effort ~5 minutes, the rest is handled by agents):

1. **Create an independent Slack App**: [api.slack.com/apps](https://api.slack.com/apps) -> From manifest -> use the manifest in [A2A_SETUP_GUIDE.md](docs/en/A2A_SETUP_GUIDE.md)
2. **Have your Agent configure multi-account** -- send the following to any Agent:

```
Help me configure Discussion Mode.

Reference: read docs/A2A_SETUP_GUIDE.md in the repo

New Bot credentials (write to config, do not echo back):
- Bot Token: <xoxb-new-bot>
- App Token: <xapp-new-bot>

Target channel: #cto (let the new bot collaborate with CTO)

Follow the steps in A2A_SETUP_GUIDE.md to configure multi-account.
You MUST also declare accounts.default (using existing tokens), otherwise the main bot will disconnect.
Do not touch my models / auth / gateway config -- only make A2A-related changes.
```

3. **Invite the bot in the target channel**: `/invite @NewBotName`

Verify: @mention the new bot in #cto -> new bot replies -> @mention CTO in the thread -> CTO also replies -> two Agents conversing in the same thread.

> Full guide (with manifest, config templates, pitfall checklist, rollback) -> [Discussion Mode Setup Guide](docs/en/A2A_SETUP_GUIDE.md)

### Delegation Mode -- One-Way Task Dispatch

For scenarios that don't need Discussion, you can use the simpler Delegation mode: CTO dispatches to Builder in `#build` -> Builder executes in rounds -> CTO reports back to `#cto`. You only need to watch Slack.

<details>
<summary>Delegation Setup (no independent Slack App needed)</summary>

Send the following to any Agent:

```
Help me set up A2A Delegation (legacy delegation mode).

Reference: read shared/A2A_PROTOCOL.md Appendix C (legacy Delegation) in the repo

Current state:
- OpenCrew is deployed, each Agent replies normally in their channel
- My Slack channels: #hq(CoS) #cto(CTO) #build(Builder)

Follow the instructions in Appendix C:
1. Check and complete Delegation config in openclaw.json (agentToAgent.allow / maxPingPongTurns)
2. Append Delegation A2A sections to CoS, CTO, and Builder's AGENTS.md (minimal increment, don't rewrite)
3. First validate CoS->CTO closed-loop, then CTO->Builder closed-loop
4. Report results to me

Do not touch my models / auth / gateway config -- only make A2A-related changes.
```

> First-time setup note: the Agent will update `openclaw.json` A2A settings, which triggers a gateway restart. All Agents briefly disconnect, then auto-recover.

</details>

> Full comparison and technical details of both modes -> [A2A Protocol v2](shared/A2A_PROTOCOL.md)

---

## Documentation Guide

### For You (the User)

| Document | What's Inside | When to Read |
|----------|--------------|--------------|
| **[Full Getting Started Guide](docs/en/GETTING_STARTED.md)** | Zero-to-running detailed steps + common issues | First-time deployment |
| **[Core Concepts Deep Dive](docs/en/CONCEPTS.md)** | Complete explanation of Autonomy Ladder, QAPS, A2A, Knowledge Distillation | Want to deeply understand the system |
| **[Architecture Design](docs/en/ARCHITECTURE.md)** | Three-layer architecture, design trade-offs, rationale | Want to understand design decisions |
| **[A2A Setup Guide](docs/en/A2A_SETUP_GUIDE.md)** | Delegation + Discussion config, multi-account setup, validation steps | Enable cross-agent collaboration |
| **[Customization Guide](docs/en/CUSTOMIZATION.md)** | Add/remove/modify agents, swap domain experts | Want to adjust your team setup |
| **[Known Issues](docs/en/KNOWN_ISSUES.md)** | Real system boundaries and current best practices | When you hit weird behavior |
| **[The Journey](docs/en/JOURNEY.md)** | From one person's pain point to a virtual team | Want the backstory |
| **[FAQ](docs/en/FAQ.md)** | Frequently asked questions | Quick lookup |
| **[Slack Setup](docs/en/SLACK_SETUP.md)** | Slack App creation and config | Using Slack |
| **[Feishu Setup](docs/en/FEISHU_SETUP.md)** | Feishu custom app creation and config | Using Feishu |
| **[Discord Setup](docs/en/DISCORD_SETUP.md)** | Discord Bot creation and config | Using Discord |

### For Your Agents (what agents need to understand during deployment)

| Document | What's Inside | Who Reads It |
|----------|--------------|-------------|
| **[Agent Onboarding Guide](docs/en/AGENT_ONBOARDING.md)** | What an agent should read on first boot, how to understand the system | Newly deployed agents |
| Everything under **shared/** | Global protocols and templates (the agent "employee handbook") | All agents |
| SOUL.md / AGENTS.md in each workspace | Role definitions and workflows | The respective agent |

---

## Stable vs Experimental

### ✅ Stable and Running

- Multi-agent domain separation + channel binding (Slack / Feishu / Discord)
- A2A Delegation (two-step trigger: Slack visible anchor + `sessions_send`)
- A2A Discussion (independent Bot @mention collaboration, Slack verified) `NEW`
- A2A closed-loop (multi-round WAIT discipline + dual-channel trace + closed-loop DoD)
- Closeout / Checkpoint enforced structured outputs
- Autonomy Ladder (L0–L3)
- Ops Review governance loop
- Signal scoring + KO Knowledge Distillation

### 🔄 Experimental

- Better knowledge system (cross-session semantic retrieval)
- Lighter architecture (v2-lite: 7 agents → 5, 9 shared files → 3)
- Discord Discussion mode (blocked by OpenClaw code-level bug, not a platform limitation)

---

## FAQ

**Q: Do I need to know how to code?**

No. OpenCrew was designed and deployed by a non-technical user with an economics/MBA background. You need to be comfortable typing a few terminal commands — or just send the deployment commands to your existing OpenClaw and let it handle everything.

**Q: What's the minimum number of agents?**

3: CoS + CTO + Builder. That's the minimum viable setup. Scale up when you notice experience is being lost (add KO) or the system is drifting (add Ops).

**Q: How is this different from CrewAI / AutoGen?**

Those are SDKs for developers to write code. OpenCrew is a system for decision-makers to manage a team — you manage your AI team through Slack, no code required. They solve "how to orchestrate agents." OpenCrew solves "how to manage an AI team."

**Q: Which platforms are supported?**

**Slack**, **Feishu**, and **Discord**. The core model "channel/group = role" is consistent across all three. Slack and Discord fully support thread-based task isolation; Feishu's thread support is limited by the OpenClaw plugin and not yet available ([details](docs/en/FEISHU_SETUP.md#key-difference-from-slack-thread-support)). Pick whichever your team uses most.

**Q: Won't this burn through a lot of tokens?**

More than a single agent, yes — each agent has its own context. But the Closeout mechanism (~25x compression) and domain isolation (each agent only sees its own domain's information) actually make per-conversation token usage more efficient. Total volume goes up, but each agent runs leaner.

**Q: Does Slack Free plan work?**

Yes. The Slack APIs OpenCrew uses (Socket Mode) are fully available on the free plan. The only limitation is 90-day message history retention, but important information is already distilled through Closeouts and the knowledge base.

More Q&A → [FAQ](docs/en/FAQ.md)

---

## Contributing

Issues and PRs are welcome. We especially appreciate:

- Improvement ideas for multi-agent collaboration architecture
- Practical experience with knowledge systems (retrieval / indexing / memory)
- Stability optimizations for Slack thread / session handling
- Adapters for more platforms (Telegram / Lark / etc.)
- Bug reports and improvements for our English documentation

---

## The Journey

This project was built solo by a non-technical OpenClaw user with an economics/MBA background.

It started with discovering that "one agent handling every domain leads to context bloat," evolved into a 7-agent collaboration architecture, and then came a series of technical challenges — A2A loop storms, deliveryContext drift, and more. The full record of pitfalls and design decisions is at → [The Journey](docs/en/JOURNEY.md)

**Why open-source now?** The system has been running in real use and iterating steadily, but some edge cases remain unsolved. Rather than wait for "perfect," we're putting the working framework out there — so more people can give feedback, co-build, and evolve it together.

---

## Directory Structure

```
opencrew/
├── README.md                         ← Chinese README
├── README.en.md                      ← You are here
├── DEPLOY.md                         ← Deployment guide (Chinese)
├── DEPLOY.en.md                      ← Deployment guide (English)
├── LICENSE                           ← MIT
├── shared/                           ← Global protocols and templates (shared by all agents)
├── workspaces/                       ← Each agent's workspace
├── docs/
│   ├── en/                           ← English documentation
│   ├── GETTING_STARTED.md            ← Full getting started guide (Chinese)
│   ├── CONCEPTS.md                   ← Core concepts deep dive (Chinese)
│   ├── ARCHITECTURE.md               ← Architecture design (Chinese)
│   ├── A2A_SETUP_GUIDE.md            ← A2A setup guide — for agents (Chinese)
│   ├── CUSTOMIZATION.md              ← Customization guide (Chinese)
│   ├── AGENT_ONBOARDING.md           ← Agent onboarding guide (Chinese)
│   ├── FAQ.md                        ← FAQ (Chinese)
│   ├── KNOWN_ISSUES.md               ← Known issues (Chinese)
│   ├── JOURNEY.md                    ← The journey (Chinese)
│   ├── SLACK_SETUP.md                ← Slack setup guide (Chinese)
│   ├── FEISHU_SETUP.md               ← Feishu setup guide (Chinese)
│   ├── DISCORD_SETUP.md              ← Discord setup guide (Chinese)
│   └── CONFIG_SNIPPET_2026.2.9.md    ← Minimal config snippet (Slack)
├── patches/                          ← Advanced workarounds (not recommended for beginners)
└── v2-lite/                          ← Lighter architecture exploration (experimental)
```

---

## License

MIT

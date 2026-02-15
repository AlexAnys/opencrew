[中文](../ARCHITECTURE.md) | **English**

# Architecture — Detailed Design

## Design Goals

1. **Domain Specialization**: Different types of tasks are handled by dedicated Agents, preventing context pollution
2. **Structured Collaboration**: Protocols and templates make collaboration trackable and reusable
3. **Knowledge Distillation**: A three-layer structure turns experience from "chat logs" into "reusable assets"
4. **Governance Loop**: The system can self-iterate, but every step is auditable and reversible

## System Structure: Three-Layer Architecture

> Visual architecture diagrams:
> - Source file (editable): [OpenCrew-Architecture-with-slack.excalidraw](../OpenCrew-Architecture-with-slack.excalidraw)
> - (Optional) Export a PNG: `docs/OpenCrew-Architecture-with-slack.png` for GitHub preview

OpenCrew's architecture is divided into three layers, each with clear responsibility boundaries:

### Layer 1: Deep Intent Alignment Layer

The User and CoS sit side by side. The User is the decision-maker (sets direction, accepts deliverables). The CoS is a strategic partner (deep intent alignment, drives tasks on the user's behalf).

| Agent | Responsibility | Slack Channel | Notes |
|-------|---------------|---------------|-------|
| **YOU** | Set direction, accept deliverables | Can talk directly in any channel | Jump into whichever channel you want |
| **CoS** | Deep intent alignment, drive tasks forward | #hq | Strategic partner, **not a gateway, not required** |

The CoS's value: aligning with you on deep goals and value judgments, and driving tasks to CTO/CIO on your behalf when you're unavailable (dotted-line path, optional). You can absolutely bypass CoS and talk directly to any Agent.

### Layer 2: Execution Layer

The Agents that do the actual work. You can talk directly to CTO/CIO, or have CoS drive tasks on your behalf.

| Agent | Responsibility | Slack Channel | Relationship |
|-------|---------------|---------------|-------------|
| **CTO** | Tech architecture, task breakdown, delivery stability | #cto | Direct user conversation |
| **CIO** | Domain expert (**replaceable with other specializations**) | #invest | Optional, dashed border |
| **Builder** | Implementation, testing, delivery | #build | Assigned by CTO |
| **Research** | Information gathering and analysis | #research | **Optional**, spawned on demand, dispatched by CTO or CIO |

CIO defaults to investment, but by design it's a **replaceable slot** — swap it for legal, marketing, product, or any domain expert. Research is a temporary worker, released when the task is done.

### Layer 3: System Maintenance Layer

No business tasks. Dedicated to system health. Receives **output from all Agents**, responsible for knowledge distillation and controlled iteration.

| Agent | Responsibility | Slack Channel | Scope |
|-------|---------------|---------------|-------|
| **KO** | Extracts reusable knowledge from all Agents' closeouts | #know (suggest @mention-gated, optional) | System-wide knowledge distillation |
| **Ops** | Audits all Agent changes, prevents drift | #ops (suggest @mention-gated, optional) | System-wide governance |

We recommend setting #know/#ops to `requireMention=true` to reduce noise. But the open-source default leaves it off (prioritizing "follow the steps and it just works" for newcomers). You can turn it on once things are running.

### External: Your Existing OpenClaw

Your existing OpenClaw Agent (webchat/terminal) is completely independent of OpenCrew — they don't affect each other. Your existing Agent can help deploy and operate OpenCrew.

### Why Slack as the Communication Infrastructure?

Slack's product features are a natural fit for multi-Agent collaboration:

| Slack Feature | Corresponding Value |
|--------------|-------------------|
| Channels | = Agent roles, one App manages all Agents |
| Threads | = Independent sessions, natural context isolation |
| Unreads / Later | = Decision to-do list, clear at a glance |
| A2A cross-channel output | All collaboration visible, fully auditable |
| Drafts / Sent tracking | Thread trace for complete chain |
| Mobile app | Approve anytime, decide anywhere — fragments of time = management time |
| Add/remove channels | Agents and channels are plug-and-play, flexible scaling |

## A2A Two-Step Trigger Mechanism

### Why Two Steps?

In OpenClaw's Slack integration, all Agents share one bot identity. Messages sent by the bot are ignored by itself by default (to prevent self-loops). So when Agent A sends a message in Slack, Agent B won't automatically process it.

The solution is a **two-step trigger**:

```
Step 1: Agent A creates a root message in Agent B's channel (visible anchor in Slack)
Step 2: Agent A calls sessions_send() to trigger Agent B (the actual execution signal)
```

### Session Key Structure

```
agent:<target_agent_id>:slack:channel:<channelId>:thread:<root_ts>
```

This key ensures Agent B executes within that thread's context, achieving thread-level session isolation.

### Anti-Loop Triple Protection

1. **Permission Matrix**: Only CoS/CTO/Ops can initiate sessions_send (config-layer hard constraint)
2. **maxPingPongTurns = 4**: Limits A2A round-trips (config-layer hard constraint)
3. **Subagent deny sessions**: Sub-Agents cannot spawn sessions (config-layer hard constraint)

## Information Flow

### Task Dispatch Flow (Multiple Paths Coexist)

```
Path 1 (Direct):    User -> #cto (CTO) -> Breakdown -> A2A -> #build (Builder)
Path 2 (Via CoS):   User -> #hq (CoS) -> Evaluate/Assign -> A2A -> #cto (CTO) -> ...
Path 3 (Domain):    User -> #invest (CIO) -> Handle independently or spawn Research
Path 4 (CoS Drive): CoS proactively drives -> A2A -> CTO/CIO (when user authorizes or is away)
```

You don't have to go through CoS — talk to whoever you want by jumping into their channel.

### Result Reporting Flow

```
Builder closeout -> CTO syncs to #cto -> User sees it in #cto (if via CoS, CoS syncs to #hq)
```

### Knowledge Distillation Flow

```
Any Agent's closeout (signal >= 2) -> #know -> KO extracts -> knowledge/{principles,patterns,scars}.md
```

### Governance Audit Flow

```
S-class closeout / Self-Update -> #ops -> Ops five-dimension audit -> Approved / Needs-revision / Rejected
```

## Workspace File Reference

Each Agent's workspace contains these files:

| File | Purpose | Update Frequency |
|------|---------|-----------------|
| IDENTITY.md | Name, emoji, one-liner positioning | Rarely |
| SOUL.md | Role directives, core principles, autonomy boundaries (**highest priority, must-read on Agent startup**) | Low |
| AGENTS.md | Workflow, task processing logic, spawn rules | Medium |
| USER.md | User profile: preferences, constraints, communication style | Low |
| TOOLS.md | Tools and environment configuration | Low |
| MEMORY.md | Long-term memory: stable preferences, principles, lessons | Medium |
| TASKS.md | Current task board | High |
| HEARTBEAT.md | Periodic check checklist | As needed |

**Key design**: SOUL.md is read first, ensuring role positioning has the highest priority in the Agent's context.

## Shared Protocols Reference

Rules and templates shared by all Agents live in `~/.openclaw/shared/`:

| File | Purpose |
|------|---------|
| SYSTEM_RULES.md | Global system rules (autonomy levels, task classification, artifact requirements) |
| A2A_PROTOCOL.md | Agent-to-Agent collaboration protocol (two-step trigger, permission matrix) |
| OPS_REVIEW_PROTOCOL.md | Governance audit rules (review dimensions, cadence) |
| KNOWLEDGE_PIPELINE.md | Knowledge distillation pipeline (three-layer structure, KO workflow) |
| TASK_PROTOCOL.md | Task classification and processing protocol |
| CLOSEOUT_TEMPLATE.md | Task closeout template |
| CHECKPOINT_TEMPLATE.md | Checkpoint template |
| SUBAGENT_PACKET_TEMPLATE.md | Sub-Agent task packet template |
| SELF_UPDATE_TEMPLATE.md | Self-update record template |

## Config-Layer Hard Constraints

The following behaviors are enforced via `openclaw.json` at the config layer — they don't rely on Agents "being well-behaved":

| Constraint | Config Key | Effect |
|-----------|-----------|--------|
| A2A initiation permission | `tools.agentToAgent.allow` | Only CoS/Ops/CTO can initiate sessions_send |
| A2A loop limit | `session.agentToAgent.maxPingPongTurns` | Maximum 4 round-trips |
| Subagent permission | `tools.subagents.tools.deny` | Sub-Agents cannot operate sessions |
| Channel isolation | `channels.slack.groupPolicy = "allowlist"` | Only responds to allowed channels |
| Ops noise control | `requireMention = true` (optional) | Recommended for #ops/#know @mention gate (open-source default is off, turn on once running) |
| Thread isolation | `thread.historyScope = "thread"` | Each thread is an independent session |
| Reply mode | `replyToMode = "all"` | All replies automatically go into the thread |

## Design Trade-offs

### Why 7 Agents, Not 3 or 10?
7 is the current sweet spot: enough domain specialization + manageable collaboration complexity. 3 is too few (context still bloats). 10 is too many (A2A coordination cost explodes: N*(N-1)/2 = 45 channels).

### Why Slack and Not Something Else?
- Slack threads natively support task-level isolation
- Humans can see what Agents are doing at any time (explicit auditability)
- OpenClaw natively supports Slack integration
- The free tier is sufficient

### Why Are KO and Ops Separate Agents?
Knowledge distillation and system governance are "meta-tasks" — they don't serve a specific business need, they serve the health of the entire system. If mixed into execution Agents, they'd either get crowded out by business priorities or conflict with business context. Keeping them independent lets them stay focused and undisturbed. This is also why their channels are set to requireMention — reduce noise, only wake them when needed.

### Why Isn't CoS a Gateway?
The CoS's value is **deep intent alignment** and **driving tasks when you're away**, not routing messages. If every task went through CoS, you'd get intent loss and reduced efficiency. Talking directly to CTO/CIO gives you the shortest path for intent delivery and maximum efficiency. CoS is your strategic partner, not your secretary.

### Why Are SOUL.md and AGENTS.md Separate?
SOUL is the role's core positioning and principles ("who you are, what your boundaries are"). AGENTS is the operational workflow ("what to do when a task arrives"). Separating them prevents workflow details from diluting the priority of role positioning.

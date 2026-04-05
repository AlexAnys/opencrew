[中文](../ARCHITECTURE.md) | **English**

> [README](../../README.en.md) > [Getting Started](GETTING_STARTED.md) > [Core Concepts](CONCEPTS.md) > **Architecture** > [Customization](CUSTOMIZATION.md)

# Architecture

> This document focuses on "why it's designed this way." For specific rules and parameters of each mechanism, see [Core Concepts](CONCEPTS.md).

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
| A2A cross-channel collaboration | Orchestrator enters other channels to discuss, visible and auditable |
| Drafts / Sent tracking | Thread trace for complete chain |
| Mobile app | Approve anytime, decide anywhere — fragments of time = management time |
| Add/remove channels | Agents and channels are plug-and-play, flexible scaling |

## A2A Native Collaboration

### Core Idea

All Agents share one Slack bot identity -> the bot ignores its own messages -> Agents cannot directly talk to each other.

**Solution: Selective Independence.** Give the Orchestrator its own independent Slack App, invite it into other Agents' channels, and let it @mention them directly.

```
Orchestrator (independent App) enters #cto -> @CTO starts discussion
CTO (default Bot) replies in thread -> @Orchestrator
Orchestrator evaluates -> continue @CTO / move to #build @Builder / terminate
```

### Loop Prevention: Two-Layer Defense

1. **Config layer**: `requireMention: true` (channel root messages require explicit @)
2. **Prompt layer**: @mention protocol (check for explicit `<@BotID>` in thread, reply NO_REPLY if absent)

> Full protocol at `shared/A2A_PROTOCOL.md`; setup guide at `docs/A2A_SETUP_GUIDE.md`.

## Information Flow

### Task Dispatch Flow (Multiple Paths Coexist)

```
Path 1 (Direct):       User -> #cto (CTO) -> Breakdown -> @Builder discussion / spawn execution
Path 2 (Orchestrator): User -> @Orchestrator -> enters #cto to discuss with CTO -> enters #build to confirm with Builder
Path 3 (Domain):       User -> #invest (CIO) -> Handle independently or spawn Research
Path 4 (Proxy Drive):  Orchestrator proactively drives -> @CTO/@CIO (when user authorizes or is away)
```

You don't have to go through CoS -- talk to whoever you want by jumping into their channel.

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

## Workspace and Shared Protocols

> For the full file list and field descriptions, see [Core Concepts SS7-SS9](CONCEPTS.md#7-workspace-file-structure)

**Key design decisions**:
- **SOUL.md has the highest priority**: Read first on Agent startup, ensuring "who you are" takes precedence over "how you work"
- **SOUL and AGENTS are separate**: Prevents operational procedures from diluting role positioning
- **shared/ is linked via symlink**: Avoids multiple copies leading to protocol drift

## Config-Layer Hard Constraints

> For the full config reference, see [Core Concepts SS9](CONCEPTS.md#9-configuration-layer-hard-constraints)

**Core principle**: If a constraint can go into config, don't just put it in documentation. Document-layer rules can be "forgotten" by Agents. Config-layer rules cannot be bypassed.

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

---

> Next steps: [Customize Your Agents](CUSTOMIZATION.md) | [Known Issues](KNOWN_ISSUES.md) | [Core Concepts](CONCEPTS.md)

[中文](../CONCEPTS.md) | **English**

> [README](../../README.en.md) > [Getting Started](GETTING_STARTED.md) > **Core Concepts** > [Architecture](ARCHITECTURE.md) > [Customization](CUSTOMIZATION.md)

# Core Concepts

This page brings together all of OpenCrew's key mechanisms in one place. You don't need to read it all at once -- come back whenever you hit a concept you don't understand.

---

## 1. Channel = Role, Thread = Task

This is the most fundamental mapping in OpenCrew. Understand this, and everything else falls into place.

**A channel is a role.** Each Slack channel corresponds to an Agent's "workstation." Want to talk to the CTO? Go to `#cto`. Want the Builder to do something? Start a thread in `#build`.

**A thread is a task.** One thread = one task = one independent session. Context is fully isolated between threads. You can have multiple threads running in the same channel (i.e., multiple tasks in parallel).

**Unreads are your to-do list.** Slack's unread messages automatically become your decision queue -- which threads have updates, which Agents are waiting for your confirmation. Open your phone and see it all at a glance.

| Slack Feature | Meaning in OpenCrew |
|---------------|---------------------|
| Channel | Agent's role |
| Thread | Independent task / session |
| Unreads / Later | Your decision queue |
| Root message | Task anchor (ensures A2A visibility) |
| Mobile app | Spare moments = management time |

---

## 2. Autonomy Ladder

Agents don't need to ask you about everything. The Autonomy Ladder defines "when should an Agent act on its own, and when must it come to you."

| Level | Meaning | Agent Behavior | Example |
|-------|---------|----------------|---------|
| **L0** | Suggest only | Takes no action | "I suggest doing X -- confirm and I'll proceed" |
| **L1** | Reversible ops | Acts directly | Write drafts, do research, organize docs, edit code |
| **L2** | Impactful but rollbackable | Acts, then writes Closeout | Open PRs, modify config files, write investment analysis |
| **L3** | Irreversible ops | **Must get your confirmation** | Publish releases, execute transactions, delete data, send externally |

**Design principle**: L1/L2 proceed autonomously by default; L3 always requires human confirmation. This lets Agents maximize output within safe boundaries while handing you control at critical moments.

Each Agent's SOUL.md specifies its autonomy boundaries. For example, Builder:

```
Can do directly: write code, open PRs, run tests
Must confirm: merge to main, publish releases, delete branches
```

---

## 3. Task Classification (QAPS)

Different types of tasks require different levels of rigor. QAPS tells Agents "how thorough do I need to be for this task."

| Type | Full Name | Characteristics | Output Requirements | Typical Scenario |
|------|-----------|-----------------|---------------------|------------------|
| **Q** | Query | One-off question | No Closeout needed | "What is Socket Mode?" |
| **A** | Artifact | Small task with a deliverable | Must Closeout | "Write me an API doc" |
| **P** | Project | Multi-step, may span days | Task Card + Checkpoint + Closeout | "Migrate the database schema" |
| **S** | System | System-level change | Ops Review + Closeout + rollback plan | "Modify an Agent's SOUL.md" |

**Why classify?** If every task followed the same process, small questions would be over-handled (waste) and big problems would be under-handled (risk). QAPS matches "level of rigor" to "task importance."

---

## 4. A2A Two-Step Trigger

Agent-to-Agent collaboration requires a special mechanism because all Agents share a single Slack bot identity -- the bot won't trigger on its own messages.

### Why Two Steps?

```
Problem: CTO posts a message in #build for Builder
         -> Slack sees it as a bot message
         -> Bot ignores its own messages by default
         -> Builder never receives it
```

### How the Two-Step Trigger Works

**Step 1: Create a visible root message (anchor) in the target channel**

CTO posts a message in `#build`, formatted like:

```
A2A cto->builder | Implement login feature | TID:20260210-1430-login
---
Goal: Add OAuth login to the user system
Done criteria: Unit tests pass, compatible with Google/GitHub
```

This message is for you -- you can always see in Slack "what task did CTO assign to Builder."

**Step 2: Use sessions_send to trigger Builder**

CTO calls `sessions_send()`, pushing the message to Builder's session in that thread. This is what actually makes Builder "start working."

### Loop Prevention

Three layers of protection prevent Agents from triggering each other in a message storm:

| Protection Layer | Mechanism | Configuration |
|------------------|-----------|---------------|
| Permission matrix | Only CoS/CTO/Ops can initiate A2A | `tools.agentToAgent.allow` |
| Round-trip limit | Max 4 ping-pong exchanges | `maxPingPongTurns = 4` |
| Sub-Agent restriction | Spawned sub-Agents cannot initiate A2A | `tools.subagents.tools.deny` |

### Permission Matrix

Not every Agent can assign tasks to everyone. Follow organizational discipline:

```
CoS -> CTO (strategic guidance)
CTO -> Builder / Research / KO (task distribution)
Ops -> Everyone (audit privileges)
Builder -> Cannot assign tasks (receives and executes only)
CIO -> Operates independently (syncs with CoS when needed)
```

---

## 5. Structured Artifacts: Closeout and Checkpoint

### Closeout -- Structured Summary at Task Completion

After every A/P/S task is completed, the executor must write a 10-15 line Closeout:

```
CLOSEOUT A | Implement rate limiting | TID:20260210-1400-ratelimit
---
## What was done
- Added Token Bucket rate limiting to API gateway
- Test coverage at 89%

## Key decisions
1. Chose Token Bucket over Sliding Window (reason: simpler in distributed scenarios)
2. Limit set to 100 req/sec per IP (based on capacity model)

## Pitfalls
- Redis sync latency caused race condition -> switched to in-memory + graceful degradation

## Signal: 3 (general technical pattern, worth distilling)
```

**Why Closeouts?**

- Information compression: 50K tokens of conversation -> 1-2K summary (~25x compression)
- KO only reads Closeouts, not massive conversations
- You only need to read Closeouts to know what happened

### Checkpoint -- Progress Report for Long Tasks

For P-type tasks that span multiple days, write one at the end of each day or at each key milestone:

```
CHECKPOINT P | Database migration | TID:20260210-0900-dbmigrate | Progress: 40%
---
Completed: schema design, test environment setup
In progress: data migration script (50%)
Blocked: awaiting DBA approval (expected 2/12)
```

---

## 6. Three-Layer Knowledge Distillation

How does experience go from "chat logs" to "organizational assets"? Through three layers of filtering:

```
Layer 0: Raw conversation
  |  Fully retained for audit, not directly reused
  |
  v  Closeout compression (~25x)
  |
Layer 1: Closeouts (structured summaries)
  |  Output from all A/P/S tasks
  |  Signal score 0-3
  |
  v  KO distillation (only Signal >= 2 enters)
  |
Layer 2: Abstract knowledge
  |-- Principles: "In scenario X, you should do Y"
  |-- Patterns: "The general solution for this type of problem is Z"
  +-- Scars: "Never do W, because..."
```

### Signal Score

Not every Closeout deserves a spot in the knowledge base. Signal scoring acts as the filter:

| Score | Meaning | How It's Handled |
|-------|---------|------------------|
| 0 | One-off fix, no reuse value | Agent keeps internally |
| 1 | Useful in specific scenarios, hard to generalize | Agent keeps internally |
| 2 | Likely reusable by other tasks | KO distills -> knowledge base |
| 3 | General pattern, applicable across domains | KO prioritizes -> knowledge base |

---

## 7. Workspace File Structure

Each Agent's workspace is its "brain":

| File | Purpose | Read Priority | Update Frequency |
|------|---------|---------------|------------------|
| **SOUL.md** | Role definition, core principles, autonomy boundaries | **Highest** (must read on startup) | Very low |
| **AGENTS.md** | Workflows, task processing logic | High | Medium |
| **USER.md** | User profile: preferences, style, constraints | Medium | Low |
| **MEMORY.md** | Long-term memory: stable preferences, principles, lessons | Medium | Medium |
| **IDENTITY.md** | Name, emoji, one-line positioning | Low | Very low |
| **TOOLS.md** | Tool and environment configuration | Low | Low |
| **TASKS.md** | Current task board | On demand | High |
| **HEARTBEAT.md** | Periodic check-in checklist | On demand | On demand |

**Key design**: SOUL.md is read first, ensuring "who you are" takes priority over "how you work." Separating role definition from operational process (SOUL vs AGENTS) prevents procedural details from diluting role identity.

---

## 8. shared/ Global Protocols

The `shared/` directory holds the "employee handbook" shared by all Agents -- unified protocols and templates that prevent each Agent from writing its own version and drifting apart.

| File | Content |
|------|---------|
| `SYSTEM_RULES.md` | Autonomy Ladder + QAPS + artifact requirements |
| `A2A_PROTOCOL.md` | Two-step trigger for cross-Agent collaboration + permission matrix |
| `TASK_PROTOCOL.md` | Task classification and handling standards |
| `CLOSEOUT_TEMPLATE.md` | Closeout template |
| `CHECKPOINT_TEMPLATE.md` | Checkpoint template |
| `OPS_REVIEW_PROTOCOL.md` | Five-dimension audit for S-type changes |
| `KNOWLEDGE_PIPELINE.md` | Knowledge distillation pipeline |
| `SUBAGENT_PACKET_TEMPLATE.md` | Task packet template for spawning sub-tasks |
| `SELF_UPDATE_TEMPLATE.md` | Agent self-iteration record template |

> These files are not decorative documentation -- they are referenced by each Agent's AGENTS.md as part of its workflow. Critical constraints also sink down to the OpenClaw configuration layer (hard constraints > soft constraints).

---

## 9. Configuration-Layer Hard Constraints

Some rules rely on "Agents following them voluntarily" (document layer). Others are enforced directly in configuration (config layer). The latter is more reliable.

| Constraint | Type | Config Key | Why It's Needed |
|------------|------|------------|-----------------|
| A2A initiation permission | Hard | `tools.agentToAgent.allow` | Prevent everyone from assigning tasks |
| A2A loop limit | Hard | `maxPingPongTurns` | Prevent message storms |
| Sub-Agent permission | Hard | `tools.subagents.tools.deny` | Sub-Agents cannot spawn further |
| Channel isolation | Hard | `groupPolicy = "allowlist"` | Only respond in allowed channels |
| Thread isolation | Hard | `historyScope = "thread"` | Each thread is an independent session |
| Reply mode | Hard | `replyToMode = "all"` | Replies automatically go into threads |
| Ops noise reduction | Optional | `requireMention = true` | Recommended for #ops/#know |

**Practical advice**: If a constraint can go into config, don't just put it in documentation. Document-layer rules can be "forgotten" by Agents. Config-layer rules cannot be bypassed.

---

## Concept Relationship Map

```
You (decision-maker)
  |
  |-- Converse in Slack channels (= roles)
  |     +-- Each thread (= task) is an independent session
  |
  |-- Agents progress autonomously per the Autonomy Ladder
  |     +-- L1/L2 act directly, L3 asks for your confirmation
  |
  |-- Tasks are classified and handled via QAPS
  |     +-- Q gets lightweight handling; A/P/S require Closeout
  |
  |-- Agents collaborate via A2A two-step trigger
  |     +-- Permission matrix + loop prevention
  |
  +-- Knowledge accumulates through three-layer distillation
        +-- Conversation -> Closeout -> KO abstract knowledge
```

---

> Next steps: [Architecture Deep Dive](ARCHITECTURE.md) | [Customize Your Agents](CUSTOMIZATION.md) | [Known Issues](KNOWN_ISSUES.md)

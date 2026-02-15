[中文](../AGENT_ONBOARDING.md) | **English**

# Agent Onboarding Guide — A System Comprehension Doc for AI Agents

> **The reader of this document is an agent, not a human.**
> If you are an AI agent deployed into OpenCrew, read and execute in the order below.
> If you are a human user, this document helps you understand "what an agent should know at startup."

---

## Step 1: Understand who you are

Navigate to your workspace directory (e.g., `~/.opencrew/workspace-cto/`) and read in this **strict order**:

### 1. SOUL.md (highest priority)

This file defines your role, values, and capability boundaries. It is your "constitution" -- all subsequent behavior must not violate the principles in SOUL.md.

You need to understand from it:
- What domain you are responsible for
- Where your autonomy boundaries are (what you can do directly, what requires confirmation)
- Your relationship with other agents

### 2. AGENTS.md (workflow)

This file defines your operational procedures:
- How to classify tasks when received (Q/A/P/S)
- When to write a Closeout, when to write a Checkpoint
- When to spawn subtasks, when to send A2A
- Which files to read at session startup

### 3. USER.md (user profile)

About the human user you serve:
- Preferences and communication style
- Professional background and constraints
- What they dislike

### 4. MEMORY.md (long-term memory)

Stable knowledge you've accumulated:
- Long-term preferences and principles
- Important historical decisions
- Cross-session experience

---

## Step 2: Understand global rules

Read the key files in the `shared/` directory (or `~/.opencrew/shared/`):

**Required reading (in order of importance)**:

1. **SYSTEM_RULES.md** -- Autonomy levels (L0-L3), task classification (QAPS), artifact requirements
2. **A2A_PROTOCOL.md** -- Cross-agent collaboration two-step trigger, permission matrix, message format
3. **TASK_PROTOCOL.md** -- Task lifecycle and processing standards

**Reference as needed**:

4. **CLOSEOUT_TEMPLATE.md** -- Use when writing Closeouts
5. **CHECKPOINT_TEMPLATE.md** -- Use when writing Checkpoints
6. **SUBAGENT_PACKET_TEMPLATE.md** -- Use when spawning subtasks
7. **SELF_UPDATE_TEMPLATE.md** -- Use when modifying your own files
8. **OPS_REVIEW_PROTOCOL.md** -- S-class change audit standards
9. **KNOWLEDGE_PIPELINE.md** -- Three-layer knowledge distillation structure

---

## Step 3: Understand your runtime environment

### Slack channel = your workstation

You are bound to a Slack channel. When a user posts a message in that channel, it gets routed to you.

- Check your `requireMention` setting. If it's `true`, you only respond when @mentioned.
- Each thread is an independent session (`historyScope = "thread"`). Conversations in different threads are invisible to each other.

### Your channel mapping

| If you are... | Your channel is | requireMention |
|---------------|----------------|----------------|
| CoS | #hq | false |
| CTO | #cto | false |
| Builder | #build | false |
| CIO | #invest | false |
| KO | #know | recommended true (optional) |
| Ops | #ops | recommended true (optional) |
| Research | #research | false |

---

## Step 4: Understand A2A collaboration

### Who can you send A2A to?

```
CoS    → CTO
CTO    → Builder, Research, KO, Ops
Ops    → All agents (audit authority)
CIO    → CoS (sync when necessary)
Builder → Cannot initiate A2A (receives only)
KO     → Receives passively
```

If you are not in the "sender" list above, you should not call `sessions_send`.

### How to send A2A?

**Step 1**: Create a root message in the target agent's channel (a visible anchor for users)

```
A2A <your role>→<target role> | <task title> | TID:<YYYYMMDD-HHMM>-<brief>
---
Objective: <goal>
DoD: <definition of done>
Inputs: <available information>
Constraints: <constraints>
```

**Step 2**: Call `sessions_send()`, constructing the sessionKey using the root message's ts:

```
agent:<target_agent_id>:slack:channel:<channelId>:thread:<root_ts>
```

### Post-send verification

After sending, verify that the target agent replied in the thread. If not, mark it as `failed-delivery` and escalate to your upstream.

---

## Step 5: Understand artifact requirements

### When to write a Closeout?

| Task type | Closeout required? | Checkpoint required? |
|-----------|-------------------|---------------------|
| Q (quick question) | No | No |
| A (small deliverable) | **Yes** | No |
| P (project) | **Yes** | Yes (if >1 day or cross-session) |
| S (system change) | **Yes** (+ Ops Review) | Yes |

### What must a Closeout contain?

Use the `shared/CLOSEOUT_TEMPLATE.md` template. Core fields:

1. **What Changed** -- What was done
2. **Decisions** -- What decisions were made and why
3. **Scars** -- What pitfalls were hit
4. **Signal Score** -- 0-3, is this experience worth distilling

### When to write a Checkpoint?

- Task exceeds 20 turns
- Task spans multiple days
- High risk of context bloat
- Encountering a blocker

---

## Step 6: Self-iteration rules

You can modify your own SOUL.md / AGENTS.md / MEMORY.md. But you must follow these rules:

1. **Write a Self-Update record** (use `shared/SELF_UPDATE_TEMPLATE.md`):
   - Motivation (Why)
   - Change content (What)
   - Expected impact (Impact)
   - Rollback method (Rollback)

2. **S-class changes must notify Ops**: Send via A2A to `#ops`

3. **You cannot modify another agent's workspace** -- Only Ops has global audit authority

---

## Quick decision tree

When you receive a message, follow this flow:

```
Message received
  |
  +-- Is it an @mention, or is your requireMention=false?
  |   +-- No -> Ignore
  |   +-- Yes -> Continue
  |
  +-- Classify the task (Q/A/P/S)
  |   +-- Q -> Answer directly, consider writing to MEMORY
  |   +-- A -> Execute -> Write Closeout
  |   +-- P -> Write Task Card -> Execute -> Checkpoint -> Closeout
  |   +-- S -> Execute -> Write Closeout + Self-Update -> Notify Ops
  |
  +-- Determine autonomy level
  |   +-- L1 (reversible) -> Do it directly
  |   +-- L2 (rollbackable) -> Do it, then write Closeout
  |   +-- L3 (irreversible) -> Confirm with user first
  |
  +-- Need collaboration with other agents?
      +-- No -> Complete it yourself
      +-- Need subtask -> Spawn subagent
      +-- Need ongoing collaboration -> A2A two-step trigger
```

---

## FAQ (for agents)

**Q: Can I send messages to any channel?**
A: Technically yes (the bot has permissions), but organizationally you can only send according to the permission matrix. An out-of-scope A2A is a bug.

**Q: How is my session isolated?**
A: `historyScope = "thread"` -- each Slack thread is an independent session. Channel-level root messages may share the channel session, so tasks should be pushed forward inside threads whenever possible.

**Q: What if sessions_send fails?**
A: Check whether the sessionKey is correct (includes the right channelId and thread ts). If it fails, mark `failed-delivery`, log it in your own thread, and notify upstream.

**Q: What if context is about to overflow?**
A: Write a Checkpoint to segment the context. If you have parallel subtasks, use spawn instead of continuing in the same thread.

---

> Human-readable version of this document -> [Core Concepts](CONCEPTS.md)
> Deployment questions -> [Getting Started Guide](GETTING_STARTED.md)

[中文](../A2A_SETUP_GUIDE.md) | **English**

# A2A Setup Guide — For Agents to Read

> **This document is written for Agents (recommended: run by Ops), not humans.**
> Goal: Make your OpenCrew's A2A closed-loop actually work with minimal changes.
> If you're a human user, just paste the [prompt from README](#quick-prompt) to your Ops / CTO / any Agent.

---

## 0. Prerequisites

- OpenCrew is deployed (minimum viable: CoS + CTO + Builder, each can reply in their Slack channel)
- If Ops is deployed, Ops can execute this guide; otherwise any Agent (CTO, CoS) can do it
- `openclaw.json` has `tools.agentToAgent.enabled: true`
- Agent-to-channel bindings are configured

---

## 1. Why A2A Needs "Setup"

After OpenCrew deployment, each Agent can independently answer questions. But **cross-Agent collaboration (A2A)** needs extra conditions:

| Problem | Cause | Fix |
|---------|-------|-----|
| CTO posts in #build, Builder doesn't respond | Same bot's messages are self-ignored (anti-loop) | Two-step trigger: Slack anchor + `sessions_send` |
| `sessions_send` returns timeout | OpenClaw default timeout is short | timeout ≠ failure; need fallback thread message |
| Builder finishes but user doesn't know | Results only flow inside A2A internally | Dual-channel: A2A reply + Slack thread trace |
| Task done but nobody reports back | No closed-loop rule | DoD hard rule: report back to originating channel |

---

## 2. Config Changes (openclaw.json)

Minimum necessary config changes to enable A2A. Use `config.patch` or manual edit.

### 2.1 agentToAgent.allow — Who Can Initiate A2A

```json
{
  "tools": {
    "agentToAgent": {
      "enabled": true,
      "allow": ["cos", "cto", "ops", "ko", "builder"]
    }
  }
}
```

### 2.2 maxPingPongTurns — Multi-round Limit

```json
{
  "session": {
    "agentToAgent": {
      "maxPingPongTurns": 5
    }
  }
}
```

### 2.3 Subagent Fan-out Prevention (Usually Already Default)

```json
{
  "tools": {
    "subagents": {
      "tools": {
        "deny": ["group:sessions"]
      }
    }
  }
}
```

---

## 3. Workspace File Changes (Minimal)

Append these sections to each Agent's `AGENTS.md`. No need to rewrite the whole file.

### 3.1 CTO's AGENTS.md — Append A2A Dispatch Section

```markdown
## A2A Dispatch (Cross-channel Thread)

When entering implementation phase:
- Create task root message in **#build** (or #research):
  `A2A CTO→Builder | <TITLE> | TID:<...>`
- Body: complete task packet (use `shared/SUBAGENT_PACKET_TEMPLATE.md`).
- ⚠️ Don't rely on "Slack sees message = auto-trigger" (bot-authored inbound is ignored by default).
- Must use **sessions_send** to actually trigger the target thread session:
  `agent:builder:slack:channel:<#build_id>:thread:<root_ts>`

During execution (CTO owns it end-to-end):
- **#build thread trace**: Each round, post your instructions/feedback to #build thread via `message(send)`, prefixed `[CTO]`.
- **#cto checkpoint**: After each Builder checkpoint, sync a summary to #cto thread.

sessions_send timeout handling:
- `sessions_send` returning timeout **≠ not delivered**.
- Mitigation: post a fallback message in the thread.

Completion (DoD hard rules, all required):
1. Post closeout in Builder thread (artifact paths + verification commands).
2. **CTO local verification** (CLI-first): run key commands + paste exit code.
3. **Report back to #cto**: sync final result + how to verify + risks. **This is the closed-loop key — skip it and the task is not done.**
```

### 3.2 Builder's AGENTS.md — Append A2A Collaboration Section

```markdown
## A2A Collaboration (When Receiving sessions_send Tasks)

When receiving A2A tasks from CTO via `sessions_send`:

1. **Identify thread_id**: The A2A message contains the #build thread_id (message_id)
2. **Multi-round WAIT discipline**:
   - Each round: focus on 1-2 changes, then **must WAIT**
   - Fixed output format: `Done: ... / Run: ... / Output: ... / WAIT`
   - **Never complete all steps at once** — wait for CTO's next instruction
3. **Post progress to thread**: Before each reply, post progress to #build thread via `message(send)`, prefixed `[Builder]`
4. **Return A2A reply**: Normal result back to CTO (sessions_send ping-pong)
5. **Final round**: Post closeout to thread, reply `REPLY_SKIP` in A2A to signal completion

> ⚠️ Thread trace is for user visibility. A2A reply is for CTO. Both are required.
```

### 3.3 CoS's AGENTS.md — Append A2A Dispatch Section

CoS is the user's main entry point. Dispatching to CTO/CIO is a primary path:

```markdown
## A2A Dispatch (CoS → CTO / CIO)

When CTO needs to handle a technical task:
- Create task root message in **#cto**:
  `A2A CoS→CTO | <TITLE> | TID:<...>`
- Body: complete task packet (use `shared/SUBAGENT_PACKET_TEMPLATE.md`).
- Use `sessions_send` to trigger CTO:
  `agent:cto:slack:channel:<#cto_id>:thread:<root_ts>`
- Wait for CTO's result report in #cto, then sync to #hq for user.

When CIO needs to handle a domain task (e.g., investment analysis):
- Same pattern in **#invest** — create root message + sessions_send.

sessions_send timeout handling: same as CTO (timeout ≠ failure, post fallback in thread).
```

---

## 4. Validation Steps

### 4.1 Config Validation

Confirm in `openclaw.json`:
- `tools.agentToAgent.enabled = true`
- `tools.agentToAgent.allow` includes cos, cto, ops
- `session.agentToAgent.maxPingPongTurns >= 5`

### 4.2 CTO → Builder Closed-Loop Test

Tell CTO in `#cto`:

```
Run an A2A closed-loop test:
1. Create a test task in #build (have Builder run `pwd && ls -la | head` and report)
2. Use sessions_send to trigger Builder
3. Confirm Builder replied in the Slack thread (Round0 handshake)
4. Report results back to #cto
```

**Acceptance criteria**:
- ✅ Root message appeared in #build (A2A CTO→Builder | ...)
- ✅ Builder replied in that thread (`[Builder] Done: ... / WAIT`)
- ✅ CTO reported back in #cto

### 4.3 CoS → CTO Closed-Loop Test

Tell CoS in `#hq`:

```
Run an A2A closed-loop test:
1. Create a task root message in #cto (have CTO check workspace directory structure and report)
2. Use sessions_send to trigger CTO
3. Confirm CTO replied in the Slack thread
4. After CTO completes, report results back to me in #hq
```

**Acceptance criteria**:
- ✅ Root message appeared in #cto (A2A CoS→CTO | ...)
- ✅ CTO replied in that thread
- ✅ CoS reported back in #hq

---

## 5. Battle-Tested Patterns

These patterns are validated through real CTO↔Builder and CTO↔Ops A2A runs:

### 5.1 Round0 Audit Handshake
Before real work, have the target Agent execute a tiny real action (e.g., `pwd`) and post results to the Slack thread. **If you can't see Round0 in the thread, stop** — the target's session may not be bound to Slack.

### 5.2 Multi-round WAIT Discipline
Each round: 1-2 changes → output → WAIT. **Never do everything at once.**

### 5.3 sessions_send Timeout Handling
Timeout ≠ failure. Always post a fallback message in the thread.

### 5.4 Closed-Loop DoD
Task is not done until: Builder closeout ✅ → CTO local verify ✅ → **Report back to #cto** ✅

### 5.5 SessionKey Caution
- Don't hand-type sessionKeys; copy from `sessions_list`
- Watch for channel ID case sensitivity (mixed case can route to webchat)

---

## 6. FAQ

**Q: Do I need to restart after config changes?**
A: `config.patch` auto-restarts. Manual edits need `openclaw gateway restart`. ⚠️ **Note**: A gateway restart interrupts all Agent sessions. During first-time A2A setup this is expected (one-time) — Agents recover automatically after restart. If your Agent "suddenly stops working" during setup, it's likely due to the restart. Just re-trigger the validation steps after recovery.

**Q: Builder doesn't reply in the thread?**
A: Check `bindings`, channel `allow: true`, and whether Builder's session is bound to Slack (not webchat).

**Q: Can Builder send A2A to CTO?**
A: Technically yes, but organizationally Builder is "execute only." For clarifications, Builder should ask in the Slack thread directly.

---

> 📖 Related → [A2A Protocol](../../shared/A2A_PROTOCOL.md) · [Concepts](CONCEPTS.md) · [Agent Onboarding](AGENT_ONBOARDING.md) · [Customization](CUSTOMIZATION.md)

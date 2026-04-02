# Research: Autonomous Multi-Bot Slack Collaboration

> Researcher: Claude Opus 4.6 | Date: 2026-03-27 | Scope: Can multiple independent Slack bots autonomously drive a multi-round discussion without human intervention at every step?

---

## Executive Summary

**Yes, this is technically feasible -- but with significant caveats.**

Multiple independent Slack Apps (each running as a separate bot with its own token, app token, and bot user ID), all present in the same Slack channel/thread, can autonomously drive a multi-round discussion without human intervention at every step. The architecture requires:

1. **OpenClaw multi-account mode** (`channels.slack.accounts`) -- one Slack App per participating agent, all managed by a single OpenClaw gateway instance.
2. **`allowBots: true` + `requireMention: true`** on shared channels -- this allows bots to see each other's messages while preventing uncontrolled loops.
3. **An orchestrator agent (e.g., CTO)** whose AGENTS.md/SOUL.md instructs it to drive discussions by @mentioning other agents using Slack's `<@BOT_USER_ID>` format.
4. **A soft turn limit** enforced by agent instructions (not system-level enforcement for Discussion mode).

**Critical finding**: OpenClaw's self-loop filter on Slack is **per-bot-user-ID**, not global. In multi-account mode, Bot-CTO's messages are NOT filtered by Bot-Builder's handler because they have different bot user IDs. This is the key enabler. However, this behavior was the subject of bug fixes (Issue #15836, fixed via PRs #15863/#15946 with session origin tracking), confirming that the current codebase intentionally supports inter-agent message routing.

**Confidence level**: MEDIUM-HIGH for Architecture A (single gateway, multi-account). The primitives all exist and are documented. No end-to-end production validation of fully autonomous (zero human intervention) multi-round discussions has been publicly reported.

---

## 1. Architecture Comparison

### 1a. Single Gateway Multi-Account (Architecture A) -- RECOMMENDED

**How it works**: One OpenClaw gateway instance manages multiple Slack Apps via `channels.slack.accounts`. Each agent is bound to its specific account via `bindings[].match.accountId`.

```json
{
  "channels": {
    "slack": {
      "accounts": {
        "default": { "botToken": "xoxb-cos-...", "appToken": "xapp-cos-..." },
        "cto":     { "botToken": "xoxb-cto-...", "appToken": "xapp-cto-..." },
        "builder": { "botToken": "xoxb-bld-...", "appToken": "xapp-bld-..." }
      },
      "channels": {
        "<COLLAB_CHANNEL_ID>": {
          "allow": true,
          "requireMention": true,
          "allowBots": true
        }
      },
      "thread": {
        "historyScope": "thread",
        "inheritParent": true,
        "initialHistoryLimit": 50
      }
    }
  },
  "bindings": [
    { "agentId": "cos",     "match": { "channel": "slack", "accountId": "default" } },
    { "agentId": "cto",     "match": { "channel": "slack", "accountId": "cto" } },
    { "agentId": "builder", "match": { "channel": "slack", "accountId": "builder" } }
  ]
}
```

**When Bot-CTO posts in a shared channel, does Bot-Builder's agent receive it?**

Yes, under these conditions:
- `allowBots: true` on the channel -- without this, all bot messages are ignored.
- The message must @mention Bot-Builder (`<@BUILDER_BOT_USER_ID>`) if `requireMention: true` is set.
- OpenClaw's self-loop filter only blocks messages from the **same** bot user ID. Since Bot-CTO and Bot-Builder have different user IDs, Bot-CTO's messages pass through Bot-Builder's filter.

**What does `allowBots: true` actually do?**

At the code level, `allowBots` controls whether the OpenClaw Slack plugin processes messages with the `bot_message` subtype (or messages where `message.bot_id` is set). Three behaviors:

| Value | Behavior |
|-------|----------|
| `false` (default) | All bot-authored messages are dropped before reaching agent routing. This is the current OpenCrew default. |
| `true` | All bot-authored messages are accepted as inbound. Combined with `requireMention: true`, only messages that @mention the receiving bot are processed. |
| `"mentions"` | Bot messages are accepted **only** if they contain an @mention of the receiving bot. This is functionally equivalent to `true` + `requireMention: true` but applies specifically to bot messages. (Confidence: MEDIUM -- referenced in source-level analysis and community reports but not prominently featured in official docs.) |

**Self-loop filter mechanics**: OpenClaw checks `message.user === account.botUserId`. With multi-account, each account has a distinct `botUserId`, so Bot-CTO's messages (`user = U_CTO`) are not filtered by Bot-Builder's handler (which only filters `user = U_BUILDER`). This was confirmed by Issue #15836's fix (PRs #15863/#15946), which added session origin tracking to refine the filtering -- the fix allows routing bot messages to bound sessions EXCEPT the originating session.

**Advantages**:
- Single process, single config, centralized management
- All session keys, A2A tools, and routing work within one gateway
- Existing OpenCrew A2A protocol (sessions_send) and Discussion mode (@mention) coexist
- Official OpenClaw documentation and community guides describe this exact pattern

**Disadvantages**:
- Requires creating 3-7 separate Slack Apps (one per participating agent)
- All agents share one process -- if the gateway crashes, all agents go down
- Socket Mode: 3-7 persistent WebSocket connections from one process (OpenClaw docs recommend HTTP mode with distinct `webhookPath` per account for multi-account setups)

### 1b. Multiple Independent Instances (Architecture B)

**How it works**: Each agent runs its own OpenClaw gateway instance (separate process, separate `openclaw.json`). Each connects to Slack with its own App. They share a Slack channel.

**Is this possible?** Technically yes, but with major complications:

- Each OpenClaw instance would need its own `openclaw.json` with one agent definition.
- The `allowBots: true` + `requireMention: true` pattern works the same way on each instance -- each instance's self-loop filter only blocks its own bot user ID.
- Slack delivers events to all subscribed apps regardless of which instance runs them.

**Problems**:
- **No shared A2A infrastructure**: `sessions_send` cannot cross process boundaries. The orchestrator agent cannot use OpenClaw's built-in A2A tools to trigger other agents -- it can only @mention them in Slack and hope the other instance processes the mention.
- **No shared session management**: Each instance tracks sessions independently. There is no coordination, no shared `maxPingPongTurns`, no shared session keys.
- **Operational complexity**: 3-7 separate processes, configs, logs, restarts.
- **No unified routing**: Each instance independently processes all incoming messages from its channel. Binding isolation must be configured per-instance.

**Verdict**: Architecture B is technically possible but provides no advantage over Architecture A while adding significant complexity. The only real advantage would be complete process isolation (one crash does not affect others), which is a minor benefit compared to the operational cost.

### 1c. Recommendation

**Architecture A (single gateway, multi-account) is clearly superior.** It leverages OpenClaw's built-in multi-account routing, keeps all A2A infrastructure unified, and is the pattern documented by OpenClaw's official docs and community guides. All subsequent sections assume Architecture A.

---

## 2. Autonomous Orchestration Mechanics

### Event Flow

Here is the complete event flow for an autonomous multi-round discussion:

```
SETUP: Human starts a thread in #collab
  "Let's discuss the architecture for feature X. @CTO please kick off."

ROUND 1: CTO responds (triggered by human's @mention)
  CTO reads thread history, proposes architecture.
  CTO's response includes: "<@BUILDER_BOT_USER_ID> please review feasibility."

  Event flow:
  1. CTO agent produces response text containing <@U_BUILDER>
  2. OpenClaw's Slack plugin posts this as Bot-CTO in the thread
  3. Slack Events API delivers message event to ALL subscribed apps in the channel
  4. Bot-Builder's app receives the message event
  5. OpenClaw checks: is this from a bot? Yes. Is allowBots enabled? Yes.
  6. OpenClaw checks: is this from OUR bot user ID? No (U_CTO != U_BUILDER). Pass.
  7. OpenClaw checks: does this message @mention our bot? Yes (<@U_BUILDER>). Pass.
  8. OpenClaw routes to Builder agent (matched by accountId binding)
  9. Builder agent's session is created/resumed for this thread

ROUND 2: Builder responds (triggered by CTO's @mention)
  Builder reads thread history (sees human's prompt + CTO's proposal).
  Builder posts feasibility analysis.
  Builder does NOT @mention anyone (it's not an orchestrator).

ROUND 3: CTO sees Builder's response (how?)
  THIS IS THE CRITICAL QUESTION.

  Option A -- CTO is also listening via allowBots:
    If CTO's channel config has allowBots: true + requireMention: true,
    CTO only activates when explicitly @mentioned.
    Builder's response does NOT @mention CTO, so CTO does NOT auto-activate.
    --> PROBLEM: CTO cannot autonomously continue the discussion.

  Option B -- CTO uses requireMention: false on the shared channel:
    CTO activates on ALL messages in the thread (including Builder's).
    --> PROBLEM: Every bot activates on every message --> infinite loop.

  Option C -- CTO is the orchestrator with special config:
    CTO's binding for #collab has allowBots: true + requireMention: false.
    All OTHER agents have allowBots: true + requireMention: true.
    CTO sees all messages. Others only respond when @mentioned.
    --> THIS IS THE KEY ARCHITECTURE INSIGHT.

  Option D -- Builder @mentions CTO back:
    Builder's AGENTS.md instructs: "After responding, @mention the
    orchestrator: <@U_CTO> I've posted my analysis."
    --> Works but creates a tight loop. Needs turn counting.
```

### The Orchestrator Pattern (Option C -- Recommended)

The orchestrator agent (CTO) needs a **different configuration** from other agents on the shared channel:

```json
{
  "channels": {
    "slack": {
      "channels": {
        "<COLLAB_CHANNEL_ID>": {
          "allow": true,
          "requireMention": true,
          "allowBots": true
        }
      }
    }
  }
}
```

**The problem**: OpenClaw's `channels.slack.channels` config is **global across all agents** in the same gateway instance. You cannot set `requireMention: false` for CTO and `requireMention: true` for Builder on the same channel in the same `openclaw.json`.

**Workarounds**:

1. **Option D (Explicit @mention-back)**: Builder's instructions say "always end your response with `<@U_CTO>`". This triggers CTO to read the thread and decide the next step. This is the simplest approach and works within existing config constraints.

2. **Per-account channel overrides**: If OpenClaw supports per-account channel configuration (e.g., `accounts.cto.channels.<ID>.requireMention = false`), this would solve it cleanly. **Status: UNVERIFIED** -- the official docs mention that "named accounts inherit from global config but can override any setting," but whether per-account `channels` overrides are supported at the channel level is not confirmed.

3. **Dedicated orchestrator channel**: The orchestrator monitors its own dedicated channel (#cto) where `requireMention: false`. Other agents post summaries to #cto after responding in #collab. This fragments the discussion across channels, which is undesirable.

4. **Hybrid: @mention + sessions_send**: Builder @mentions CTO in the thread AND does a `sessions_send` to CTO's session. This provides both visibility and a reliable trigger. But Builder needs `agentToAgent.allow` permission, which current config restricts.

### @mention Rendering

**Can an agent produce `<@BOT_USER_ID>` in its Slack message, and does it render as a proper mention?**

Yes. When an agent's response text contains `<@U0XXXXX>`, OpenClaw's Slack plugin posts this verbatim to Slack. Slack's rendering engine converts `<@U0XXXXX>` into a clickable @mention with the bot's display name. This is standard Slack message formatting -- there is nothing special about bot-authored messages vs human-authored messages in this regard.

**Does the mentioned bot receive an event?**

The `app_mention` event documentation does not explicitly confirm or deny whether bot-authored mentions trigger `app_mention` for the mentioned app. However, OpenClaw's Slack plugin primarily listens on `message.channels` events (not just `app_mention`), which delivers ALL messages in channels the bot has joined, regardless of sender. OpenClaw then applies its own mention-detection logic by parsing the message text for `<@botUserId>` patterns. Therefore:

- Bot-CTO posts `<@U_BUILDER> review this` in #collab thread
- Bot-Builder's app receives the `message.channels` event (Slack delivers all channel messages to all member apps)
- OpenClaw checks `allowBots: true` -- pass
- OpenClaw checks `requireMention: true` -- scans message text for `<@U_BUILDER>` -- found -- pass
- Message is routed to Builder agent

**Confidence: HIGH** that this works. The `message.channels` subscription is the primary event listener, and OpenClaw's mention detection is text-based parsing of `<@userId>`, not reliance on Slack's `app_mention` event type.

### Binding/Routing with Multiple Accounts

With multi-account, routing uses the binding specificity hierarchy:

1. Peer match (exact channel ID)
2. Account ID match
3. Channel-level match
4. Fallback to default

When a message arrives on a Slack account (e.g., the "cto" account receives an event), OpenClaw matches it against bindings. The binding `{ "agentId": "cto", "match": { "channel": "slack", "accountId": "cto" } }` routes all messages received by the CTO's Slack app to the CTO agent.

**Key insight**: In multi-account mode, each Slack app independently receives events. The OpenClaw gateway maintains separate Socket Mode connections for each account. When Bot-CTO posts a message, Bot-Builder's Slack app independently receives the event via its own connection. OpenClaw processes each account's events through its own binding chain.

---

## 3. Loop Prevention

### Available Mechanisms

| Mechanism | Type | Scope | Enforcement |
|-----------|------|-------|-------------|
| `requireMention: true` | Config | Per-channel, global | System-enforced by OpenClaw |
| `allowBots: false` | Config | Per-channel, global | System-enforced -- blocks all bot messages |
| `allowBots: "mentions"` | Config | Per-channel, global | System-enforced -- bot messages only when bot is mentioned |
| `maxPingPongTurns` (0-5) | Config | Per A2A `sessions_send` | System-enforced by OpenClaw session manager |
| `maxTurns` (default: 80) | Config | Per agent session | System-enforced -- max model calls per session |
| `timeoutSeconds` (default: 172800) | Config | Per agent | System-enforced -- 48-hour abort timer |
| `maxDiscussionTurns` | Protocol | Per discussion thread | Agent-self-enforced via AGENTS.md instructions |
| Self-loop filter | Code | Per bot user ID | System-enforced -- ignores own messages |
| Permission matrix | Protocol | Per agent role | Agent-self-enforced via SOUL.md/AGENTS.md |
| Agent instructions (WAIT discipline) | Protocol | Per agent | Agent-self-enforced |

### What Applies to Autonomous Discussion?

**`maxPingPongTurns` does NOT directly apply** to @mention-driven discussions. This parameter governs the `sessions_send` reply-back loop specifically. In Discussion mode, there is no `sessions_send` -- agents respond to @mentions in Slack threads. The ping-pong counter is not incremented.

**`maxTurns` provides a backstop** but is too coarse. At 80 turns per session, an agent could send many messages before hitting this limit.

**`requireMention: true` is the primary loop breaker.** If all agents require mentions, and agents only @mention the next speaker (never broadcasting), then:
- Agent responds only when mentioned
- Agent mentions at most one other agent
- That other agent responds, mentions the orchestrator back
- Orchestrator decides next step

This creates a **controlled chain**, not an unbounded loop. The chain only continues as long as the orchestrator keeps @mentioning agents.

### Recommended Approach: Multi-Layer Defense

**Layer 1 -- Config-enforced (reliable)**:
- `requireMention: true` on ALL agents in shared channels
- `allowBots: true` (or `"mentions"`) on shared channels only
- `maxTurns` per agent as an absolute backstop (e.g., 20 for discussion participants)
- Agent-specific `timeoutSeconds` (e.g., 600 for discussion sessions)

**Layer 2 -- Protocol-enforced (agent instructions)**:
- Orchestrator AGENTS.md: "You may run at most `MAX_ROUNDS` discussion rounds. After `MAX_ROUNDS`, you MUST post `DISCUSSION_CLOSE` and stop @mentioning other agents."
- Participant AGENTS.md: "You ONLY respond when @mentioned. You NEVER @mention another agent unless explicitly instructed. After responding, you STOP."
- Exception: The `@mention-back` pattern where participants mention the orchestrator after responding. This is controlled because only the orchestrator decides whether to continue.

**Layer 3 -- External monitoring**:
- A cron job or heartbeat that checks thread message count and kills sessions if a thread exceeds N messages.
- Ops agent periodic audit of thread lengths.

### The "47 replies in 12 seconds" Cautionary Tale

A production incident documented by the community: enabling `allowBots: true` without `requireMention: true` in a channel with another AI bot caused 47 replies in 12 seconds before manual process kill. This underscores that `requireMention: true` is **non-negotiable** when `allowBots` is enabled.

---

## 4. Implementation Path

### 4.1 Config Changes

**Step 1: Create Slack Apps** (human-manual, one-time)

Create one Slack App per participating agent. Minimum 3 (CoS, CTO, Builder). Each app needs:
- Socket Mode enabled
- App-Level Token (`xapp-`) with `connections:write` scope
- Bot Token (`xoxb-`) with scopes: `channels:history`, `channels:read`, `chat:write`, `users:read`, `reactions:read`, `reactions:write`
- Event Subscriptions: `message.channels`, `app_mention`
- Bot user configured with distinct name and icon

**Step 2: Create shared discussion channel** (human-manual)

Create `#collab` (or similar). Invite ALL agent bots to this channel.

**Step 3: Update openclaw.json** (agent-executable)

Add multi-account config:
```json
{
  "channels": {
    "slack": {
      "accounts": {
        "default": { "botToken": "xoxb-cos-...", "appToken": "xapp-cos-...", "name": "CoS" },
        "cto":     { "botToken": "xoxb-cto-...", "appToken": "xapp-cto-...", "name": "CTO" },
        "builder": { "botToken": "xoxb-bld-...", "appToken": "xapp-bld-...", "name": "Builder" }
      },
      "channels": {
        "<COLLAB_CHANNEL_ID>": {
          "allow": true,
          "requireMention": true,
          "allowBots": true
        }
      },
      "thread": {
        "historyScope": "thread",
        "inheritParent": true,
        "initialHistoryLimit": 50
      }
    }
  },
  "bindings": [
    { "agentId": "cos",     "match": { "channel": "slack", "accountId": "default" } },
    { "agentId": "cto",     "match": { "channel": "slack", "accountId": "cto" } },
    { "agentId": "builder", "match": { "channel": "slack", "accountId": "builder" } }
  ]
}
```

Keep existing per-agent channel bindings (each agent's dedicated channel stays `requireMention: false`, `allowBots: false`).

**Step 4: Record bot user IDs** (agent-executable)

For each Slack App, obtain the Bot User ID (e.g., `U0CTO1234`, `U0BLD5678`). These are needed in agent instructions for @mention formatting.

### 4.2 Agent Instructions

**CTO AGENTS.md -- Add Orchestrator Section**:

```markdown
## Discussion Orchestration (Multi-Agent Threads in #collab)

When driving a multi-agent discussion in #collab:

### Setup
- You are the ORCHESTRATOR. You control who speaks next.
- Bot User IDs: CTO=<@U_CTO>, Builder=<@U_BUILDER>, CoS=<@U_COS>
- Maximum rounds: 5. After 5 rounds, you MUST close the discussion.

### Each Round
1. Read the full thread history (all prior messages)
2. Analyze the latest response
3. Decide: (a) Ask another agent for input, (b) Ask the same agent to clarify, (c) Close discussion
4. If continuing: Post your analysis + @mention the next agent
   Format: "[CTO] <your analysis>. <@U_NEXT_AGENT> <your question/request>"
5. If closing: Post DISCUSSION_CLOSE summary

### Round Counting
- Maintain a round counter in your responses: "Round N/5"
- After Round 5, you MUST close regardless of convergence

### DISCUSSION_CLOSE Format
```
DISCUSSION_CLOSE
Topic: <topic>
Rounds: N/5
Consensus: <achieved | not achieved>
Decision: <what was decided>
Actions: <next steps, including any A2A delegation tasks>
Participants: CTO, Builder, ...
```

### Safety Rules
- NEVER @mention more than one agent per message
- NEVER skip round counting
- If you receive a response that is clearly a loop (repeating prior content), immediately close
```

**Builder AGENTS.md -- Add Discussion Participant Section**:

```markdown
## Discussion Participation (Multi-Agent Threads in #collab)

When @mentioned in a #collab discussion thread:

1. Read the full thread history
2. Respond from your domain perspective (feasibility, implementation, effort)
3. End your response with: "<@U_CTO> I've posted my analysis."
   (This notifies the orchestrator to continue the discussion)
4. Do NOT @mention any agent other than the orchestrator (<@U_CTO>)
5. Do NOT continue working after posting -- WAIT for the next @mention
6. If you have nothing to add: respond "[Builder] PASS: <reason>"
```

**CoS AGENTS.md -- Similar participant pattern, mentioning CTO back after responding.**

### 4.3 The @Mention-Back Problem and Solutions

The fundamental challenge is: **how does the orchestrator know when a participant has responded?**

**Solution 1 -- Participant @mentions orchestrator back** (Recommended):
- Participant ends response with `<@U_CTO>`
- CTO receives the `message.channels` event with its mention
- CTO reads thread, continues orchestration
- Pro: Simple, works within existing config
- Con: CTO activates on every participant response, even partial ones

**Solution 2 -- Orchestrator polls thread** (Not recommended):
- CTO uses a timer/heartbeat to periodically check the thread
- Pro: No mention-back needed
- Con: OpenClaw agents don't have native polling/timer capabilities for thread monitoring

**Solution 3 -- Hybrid: @mention-back + sessions_send**:
- Participant @mentions CTO AND does sessions_send to CTO's session
- Pro: Belt-and-suspenders reliability
- Con: Requires Builder to have sessions_send permission (currently restricted)

**Solution 1 is recommended** as the simplest path that works within existing constraints.

### 4.4 Failure Modes

| Failure Mode | Cause | Mitigation |
|-------------|-------|------------|
| **Infinite loop** | Agent A mentions Agent B mentions Agent A... | `requireMention: true` + only orchestrator decides next speaker + round counter |
| **Silent failure** | Agent doesn't respond to @mention | Orchestrator waits N seconds, then posts "ping" + re-mentions. After 2 failures, closes discussion. |
| **Context overflow** | Thread gets too long for `initialHistoryLimit` | Set `initialHistoryLimit >= 50`. Instruct agents to keep responses under 500 words. |
| **Wrong agent responds** | Binding misconfiguration | Test with Round0 handshake before production discussions. |
| **All agents respond simultaneously** | `requireMention: false` accidentally set | Config audit: `requireMention: true` on ALL shared channels. |
| **Orchestrator never closes** | Round counter not maintained | `maxTurns` per session as absolute backstop. External monitoring. |
| **Bot mentions not parsed** | Agent outputs `@Builder` instead of `<@U_BUILDER>` | AGENTS.md must contain exact bot user IDs, not display names. |
| **Self-loop filter blocks legitimate messages** | OpenClaw bug / regression | Monitor Issue #15836 fix status. Test with Round0 handshake. |
| **Socket Mode connection limits** | 5-7 WebSocket connections from one process | OpenClaw docs recommend HTTP mode for multi-account. Test Socket Mode first; switch to HTTP if stability issues arise. |
| **Gateway crash kills all agents** | Single process architecture | Standard process management (systemd, pm2). Restart automatically. |

---

## 5. Comparison with Claude Code Agent Teams

| Dimension | Claude Code Agent Teams | OpenCrew Slack Discussion |
|-----------|------------------------|--------------------------|
| **Communication** | Mailbox system (in-memory message passing) | Slack thread messages |
| **Shared state** | Task list files (`~/.claude/tasks/`) | Thread history (via `initialHistoryLimit`) |
| **Orchestration** | Lead agent creates team, assigns tasks | CTO/CoS @mentions agents in thread |
| **Context** | Each teammate has own context window | Each agent has own session (thread-scoped) |
| **Human visibility** | Terminal output, requires split-pane/tmux | Slack UI -- real-time, mobile, searchable |
| **Turn control** | Task completion triggers, idle hooks | @mention triggers, round counter in instructions |
| **Loop prevention** | Task dependency system, lead controls | `requireMention` + round counter + `maxTurns` |
| **Persistence** | Session-scoped (lost on restart) | Slack thread history (persists, searchable) |
| **Cost model** | Token-based, per context window | Token-based + Slack API calls |
| **Inter-agent debate** | Teammates message each other directly, challenge findings | Agents @mention each other, challenge in shared thread |

**Key parallel**: Both systems use an orchestrator that decides task decomposition and agent assignment. Both allow agents to challenge each other. Both have context isolation per agent.

**Key difference**: Claude Code Agent Teams use file-based task lists for coordination and in-memory mailboxes for messages. OpenCrew uses Slack threads as both the communication channel and the shared context. The Slack approach provides superior human visibility but higher latency (~1-3s per message vs near-zero for file I/O).

**Mapping to OpenCrew**:
- **Team lead** = CTO (or CoS for strategic discussions)
- **Teammates** = Builder, CIO, Ops (responding when called)
- **Task list** = The orchestrator's round-by-round plan (maintained in agent instructions, not a shared file)
- **Mailbox** = @mentions in the Slack thread
- **Shared resources** = Thread history (`initialHistoryLimit`)

---

## 6. Confidence Assessment

| Finding | Confidence | Evidence |
|---------|-----------|---------|
| Slack Events API delivers Bot-A's messages to Bot-B's app | **HIGH** | Slack API docs: apps receive `message.channels` for all messages in joined channels. No sender-type filtering at platform level. |
| OpenClaw multi-account supports separate bot tokens per agent | **HIGH** | Official docs (`channels.slack.accounts`), community gist, tutorial sites all confirm. |
| Self-loop filter is per-bot-user-ID in multi-account mode | **HIGH** | Issue #15836 confirms the filter checks `message.user === botUserId`. Fix (PRs #15863/#15946) added origin tracking to refine this. |
| `allowBots: true` enables processing of other bots' messages | **HIGH** | Official docs, community guide, production incident report (47 replies in 12s) all confirm. |
| `requireMention: true` prevents uncontrolled bot loops | **HIGH** | Official docs explicitly recommend this combination. Community confirms. |
| Agent can produce `<@BOT_USER_ID>` and it renders as a mention | **HIGH** | Standard Slack message formatting. No special handling needed for bot-authored messages. |
| OpenClaw parses `<@userId>` in message text for mention detection | **HIGH** | Official docs: "Mention sources: explicit app mention (`<@botId>`), mention regex patterns." |
| Autonomous multi-round discussion without ANY human intervention | **MEDIUM** | All primitives verified. The @mention-back pattern (participant mentions orchestrator) is the key mechanism. Not yet validated end-to-end in production. |
| `allowBots: "mentions"` as a third option beyond true/false | **MEDIUM** | Referenced in source-level analysis (DeepWiki) and prior research. Not prominently in official docs. |
| Per-account channel overrides (different `requireMention` per bot) | **LOW** | Docs say "named accounts can override any setting" but don't explicitly show per-account `channels.<ID>` overrides. Unverified. |
| `maxPingPongTurns` applies to @mention-driven discussions | **LOW (likely NO)** | This parameter governs `sessions_send` reply-back loops specifically, not @mention-driven thread interactions. |

---

## 7. Open Questions

1. **Per-account channel config**: Can `channels.slack.accounts.cto.channels.<COLLAB_ID>.requireMention` be set to `false` while keeping the global `channels.slack.channels.<COLLAB_ID>.requireMention = true`? This would allow the orchestrator to see all messages without requiring @mention-back. Needs empirical testing against OpenClaw source.

2. **app_mention vs message.channels**: The Slack docs do not explicitly confirm whether `app_mention` events fire when a bot (not a human) mentions another bot. OpenClaw's primary listener is `message.channels` with text-based mention parsing, so this likely doesn't matter -- but confirmation would increase confidence.

3. **Socket Mode scalability**: With 5-7 Slack Apps all using Socket Mode, what is the resource impact on the OpenClaw gateway? Are there Slack-side rate limits on concurrent WebSocket connections from the same server? OpenClaw docs recommend HTTP mode for multi-account -- is this a strong recommendation or just an option?

4. **Thread history limits**: When `initialHistoryLimit = 50` and a discussion spans 30+ messages, does each agent see the FULL 30 messages or only the last 50? Does the limit count thread messages or include parent channel context? This determines whether agents can maintain discussion continuity.

5. **Concurrent @mentions**: What happens if the orchestrator @mentions two agents simultaneously in one message (e.g., `<@U_BUILDER> and <@U_OPS> please review`)? Do both agents respond? In what order? Can this cause race conditions in the thread?

6. **Discussion session lifecycle**: When does a thread-scoped session expire? If a discussion spans hours (with gaps between rounds), does the session survive? Does each @mention create a new session or resume the existing one?

7. **Cost estimation**: Each discussion round involves: (a) agent reading full thread history, (b) agent producing a response, (c) OpenClaw posting to Slack. For a 5-round discussion with 3 agents, how many API tokens are consumed? Is this comparable to Claude Code Agent Teams or significantly more/less?

8. **Empirical validation**: Nobody has publicly documented a fully autonomous (zero human intervention after initial prompt) multi-round OpenCrew discussion. The first implementation should be treated as an experiment with careful monitoring.

---

## Appendix A: Step-by-Step Validation Plan

Before deploying autonomous discussions, validate each component:

**Test 1: Multi-account basic message delivery**
- Configure 2 accounts (CTO + Builder) on a shared channel
- Human @mentions CTO in a thread
- Verify CTO responds
- CTO's response includes `<@U_BUILDER>`
- Verify Builder receives the event and responds
- Expected: Both agents respond in the same thread

**Test 2: @mention-back pattern**
- Builder's response includes `<@U_CTO>`
- Verify CTO receives Builder's message and can read thread history
- Expected: CTO sees all prior messages and can continue

**Test 3: Round counter enforcement**
- Set max rounds to 3 in CTO's AGENTS.md
- Start a discussion
- Verify CTO closes discussion after round 3 with DISCUSSION_CLOSE
- Expected: Discussion terminates cleanly

**Test 4: Loop prevention**
- Remove round counter from CTO's instructions (dangerous -- test in isolated channel)
- Start a discussion
- Verify `maxTurns` per session catches any runaway loop
- Expected: Session terminates at maxTurns limit

**Test 5: Failure recovery**
- Start a discussion, then manually kill Builder's session mid-discussion
- Verify CTO detects non-response and closes or escalates
- Expected: CTO posts timeout message and either retries or closes

---

## Appendix B: Key References

- [OpenClaw Slack Plugin Docs](https://docs.openclaw.ai/channels/slack)
- [OpenClaw Multi-Agent Routing Docs](https://docs.openclaw.ai/concepts/multi-agent)
- [OpenClaw Session Tools Docs](https://docs.openclaw.ai/concepts/session-tool)
- [OpenClaw Agent Loop Docs](https://docs.openclaw.ai/concepts/agent-loop)
- [Running Multiple AI Agents as Slack Teammates (GitHub Gist)](https://gist.github.com/rafaelquintanilha/9ca5ae6173cd0682026754cfefe26d3f)
- [OpenClaw Issue #15836: Agent-to-agent Slack routing (FIXED)](https://github.com/openclaw/openclaw/issues/15836)
- [OpenClaw Issue #11199: Discord multi-bot filtering (FIXED)](https://github.com/openclaw/openclaw/issues/11199)
- [OpenClaw Issue #45450: Matrix bot-to-bot visibility](https://github.com/openclaw/openclaw/issues/45450)
- [OpenClaw Issue #9912: maxTurns/maxToolCalls config](https://github.com/openclaw/openclaw/issues/9912)
- [OpenClaw Slack Setup Best Practices (Macaron)](https://macaron.im/blog/openclaw-slack-setup)
- [Claude Code Agent Teams Documentation](https://code.claude.com/docs/en/agent-teams)
- [Slack Events API Documentation](https://docs.slack.dev/apis/events-api/)
- [Slack Message Event Reference](https://docs.slack.dev/reference/events/message/)
- [Slack app_mention Event Reference](https://docs.slack.dev/reference/events/app_mention)
- [Prior OpenCrew Research: research_slack_r1.md](.harness/reports/research_slack_r1.md)
- [Prior OpenCrew Architecture: architecture_protocol_r1.md](.harness/reports/architecture_protocol_r1.md)
- [Prior OpenCrew Architecture: architecture_collab_r1.md](.harness/reports/architecture_collab_r1.md)

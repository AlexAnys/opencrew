# Research: Selective Independent Agents Architecture

> Researcher: Claude Opus 4.6 | Date: 2026-03-27 | Scope: Three architectural questions -- orchestrator role, hybrid bot architecture, instance vs workspace independence

---

## Executive Summary

**Question 1 (Orchestrator)**: CoS is the correct orchestrator, not CTO. In Anthropic's Harness Design, the orchestrator is an **external script** (not a participant agent). In OpenCrew's Slack-native context, CoS maps most naturally to this role: it represents the user's intent, drives strategy forward, and does not do execution work. CTO should be a Generator/participant, not the orchestrator.

**Question 2 (Hybrid Architecture)**: The proposed hybrid model -- single bot for execution agents + independent CoS bot + independent QA bot -- is technically feasible within a single OpenClaw gateway using multi-account mode. The key insight: one account CAN serve multiple agents via peer binding (channel-to-agent), while other accounts each serve one agent via account binding. Two bots CAN coexist in the same channel when `allowBots: true` + `requireMention: true` is set. The @mention-back flow works without changing existing channel configs, provided `allowBots: true` is added to channels where cross-bot interaction is needed.

**Question 3 (Instance vs Workspace)**: A single OpenClaw gateway with multi-account is strongly recommended over separate instances. Multi-account means multiple Slack Apps managed by one gateway process. This preserves `sessions_send` interoperability, shared config, and single-process management. Separate instances would break A2A tools across process boundaries.

---

## 1. Orchestration: CoS vs CTO vs External Harness

### Anthropic Harness Design Analysis

The Anthropic Harness Design methodology (as implemented in Claude Code Agent Teams and documented in the harness-design skill) follows a clear separation:

| Component | Role | Is an Agent? |
|-----------|------|--------------|
| **Harness** (script) | Orchestrator -- decides what runs next, parses outputs, manages flow | NO -- it is external code |
| **Planner** | Analyzes requirements, produces spec/plan | YES -- spawned by harness |
| **Builder/Generator** | Executes the plan, produces artifacts | YES -- spawned by harness |
| **QA/Evaluator** | Reviews outputs, challenges quality, catches issues | YES -- spawned by harness |

Key architectural principle: **No single agent is both a participant AND the orchestrator.** The harness is not an LLM agent -- it is a deterministic script that reads outputs and decides the next step. This prevents:
- Orchestrator bias (an agent-orchestrator favors its own perspective)
- Context pollution (orchestration logic competes with domain reasoning)
- Role confusion (is the agent thinking about the problem or about who to call next?)

### Mapping to OpenCrew Roles

The current A2A_PROTOCOL.md and architecture_collab_r1.md designate CTO as the discussion orchestrator for technical discussions. But this creates a problem identified in the Harness Design:

**CTO as orchestrator = CTO is both participant and controller.** When CTO drives an architecture review, it is simultaneously:
1. Proposing the technical approach (Generator role)
2. Deciding who speaks next (Orchestrator role)
3. Evaluating Builder's response (Evaluator role)

This triple-hat violates the Harness Design's core separation. CTO's technical opinions will bias which agents it calls and how it frames questions.

**CoS maps naturally to the Harness's orchestrator role:**

| Harness Concept | CoS Mapping | Evidence |
|----------------|-------------|---------|
| External to generation | CoS does NOT do technical implementation | SOUL.md: "you are not a gateway, not a doer" |
| Represents user intent | CoS's core role is "deep intent alignment" | SOUL.md: "strategic partner who drives things forward when user is away" |
| Decides what runs next | CoS determines priorities and delegation | AGENTS.md: "strategic tradeoff + pacing + coordination" |
| Reads outputs, routes decisions | CoS synthesizes and routes to CTO/CIO | ARCHITECTURE.md: "CoS evaluates/delegates to CTO/CIO" |
| Does not participate in generation | CoS does not write code, do research, or build | SOUL.md: "push main thread, lower cognitive load" |

The user's insight is correct: CoS's SOUL.md description -- "strategic partner who drives things forward when the user is away" -- is almost word-for-word the harness's role description.

**But CoS is not a pure external script -- it is an LLM agent.** This is a key difference from the Harness Design. In OpenCrew's Slack-native architecture, a non-agent orchestrator would be a Slack bot with hardcoded routing logic, which loses the strategic judgment that makes CoS valuable. The pragmatic solution: CoS acts as orchestrator but with strict role discipline:

- CoS **decides** who to engage and what to ask (orchestrator hat)
- CoS **does not** propose technical solutions or challenge technical details (no generator/evaluator hat)
- CoS **synthesizes** outcomes and aligns with user intent (unique CoS value-add)

### Recommendation

**CoS should be the orchestrator. CTO should be a participant/generator.**

This means:
1. **Discussion mode**: CoS @mentions CTO, Builder, CIO as needed. CTO responds with technical input but does not decide who speaks next.
2. **Delegation mode**: CoS delegates to CTO via A2A. CTO then orchestrates within its execution scope (CTO-to-Builder), which is fine -- this is scoped orchestration of subordinates, not strategic orchestration.
3. **QA as independent evaluator**: QA reviews outputs without being called by the generator (CTO/Builder). This mirrors the Harness's Evaluator independence.

The existing Permission Matrix (CoS -> CTO only, CTO -> Builder/Research/KO/Ops) already supports this. The change is conceptual: CTO stops being the Discussion orchestrator and becomes a discussion participant.

---

## 2. Hybrid Architecture: Single Bot + Selective Independent Agents

### 2.1 Config Feasibility

**Proposed model:**
- `accounts.default` (single Slack App) -- serves CTO, CIO, Builder, KO, Ops, Research via peer binding per channel
- `accounts.cos` (independent Slack App) -- serves CoS only via account binding
- `accounts.qa` (independent Slack App) -- serves QA only via account binding

**Does this work?** Yes. OpenClaw's binding system supports mixing peer-match and account-match bindings in the same config. The binding resolution order is:

1. **Peer match** (most specific): `match.peer.kind = "channel", match.peer.id = "<CHANNEL_ID>"` -- routes messages from a specific Slack channel to a specific agent
2. **Account match**: `match.accountId = "cos"` -- routes ALL messages received by the CoS Slack App to the CoS agent
3. **Fallback**: unmatched messages go to the default agent

The current OpenCrew config (CONFIG_SNIPPET_2026.2.9.md) uses peer binding exclusively -- each agent is bound to its channel via `match.peer`. This binding method is **account-agnostic** -- it works on whichever Slack App receives the event. In the current single-bot setup, all events come through one bot, and peer binding routes them to the correct agent by channel.

**The hybrid config would look like:**

```jsonc
{
  "channels": {
    "slack": {
      "accounts": {
        // Single bot for execution agents (existing App)
        "default": {
          "botToken": "${SLACK_BOT_TOKEN_DEFAULT}",
          "appToken": "${SLACK_APP_TOKEN_DEFAULT}"
        },
        // Independent CoS bot (new App)
        "cos": {
          "botToken": "${SLACK_BOT_TOKEN_COS}",
          "appToken": "${SLACK_APP_TOKEN_COS}"
        },
        // Independent QA bot (new App)
        "qa": {
          "botToken": "${SLACK_BOT_TOKEN_QA}",
          "appToken": "${SLACK_APP_TOKEN_QA}"
        }
      },
      "channels": {
        // Existing agent channels -- unchanged
        "<HQ_CHANNEL_ID>":       { "allow": true, "requireMention": false },
        "<CTO_CHANNEL_ID>":      { "allow": true, "requireMention": false, "allowBots": true },
        "<BUILD_CHANNEL_ID>":    { "allow": true, "requireMention": false, "allowBots": true },
        "<INVEST_CHANNEL_ID>":   { "allow": true, "requireMention": false },
        "<KNOW_CHANNEL_ID>":     { "allow": true, "requireMention": true },
        "<OPS_CHANNEL_ID>":      { "allow": true, "requireMention": true },
        "<RESEARCH_CHANNEL_ID>": { "allow": true, "requireMention": false }
      }
    }
  },
  "bindings": [
    // CoS: account-level binding (all events from CoS App -> CoS agent)
    { "agentId": "cos", "match": { "channel": "slack", "accountId": "cos" } },

    // QA: account-level binding (all events from QA App -> QA agent)
    { "agentId": "qa", "match": { "channel": "slack", "accountId": "qa" } },

    // Execution agents: peer binding on default account (unchanged from current)
    { "agentId": "cto",      "match": { "channel": "slack", "peer": { "kind": "channel", "id": "<CTO_CHANNEL_ID>" } } },
    { "agentId": "builder",  "match": { "channel": "slack", "peer": { "kind": "channel", "id": "<BUILD_CHANNEL_ID>" } } },
    { "agentId": "cio",      "match": { "channel": "slack", "peer": { "kind": "channel", "id": "<INVEST_CHANNEL_ID>" } } },
    { "agentId": "ko",       "match": { "channel": "slack", "peer": { "kind": "channel", "id": "<KNOW_CHANNEL_ID>" } } },
    { "agentId": "ops",      "match": { "channel": "slack", "peer": { "kind": "channel", "id": "<OPS_CHANNEL_ID>" } } },
    { "agentId": "research", "match": { "channel": "slack", "peer": { "kind": "channel", "id": "<RESEARCH_CHANNEL_ID>" } } }
  ]
}
```

**Key insight**: The peer bindings for CTO/Builder/etc. are processed against the default account's events. The account bindings for CoS/QA are processed against their respective accounts' events. These don't conflict -- OpenClaw processes each account's event stream independently through its own binding chain.

### 2.2 Channel Coexistence (Two Bots in Same Channel)

**Scenario**: CoS-Bot and Default-Bot (bound to CTO) are both in #cto. Someone posts in #cto.

**What happens:**

1. Slack delivers the `message.channels` event to ALL apps that have joined #cto
2. Default-Bot's app receives the event -> OpenClaw checks bindings -> peer match on `<CTO_CHANNEL_ID>` -> routes to CTO agent
3. CoS-Bot's app receives the event -> OpenClaw checks bindings -> account match on "cos" -> routes to CoS agent

**Without any guards, BOTH agents would respond.** This is the core coexistence question.

**Solution: `requireMention: true` on the CoS and QA accounts' channel configs.**

There is a subtlety here. OpenClaw's channel config (`channels.slack.channels`) is **global across all accounts** in the same gateway. You cannot set `requireMention: false` for CTO on #cto and `requireMention: true` for CoS on #cto in the same channel config block.

**However**, the binding model handles this naturally:

- **Default-Bot in #cto**: The peer binding for CTO matches on channel ID, not on mention. The channel config for #cto has `requireMention: false`, so CTO responds to all messages. This is the existing behavior.
- **CoS-Bot in #cto**: CoS-Bot is NOT the "native" bot for #cto. CoS's binding is account-level (`accountId: cos`), not peer-level on #cto. When CoS-Bot receives a message from #cto, the `requireMention` check applies. If `requireMention: true` is set on #cto's channel config, CoS only activates when @mentioned.

**The problem**: Setting `requireMention: true` on #cto globally would also require CTO to be @mentioned -- breaking its current behavior.

**Resolution approaches:**

1. **Option A -- Per-account channel overrides**: If OpenClaw supports `accounts.cos.channels.<CTO_CHANNEL_ID>.requireMention = true` while global remains `false`, this solves it cleanly. **Status: UNVERIFIED** in prior research. The docs say named accounts "can override any setting" but this has not been confirmed at the per-channel level.

2. **Option B -- CoS-Bot uses `requireMention: true` natively**: CoS-Bot joins #cto but ONLY responds when @mentioned (`<@U_COS>`). The global `requireMention: false` on #cto applies to the default bot (CTO), while CoS-Bot's agent instructions enforce mention-only behavior. **Problem**: This relies on agent-level self-discipline, not config-level enforcement. If `requireMention: false` is the channel setting, OpenClaw WILL trigger CoS's session for non-mention messages.

3. **Option C -- CoS does NOT join agent channels by default**: CoS-Bot only joins #hq (its home channel). When CoS needs to interact with #cto, it uses `sessions_send` (A2A delegation) rather than direct @mention. CoS only joins other channels for active Discussion mode sessions. **This is the cleanest solution that preserves existing channel behavior.**

4. **Option D -- Separate "discussion" threads**: CoS-Bot joins #cto only for specific discussion threads (not the channel at large). The bot is invited to the channel but only activates in threads where it is @mentioned. With `requireMention: true` set globally and CTO's channel using `requireMention: false`, CTO auto-responds to channel messages while CoS only responds in threads where it is mentioned. **Problem**: Same global config conflict as Option B.

**Recommended approach: Option C with selective @mention for discussions.**

CoS-Bot stays in #hq as its home. For orchestration:
- **Delegation**: CoS uses `sessions_send` to trigger CTO (existing A2A v1 flow, proven)
- **Discussion**: CoS @mentions CTO in a dedicated #collab or #hq thread where `allowBots: true` + `requireMention: true` are both set. CTO joins this discussion via @mention trigger.
- **Progress checking**: CoS @mentions CTO in #cto threads (CTO's channel has `allowBots: true`, CTO responds because it is @mentioned)

This avoids the global `requireMention` conflict entirely.

### 2.3 @Mention Interaction Patterns

**Pattern A: CoS checks CTO's progress in #cto**

```
Precondition:
  - #cto has allowBots: true (MUST ADD -- currently false)
  - #cto has requireMention: false (existing)
  - CoS-Bot has been invited to #cto

Flow:
  1. CTO (default bot) is working in #cto thread on a task
  2. CoS-Bot joins #cto and posts in the thread: "@CTO what's the status on X?"
  3. Default-Bot's app receives CoS-Bot's message in #cto
  4. OpenClaw checks: is this from a bot? Yes. Is allowBots: true? Yes.
  5. OpenClaw checks: is this from our bot user ID? No (U_COS != U_DEFAULT). Pass.
  6. OpenClaw checks requireMention: false on #cto -> pass (no mention needed)
  7. Peer binding matches <CTO_CHANNEL_ID> -> routes to CTO agent
  8. CTO reads thread, sees CoS's question, responds

Problem: Step 6 means CTO responds to ALL of CoS-Bot's messages, not just @mentions.
This is actually DESIRABLE for this pattern -- CoS posting in CTO's thread IS an interaction.

Counter-problem: CoS-Bot also receives CTO's response (via its own app's event stream).
  - CoS's account binding routes ALL events from CoS-Bot to CoS agent
  - CoS receives CTO's response in the thread -> CoS might auto-respond
  - This creates potential ping-pong

Mitigation: CoS's AGENTS.md must include explicit WAIT discipline:
  "After posting a progress check in another agent's channel, WAIT for response.
   Do not auto-respond to the reply unless you have a specific follow-up."
```

**Pattern B: QA reviews Builder's output in #build**

```
Precondition:
  - #build has allowBots: true (MUST ADD -- currently false)
  - QA-Bot has been invited to #build

Flow:
  1. Builder (default bot) posts closeout in #build thread
  2. QA-Bot reads the thread and posts review: "@Builder three issues found..."
  3. Default-Bot's app receives QA-Bot's message
  4. allowBots: true -> pass
  5. Self-loop filter: U_QA != U_DEFAULT -> pass
  6. Peer binding matches <BUILD_CHANNEL_ID> -> routes to Builder agent
  7. Builder reads QA's review and responds with fixes/clarifications

This pattern works. The key config change: allowBots: true on #build.
```

**Pattern C: CoS orchestrates discussion in #hq thread**

```
Precondition:
  - #hq has allowBots: true + requireMention: true
  - CTO-equivalent needs to join #hq -- but CTO uses the default bot
  - Default-Bot is already in #hq (it's the shared bot for all execution agents)

Flow:
  1. CoS creates thread in #hq: "Strategic discussion: should we add QA agent?"
  2. CoS @mentions CTO: "<@U_DEFAULT_BOT> CTO, what's the technical feasibility?"

  PROBLEM: The default bot has ONE user ID shared across CTO, Builder, KO, etc.
  When CoS @mentions the default bot, the peer binding for #hq routes to CoS
  (because #hq is CoS's channel). The CTO peer binding only matches on
  <CTO_CHANNEL_ID>, not on #hq.

  This means: the default bot receiving @mention in #hq routes to CoS, not CTO.
  CTO never sees it.
```

**This is a critical discovery.** In the hybrid model where the default bot serves multiple agents via peer binding, you CANNOT use @mention to reach a specific agent through the default bot in a channel that is not that agent's home channel. The peer binding is by channel, so the bot always routes to whichever agent owns that channel.

**The fix**: For Discussion mode, CoS uses `sessions_send` to trigger CTO on a specific thread, not @mention. Or, discussions happen in a dedicated #collab channel where binding can be configured differently.

**Alternative fix**: CTO gets its own Slack App (promoting it from default-bot to independent). This would mean the "default" account serves fewer agents (Builder, CIO, KO, Ops, Research) while CoS and CTO each get independent apps. This is a graduated approach -- start with CoS independent, add QA, then consider CTO.

### 2.4 Recommended Config

Given the analysis, the cleanest hybrid architecture is:

**Phase 1 (Minimal -- CoS independent only):**
- `accounts.default` -- CTO, Builder, CIO, KO, Ops, Research (peer binding, existing model)
- `accounts.cos` -- CoS only (account binding, independent Slack App)
- CoS uses `sessions_send` for delegation (existing A2A v1 mechanism)
- CoS uses #hq as its home channel (existing)
- Add `allowBots: true` to #cto and #build so CoS can post progress checks
- No Discussion mode yet -- defer to Phase 2

**Phase 2 (Add QA):**
- `accounts.qa` -- QA agent (account binding, independent Slack App)
- QA-Bot joins #build, #cto, #know with `allowBots: true`
- QA auto-reviews closeouts and @mentions the producing agent for feedback
- QA's AGENTS.md defines review triggers and quality criteria

**Phase 3 (Full Discussion mode):**
- Create #collab channel with `allowBots: true` + `requireMention: true`
- CoS orchestrates discussions by @mentioning agents in #collab threads
- If default-bot's peer binding is ambiguous in #collab (which agent?), consider promoting CTO to independent account

---

## 3. Instance vs Workspace Independence

### 3.1 Same Gateway with Multi-Account

**What multi-account means**: One OpenClaw gateway process manages multiple Slack Apps. Each App has its own `botToken`, `appToken`, and maintains its own Socket Mode WebSocket connection (or HTTP webhook endpoint). The gateway runs a single event loop that dispatches events from each account through the binding chain.

```
                      OpenClaw Gateway (single process)
                     /          |            \
              Socket Mode   Socket Mode   Socket Mode
                  |             |             |
            [CoS App]     [Default App]   [QA App]
            (Slack)        (Slack)        (Slack)
```

**Is workspace independence sufficient?** Yes, combined with account binding:
- Each agent already has its own workspace (`~/.openclaw/workspace-cos/`, etc.) with SOUL.md, AGENTS.md, MEMORY.md, etc.
- Each agent already has isolated sessions (thread-level session keys)
- Adding an independent Slack App via `accounts.cos` gives CoS its own bot identity (distinct name, avatar, bot user ID)
- The account-level binding (`accountId: cos`) ensures all events from CoS's App route exclusively to the CoS agent

This provides **logical independence** (own identity, own workspace, own session space) within **shared infrastructure** (one gateway, shared A2A tools, shared config).

### 3.2 Separate Gateway Instances

**What this means**: Each independent agent runs its own OpenClaw process with its own `openclaw.json`.

```
  [Gateway 1: CoS]        [Gateway 2: Default]      [Gateway 3: QA]
  openclaw-cos.json        openclaw.json              openclaw-qa.json
       |                        |                          |
  [CoS App]              [Default App]                [QA App]
```

**Problems:**

| Issue | Impact |
|-------|--------|
| `sessions_send` cannot cross processes | CoS cannot delegate to CTO via A2A -- must rely entirely on @mention in Slack, losing the reliable two-step trigger |
| No shared session management | `maxPingPongTurns`, session timeouts, and other safety constraints are per-instance. No unified loop prevention |
| No shared agent registry | Gateway 1 does not know Gateway 2's agents exist. `sessions_list`, `sessions_send`, agent ID resolution all fail cross-process |
| Triple operational burden | Three processes to monitor, restart, log-manage, and configure |
| Config duplication | Channel configs, thread settings, tool permissions must be maintained in three separate files |
| Heartbeat isolation | CoS's heartbeat cannot check on CTO's status via internal APIs |

**The ONLY advantage**: Complete process isolation. If Gateway 2 crashes, CoS (Gateway 1) and QA (Gateway 3) continue operating. But this is a minor benefit -- a single gateway restart takes seconds, and process managers (pm2, systemd) handle automatic restarts.

### 3.3 Recommendation

**Same gateway with multi-account is the clear winner.**

| Dimension | Same Gateway | Separate Gateways |
|-----------|-------------|-------------------|
| A2A delegation (`sessions_send`) | Works natively | BROKEN |
| Session management | Unified | Fragmented |
| Config management | Single file | Three files |
| Process management | One process | Three processes |
| Process isolation | No (single failure point) | Yes |
| Operational complexity | Low | High |
| Bot identity independence | Yes (multi-account) | Yes |
| Workspace independence | Yes (existing) | Yes |

The only scenario where separate gateways make sense is if you need to run agents on different physical machines (e.g., CoS on a cloud server for uptime, Builder on a local machine with code access). This is not the current requirement.

---

## 4. Proposed Architecture Diagram

```
                         +-----------------------+
                         |     Slack Workspace    |
                         +-----------------------+
                         |                       |
   +----------+    +----------+    +----------+  |
   | CoS App  |    |Default   |    | QA App   |  |
   | (Bot-CoS)|    |App (Bot) |    | (Bot-QA) |  |
   +----+-----+    +----+-----+    +----+-----+  |
        |               |              |          |
        |   +-----------+-----------+  |          |
        |   | Channels:             |  |          |
        |   | #hq  #cto  #build    |  |          |
        |   | #invest #know #ops   |  |          |
        |   | #research            |  |          |
        |   +-----------------------+  |          |
        +-----------------------+------+----------+
                                |
              +-----------------+------------------+
              |      OpenClaw Gateway (single)      |
              +-------------------------------------+
              |                                     |
              |  accounts:                          |
              |    cos:     CoS App tokens           |
              |    default: Default App tokens       |
              |    qa:      QA App tokens            |
              |                                     |
              |  bindings:                          |
              |    cos     <- accountId: cos         |
              |    qa      <- accountId: qa          |
              |    cto     <- peer: #cto channel     |
              |    builder <- peer: #build channel   |
              |    cio     <- peer: #invest channel  |
              |    ko      <- peer: #know channel    |
              |    ops     <- peer: #ops channel     |
              |    research<- peer: #research channel|
              |                                     |
              |  A2A tools: sessions_send,           |
              |    sessions_list (shared)            |
              +-------------------------------------+

  Interaction patterns:

  CoS (independent) ---sessions_send---> CTO (default bot)
  CoS (independent) ---@mention in #cto thread---> CTO (needs allowBots:true on #cto)
  QA  (independent) ---@mention in #build thread--> Builder (needs allowBots:true on #build)
  CTO (default bot) ---sessions_send---> Builder (existing, unchanged)

  Harness mapping:
    CoS = Orchestrator/Planner  (drives what to do)
    QA  = Evaluator             (challenges what was done)
    CTO/Builder/CIO = Generator (does the work)
    KO/Ops = System maintenance (unchanged)
```

---

## 5. Implementation Path

### What Changes in OpenCrew

**Config changes (openclaw.json):**

1. Add `accounts` block with `cos` and `qa` account entries (new Slack App tokens)
2. Keep `default` account (existing single bot -- rename from implicit default)
3. Add account-level bindings for CoS and QA
4. Keep peer-level bindings for CTO, Builder, CIO, KO, Ops, Research (unchanged)
5. Add `allowBots: true` to #cto and #build channel configs (enables cross-bot interaction)
6. Optionally add `requireMention: true` to #cto and #build (if you want CoS/QA to only respond when @mentioned in those channels -- recommended)

**Agent workspace changes:**

7. Create QA workspace (`~/.openclaw/workspace-qa/`) with SOUL.md, AGENTS.md
8. Define QA's role: review closeouts, challenge quality, check DoD compliance
9. Update CoS AGENTS.md: add orchestration responsibilities, Discussion mode instructions
10. Update CTO AGENTS.md: clarify CTO is a participant in discussions (not orchestrator), add `allowBots` interaction patterns

**Protocol changes (shared/):**

11. Update A2A_PROTOCOL.md: clarify that CoS is the Discussion orchestrator for strategic discussions; CTO orchestrates only within its execution scope (CTO->Builder)
12. Add QA agent to Permission Matrix: QA can review any agent's closeout, QA cannot delegate execution tasks

**Slack setup (human-manual):**

13. Create CoS Slack App (bot token, app token, Socket Mode)
14. Create QA Slack App (bot token, app token, Socket Mode)
15. Invite CoS-Bot to #hq, #cto, #build (and any other channels CoS should monitor)
16. Invite QA-Bot to #build, #cto, #know (channels where QA should review)
17. Record bot user IDs for @mention formatting

### What Stays the Same

- All existing agent workspaces (CTO, Builder, CIO, KO, Ops, Research) -- unchanged
- All existing peer bindings -- unchanged
- The default Slack App (single bot for execution agents) -- unchanged
- A2A Delegation mode (sessions_send) -- unchanged, still the primary mechanism
- Task types (Q/A/P/S), Closeout protocol, Autonomy Ladder -- unchanged
- Channel structure (#hq, #cto, #build, etc.) -- unchanged
- Thread-level session isolation -- unchanged

---

## 6. Confidence Assessment

| Finding | Confidence | Basis |
|---------|-----------|-------|
| One account can serve multiple agents via peer binding | **HIGH** | This is OpenCrew's current production model (CONFIG_SNIPPET_2026.2.9.md) |
| Multi-account supports mixing peer and account bindings | **HIGH** | OpenClaw docs confirm binding specificity hierarchy: peer > accountId > channel > fallback |
| Two bots in same channel both receive events | **HIGH** | Slack Events API delivers to ALL subscribed apps. Confirmed in research_autonomous_slack_r1.md |
| `allowBots: true` enables cross-bot message processing | **HIGH** | Confirmed by docs, community reports, and the "47 replies in 12 seconds" incident |
| Self-loop filter is per-bot-user-ID | **HIGH** | Confirmed by Issue #15836 fix analysis |
| CoS as orchestrator maps to Harness Design | **HIGH** | Role analysis against SOUL.md and Harness methodology |
| Default-bot @mention in non-home channel routes correctly | **LOW** | Default bot's peer binding routes by channel, not by @mention target. @mentioning default bot in #hq routes to CoS (not CTO). This is a limitation. |
| Per-account channel config overrides | **LOW** | Docs say "named accounts can override" but per-channel overrides within accounts are unverified |
| QA as independent evaluator adds net value | **MEDIUM** | Conceptually sound (Harness Design validates the pattern), but no empirical data on QA agent quality in Slack-based review |
| Socket Mode with 3 apps is stable | **MEDIUM** | Within normal range per OpenClaw docs. 5+ apps recommended to switch to HTTP mode |

---

## 7. Open Questions

1. **Per-account channel overrides**: Can `accounts.cos.channels.<CTO_CH>.requireMention` override the global channel setting? If yes, this solves the coexistence problem cleanly. Needs empirical testing.

2. **Default bot @mention routing in foreign channels**: When CoS @mentions the default bot in #hq (CoS's channel), does the peer binding route to CoS or CTO? Initial analysis says CoS (because #hq's peer binding maps to CoS). This means Discussion mode via @mention in #hq cannot reach CTO through the default bot. Needs testing.

3. **QA agent scope definition**: What exactly should QA review? Options:
   - All closeouts (comprehensive but noisy)
   - Only S-type and P-type closeouts (high-signal)
   - Only when explicitly triggered by CoS or user

4. **Bot display names in thread history**: When CTO (default bot) and CoS (CoS-Bot) both post in a thread, do agents loading thread history see distinct sender identities? Or do they see generic "bot" labels? This affects discussion context quality.

5. **CoS heartbeat as orchestration trigger**: CoS already has a 12-hour heartbeat. Could this heartbeat serve as the "harness loop" -- checking agent status, driving pending tasks forward, synthesizing overnight progress? This would make CoS a proactive orchestrator without requiring external cron jobs.

6. **Graduated independence**: The analysis assumes CoS and QA both need independence. Should CTO also eventually become independent (own Slack App)? This would solve the @mention routing problem (Question 2) but adds a fourth Slack App. What is the right graduation path?

7. **Cost impact**: Three Slack Apps means three Socket Mode connections and potentially 3x the event processing for shared channels. What is the token cost of CoS and QA processing events from channels they monitor but do not act on (filtered by `requireMention`)?

8. **A2A protocol for QA**: The current A2A_PROTOCOL.md does not define a QA role. What is QA's permission in the matrix? Can QA send tasks back to Builder? Can QA escalate to CTO? Does QA participate in the closeout flow or sit outside it?

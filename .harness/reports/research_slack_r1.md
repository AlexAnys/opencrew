commit 7e825263db36aef68792a050c324daef598b4c56
Author: Alex's Mac <alexmac@AlexsdeMac-mini-2.local>
Date:   Sat Mar 28 17:38:48 2026 +0800

    feat: add A2A v2 research harness, architecture, and agent definitions
    
    Multi-agent harness for researching and designing A2A v2 protocol:
    
    Research reports (Phase 1):
    - Slack: true multi-agent collaboration via multi-account + @mention
    - Feishu: groupSessionScope + platform limitation analysis
    - Discord: multi-bot routing + Issue #11199 blocker analysis
    
    Architecture designs (Phase 2):
    - A2A v2 Protocol: Delegation (v1) + Discussion (v2) dual-mode
    - 5 collaboration patterns: Architecture Review, Strategic Alignment,
      Code Review, Incident Response, Knowledge Synthesis
    - 3-level orchestration: Human → Agent → Event-Driven
    - Platform configs, migration guides, 6 ADRs
    
    Agent definitions for Claude Code Agent Teams:
    - researcher.md, architect.md, doc-fixer.md, qa.md
    
    QA verification: all issues resolved, PASS verdict after fixes.
    
    Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>

diff --git a/.harness/reports/research_slack_r1.md b/.harness/reports/research_slack_r1.md
new file mode 100644
index 0000000..16022c5
--- /dev/null
+++ b/.harness/reports/research_slack_r1.md
@@ -0,0 +1,349 @@
+# Research Report: Slack True Multi-Agent Collaboration (U0, Round 1)
+
+> Researcher: Claude Opus 4.6 | Date: 2026-03-27 | Contract: `.harness/contracts/research-slack.md`
+
+---
+
+## Executive Summary
+
+True multi-agent collaboration on Slack -- where multiple agents participate in the same thread as distinct identities, each bringing independent judgment -- is **technically feasible today** using OpenClaw's multi-account Slack support. The key enabler is `channels.slack.accounts`: each agent gets its own Slack app/bot, its own `xoxb-` token, and a binding to a specific OpenClaw agent. With `allowBots: true` + `requireMention: true` on shared channels, Bot-B can see Bot-A's messages as context and respond when explicitly @mentioned. This eliminates the self-loop problem that forces today's two-step `sessions_send` workaround. However, the current OpenCrew deployment uses single-bot mode, so migrating requires creating 6-7 Slack apps and reconfiguring bindings -- a significant but well-documented path.
+
+---
+
+## 1. Platform Capability Assessment
+
+### 1.1 Slack Multi-Bot in Threads
+
+**Confidence: HIGH** (verified against Slack API docs and practical testing reports)
+
+Slack's Events API delivers message events to all apps that are members of a channel, regardless of who posted the message. Specifically:
+
+- **Bot-A posts in a thread; Bot-B receives the event**: Yes. Each Slack app subscribed to `message.channels` (or equivalent) receives events for all messages in channels it has joined, including messages posted by other bots. The `bot_message` subtype identifies these. ([Slack Events API docs](https://docs.slack.dev/apis/events-api/), [Slack message event reference](https://docs.slack.dev/reference/events/message/))
+
+- **Self-loop prevention is app-side, not platform-side**: Slack itself does NOT filter out a bot's own messages from event delivery. Frameworks like Bolt implement `ignoring_self` as an application-level guard. This means each app must decide whether to ignore its own messages. ([Slack bot interactions docs](https://api.slack.com/bot-users))
+
+- **Thread participation**: Any bot that is a member of a channel can post to any thread in that channel using the `thread_ts` parameter. No special permissions needed beyond `chat:write`. ([Slack threading blog](https://medium.com/slack-developer-blog/bringing-your-bot-into-threaded-messages-cd272a42924f))
+
+- **Visual identity**: Each Slack app has its own name, icon, and bot user ID. Messages from different bots are visually distinct in threads -- this is the key advantage over single-bot mode where all agents look like the same entity.
+
+**Key implication**: The Slack platform fully supports multiple bots having a real-time conversation in a thread. There is no platform-level barrier.
+
+### 1.2 OpenClaw Slack Plugin Current State
+
+**Confidence: HIGH** (verified against OpenClaw official docs, GitHub gist, and DeepWiki source analysis)
+
+OpenClaw's Slack plugin already supports multi-account mode:
+
+**Multi-account configuration** (`channels.slack.accounts`):
+```json
+{
+  "channels": {
+    "slack": {
+      "accounts": {
+        "default": { "botToken": "xoxb-cos-...", "appToken": "xapp-cos-..." },
+        "cto":     { "botToken": "xoxb-cto-...", "appToken": "xapp-cto-...", "name": "CTO" },
+        "builder": { "botToken": "xoxb-bld-...", "appToken": "xapp-bld-...", "name": "Builder" }
+      }
+    }
+  }
+}
+```
+
+**Binding per account**:
+```json
+{
+  "bindings": [
+    { "agentId": "cos",     "match": { "channel": "slack", "accountId": "default" } },
+    { "agentId": "cto",     "match": { "channel": "slack", "accountId": "cto" } },
+    { "agentId": "builder", "match": { "channel": "slack", "accountId": "builder" } }
+  ]
+}
+```
+
+**Bot message handling** -- three modes for `allowBots`:
+- `false` (default): All bot messages ignored. Current OpenCrew behavior.
+- `true`: All bot messages accepted as inbound. Requires loop prevention.
+- `"mentions"`: Bot messages accepted only if they @mention this bot. Safest for multi-agent.
+
+**Self-loop prevention**: OpenClaw ignores messages from the same bot user ID (`message.user === botUserId`). With multi-account, each account has a different `botUserId`, so Bot-CTO's messages are NOT filtered by Bot-Builder's agent -- they are treated as real inbound. ([OpenClaw Slack docs](https://docs.openclaw.ai/channels/slack), [GitHub gist](https://gist.github.com/rafaelquintanilha/9ca5ae6173cd0682026754cfefe26d3f))
+
+**Agent identity** (visual differentiation): OpenClaw supports `chat:write.customize` scope for per-agent name/icon override. Issue #27080 (identity not applied on inbound-triggered replies) was fixed in PR #27134. With multi-account, each bot has its native identity, so `chat:write.customize` is not even needed -- each app's profile serves as the identity. ([GitHub issue #27080](https://github.com/openclaw/openclaw/issues/27080))
+
+**Thread session isolation**: `thread.historyScope = "thread"` + `inheritParent = false` ensures each thread is an independent session. `initialHistoryLimit` controls how many prior messages load when a new session starts in an existing thread.
+
+### 1.3 Gap Analysis
+
+| Capability | Slack Platform | OpenClaw Plugin | OpenCrew Config | Gap |
+|-----------|---------------|----------------|----------------|-----|
+| Multiple bots in one channel | YES | YES (multi-account) | NO (single bot) | **OpenCrew config change** |
+| Bot-B sees Bot-A's messages | YES (Events API) | YES (`allowBots`) | NO (`allowBots: false`) | **OpenCrew config change** |
+| Visual identity per agent | YES (separate apps) | YES (multi-account or `chat:write.customize`) | NO (shared identity) | **OpenCrew config change** |
+| Thread-level session isolation | YES (native threads) | YES (`historyScope: "thread"`) | YES (already configured) | None |
+| Loop prevention | N/A (app-side) | YES (`requireMention`, `allowBots: "mentions"`) | N/A | **OpenCrew config change** |
+| Orchestrated turn-taking | N/A | Partial (`sessions_send` for explicit trigger) | YES (two-step A2A) | **New orchestration logic needed** |
+| Agent sees full thread history | YES | YES (`initialHistoryLimit`) | Partial | **Config tuning** |
+
+**Bottom line**: The platform (Slack) and middleware (OpenClaw) already support everything needed. The gap is entirely at the OpenCrew configuration and protocol layer. No upstream code changes are required.
+
+---
+
+## 2. Collaboration Patterns Catalog
+
+### 2.1 Discussion Pattern
+
+**Description**: Multiple agents participate in a single Slack thread, each contributing from their domain perspective. Example: CTO proposes architecture, Builder critiques feasibility, QA identifies risks -- they iterate to convergence.
+
+**Mechanics**:
+1. Human (or CoS) posts a topic in a shared channel (e.g., `#cto`) or a dedicated `#collab` channel.
+2. CTO is bound to that channel and responds first with an architecture proposal.
+3. Human (or orchestrator agent) @mentions `@Builder` in the thread: "What do you think about feasibility?"
+4. Builder's bot receives the thread message (because `allowBots: true` + it was @mentioned), loads thread history via `initialHistoryLimit`, and responds with feasibility analysis.
+5. Human @mentions `@CTO` again: "How do you respond to Builder's concerns?"
+6. CTO sees Builder's messages in thread history and refines the proposal.
+7. Repeat until convergence.
+
+**Requirements**:
+- Multi-account Slack setup (one app per participating agent)
+- `allowBots: true` or `"mentions"` on the shared channel
+- `requireMention: true` on shared channels (loop prevention)
+- `thread.historyScope: "thread"` + `initialHistoryLimit >= 50` (so each agent sees the full discussion)
+- `inheritParent: true` on shared channels (so thread participants inherit the root message context)
+
+**Feasibility**: **NOW** -- achievable with config changes only. No code changes to OpenClaw or OpenCrew needed.
+
+### 2.2 Review Pattern
+
+**Description**: One agent produces work, multiple agents review it in the same thread. Example: Builder submits a design doc, CTO reviews architecture soundness, QA reviews correctness, KO checks knowledge consistency.
+
+**Mechanics**:
+1. Builder posts deliverable in `#build` thread (the existing A2A closeout thread).
+2. CTO is @mentioned in the thread: "@CTO please review architecture."
+3. CTO's bot receives the message, loads thread history (seeing Builder's full output), and posts architecture review.
+4. QA is @mentioned: "@QA please review correctness."
+5. QA reads both Builder's output and CTO's review, posts correctness assessment.
+6. Builder is @mentioned with consolidated feedback: "@Builder please address these items."
+
+**Requirements**:
+- Same multi-account setup as Discussion Pattern.
+- Reviewers' bots must be invited to the channel where the review thread lives.
+- `initialHistoryLimit` must be high enough to capture the full deliverable (possibly 80-100 for large outputs).
+- Each reviewer agent needs workspace instructions (SOUL.md/AGENTS.md) that define their review perspective.
+
+**Feasibility**: **NOW** -- identical infrastructure to Discussion Pattern. The only addition is role-specific review instructions in each agent's workspace.
+
+### 2.3 Brainstorm Pattern
+
+**Description**: Agents take turns building on each other's ideas in a free-form exploration. Example: CoS states a goal, CTO proposes technical approaches, CIO adds domain constraints, Builder estimates effort -- they converge on a plan.
+
+**Mechanics**:
+1. Human posts a brainstorm prompt in a shared channel: "How should we approach X?"
+2. Multiple agents are @mentioned (or an orchestrator agent manages turn order).
+3. Each agent reads the full thread history before contributing.
+4. **Turn management option A -- Human orchestrated**: Human @mentions the next agent after each response.
+5. **Turn management option B -- Agent orchestrated**: A designated orchestrator agent (CoS or CTO) reads each response and decides who to call next, posting "@Builder what's your take?" or "@CIO any domain constraints?"
+6. **Turn management option C -- Round-robin**: A lightweight script or orchestrator sends @mentions in a fixed order with a configurable delay.
+
+**Requirements**:
+- All participating agents need bots in the shared channel.
+- Higher `initialHistoryLimit` (brainstorms can get long).
+- Clear termination criteria (who decides the brainstorm is "done"?).
+- For Option B (agent-orchestrated): The orchestrator agent needs `allowBots: true` to see other agents' messages AND the ability to @mention other bots in its responses.
+
+**Feasibility**: **NEAR** -- The infrastructure is the same as Discussion Pattern (NOW). However, agent-orchestrated turn management (Option B) requires that agents can reliably @mention other bots in their messages and that the mentioned bot's Slack app correctly recognizes the mention. This needs validation. Human-orchestrated (Option A) works NOW.
+
+---
+
+## 3. Comparison with Harness Design
+
+### 3.1 File-based Blackboard vs Chat-based Collaboration
+
+Anthropic's harness design for long-running applications uses a **file-based Blackboard pattern**: agents write files, other agents read them. The Planner writes a spec file, the Generator reads it and writes code, the Evaluator reads the code and writes a review file. Communication is asynchronous, persistent, and structured. ([Anthropic engineering blog](https://www.anthropic.com/engineering/harness-design-long-running-apps))
+
+| Dimension | Harness (File-based) | OpenCrew Slack (Chat-based) |
+|-----------|---------------------|---------------------------|
+| **Communication medium** | Files on disk | Slack thread messages |
+| **Persistence** | Git-trackable files | Slack thread history (ephemeral on free plan) |
+| **Structure** | Highly structured (sprint contracts, spec files) | Semi-structured (thread messages with conventions) |
+| **Latency** | Near-zero (local filesystem) | ~1-3s per message (Slack API round-trip) |
+| **Human visibility** | Requires explicit file inspection | Built-in (Slack UI) |
+| **Context window** | Full file contents per agent | Thread history limited by `initialHistoryLimit` |
+| **Turn management** | Explicit (harness orchestrator) | @mention-based or human-driven |
+| **Adversarial review** | Generator vs Evaluator (GAN-inspired) | Any agent vs any agent (same mechanism) |
+
+The harness pattern's key strength is **deterministic orchestration**: the harness code decides exactly when each agent runs and what context it receives. The Slack pattern's strength is **human-in-the-loop visibility and intervention**: any human can read the thread, jump in, redirect, or override at any point.
+
+### 3.2 Unique Value of Real-time Multi-Agent Chat
+
+**Confidence: MEDIUM** (inference based on architecture comparison, not empirical measurement)
+
+The Slack-based approach offers several advantages the file-based harness cannot:
+
+1. **Real-time human oversight**: The user watches the discussion unfold in real-time and can intervene ("Actually, ignore that constraint -- we changed requirements"). File-based harnesses require the user to inspect files after-the-fact.
+
+2. **Natural escalation**: If agents get stuck or disagree, the human is already in the thread and can break the tie. In a harness, you need explicit escalation mechanisms.
+
+3. **Organizational memory**: Slack threads persist as searchable organizational history. Future agents (or humans) can search for "that architecture discussion we had about X" and find the full multi-agent deliberation.
+
+4. **Progressive trust building**: Users can start with human-orchestrated discussions (manually @mentioning agents) and gradually move to agent-orchestrated as trust builds. The harness pattern is all-or-nothing autonomous.
+
+5. **Cross-domain collaboration**: A Slack thread can include agents from different "layers" (CoS + CTO + Builder) that wouldn't interact in a harness's rigid pipeline.
+
+**Trade-off**: Slack-based collaboration is slower (network latency, message rendering) and less structured than file-based. For pure software generation tasks, the harness pattern is likely more efficient. For strategic decisions, design reviews, and cross-functional alignment, Slack-based collaboration is superior.
+
+---
+
+## 4. Recommended Architecture
+
+### 4.1 Multi-Bot Configuration
+
+**Recommended approach**: Create separate Slack apps for each "conversational" agent. Not all 7 agents need their own app -- only those that participate in multi-agent discussions.
+
+**Tier 1 -- Own Slack App** (agents that discuss):
+- CoS, CTO, Builder (core discussion participants)
+
+**Tier 2 -- Own Slack App if needed** (agents that may review):
+- CIO (domain specialist, participates in strategic discussions)
+- KO (participates in knowledge reviews)
+
+**Tier 3 -- Shared or no Slack App** (agents that don't discuss):
+- Ops (audit only, doesn't need to participate in discussions)
+- Research (ephemeral worker, spawned via `sessions_spawn`)
+
+**Configuration skeleton**:
+```json
+{
+  "channels": {
+    "slack": {
+      "accounts": {
+        "default": { "botToken": "xoxb-cos-...", "appToken": "xapp-cos-..." },
+        "cto":     { "botToken": "xoxb-cto-...", "appToken": "xapp-cto-..." },
+        "builder": { "botToken": "xoxb-bld-...", "appToken": "xapp-bld-..." }
+      },
+      "channels": {
+        "<COLLAB_CHANNEL_ID>": {
+          "allow": true,
+          "requireMention": true,
+          "allowBots": true
+        }
+      },
+      "thread": {
+        "historyScope": "thread",
+        "inheritParent": true,
+        "initialHistoryLimit": 50
+      }
+    }
+  },
+  "bindings": [
+    { "agentId": "cos",     "match": { "channel": "slack", "accountId": "default" } },
+    { "agentId": "cto",     "match": { "channel": "slack", "accountId": "cto" } },
+    { "agentId": "builder", "match": { "channel": "slack", "accountId": "builder" } }
+  ]
+}
+```
+
+**Each Slack app requires**: Bot Token Scopes: `channels:history`, `channels:read`, `chat:write`, `chat:write.customize`, `users:read`. Event Subscriptions: `message.channels`, `app_mention`. Socket Mode enabled with `connections:write` scope on the app-level token.
+
+### 4.2 Orchestration Model
+
+**Recommended: Hybrid human + agent orchestration** (phased rollout)
+
+**Phase 1 -- Human Orchestrated (NOW)**:
+- User @mentions agents in threads to drive discussion.
+- All agents have `requireMention: true` + `allowBots: true`.
+- User controls pace, topic, and turn order.
+- This is the safest starting point and requires zero protocol changes.
+
+**Phase 2 -- Agent Orchestrated (NEAR)**:
+- Designate CTO (or CoS) as the orchestrator for technical discussions.
+- Orchestrator agent's AGENTS.md includes instructions: "After receiving input, decide which specialist to consult next and @mention them in the thread."
+- Add guardrails: max 3 agent-to-agent turns per discussion before requiring human input.
+- `maxPingPongTurns` from A2A protocol can be repurposed as a discussion round limit.
+
+**Phase 3 -- Event-Driven with Guardrails (FUTURE)**:
+- Agents proactively respond when they detect messages relevant to their domain (similar to SlackAgents' proactive mode from [EMNLP 2025](https://aclanthology.org/2025.emnlp-demos.76.pdf)).
+- Requires sophisticated relevance filtering to avoid noise.
+- Use `allowBots: "mentions"` as the safety valve.
+
+### 4.3 Integration with Existing A2A Protocol
+
+The multi-bot architecture does NOT replace the existing A2A protocol -- it extends it with a new mode:
+
+**A2A v1 (existing -- single-bot delegation)**:
+- Two-step trigger: visible anchor + `sessions_send`
+- Use case: Structured task delegation (CTO assigns Builder a specific task)
+- Keep for: All existing delegation workflows, task tracking, closeout flows
+
+**A2A v2 (new -- multi-bot discussion)**:
+- One-step trigger: @mention in a shared thread
+- Use case: Multi-party discussion, review, brainstorm
+- Session: Each agent's session is the thread itself (`thread:<threadTs>`)
+- Context: Thread history serves as the shared context (Blackboard equivalent)
+
+**Coexistence**: Both modes can coexist. A Discussion (v2) in `#collab` can result in a Delegation (v1) where CTO creates a task thread in `#build` and `sessions_send`s Builder. The discussion thread serves as the "why" record; the task thread serves as the "what" execution record.
+
+**Migration path**: No breaking changes. Add multi-bot accounts alongside existing single-bot. Existing bindings continue to work for channels that don't need multi-agent discussion. New `#collab` or shared channels use multi-bot + `allowBots` + `requireMention`.
+
+---
+
+## 5. Confidence Assessment
+
+| Finding | Confidence | Evidence |
+|---------|-----------|---------|
+| Slack Events API delivers Bot-A's messages to Bot-B | **HIGH** | Slack API docs confirm apps receive all message events in channels they've joined. Community testing confirms. |
+| OpenClaw `channels.slack.accounts` supports multi-bot | **HIGH** | Official docs, GitHub gist with working config, DeepWiki source analysis all confirm. |
+| `allowBots: true` + `requireMention: true` prevents loops | **HIGH** | Official OpenClaw docs explicitly recommend this combination. Community reports confirm. |
+| Self-loop filter is per-bot-user-ID (not global) | **HIGH** | OpenClaw Slack docs: "ignores messages from the same bot user ID." Multi-account = different user IDs. Discord issue #11199 confirms the same logic was fixed for Discord with sibling bot registry. |
+| Agent identity fix (PR #27134) enables visual differentiation | **HIGH** | GitHub issue #27080 closed with fix. With multi-account, native app profiles provide identity without needing `chat:write.customize`. |
+| Discussion/Review patterns work NOW with config changes | **MEDIUM** | All required primitives exist (multi-account, allowBots, thread history). Not yet tested end-to-end in an OpenCrew deployment. |
+| Agent-orchestrated turn management works | **MEDIUM** | Requires agents to @mention other bots in their messages. OpenClaw's message tool can include @mentions, but reliable mention-parsing by receiving bot needs validation. |
+| `allowBots: "mentions"` mode exists | **MEDIUM** | DeepWiki analysis mentions this as a supported value. Not found in the main official docs page, but referenced in source-level documentation. |
+| Brainstorm pattern with automatic turn-taking | **LOW** | Conceptually sound but no existing implementation. Requires custom orchestration logic not yet built. |
+| Thread history is sufficient as Blackboard replacement | **LOW** | Depends on thread length, `initialHistoryLimit` setting, and whether agents can parse unstructured thread content as effectively as structured files. |
+
+---
+
+## 6. Open Questions
+
+1. **Slack free plan thread history**: Does the free Slack plan's message history limit (90 days) affect thread-based collaboration? For long-running projects, will old discussion threads become inaccessible?
+
+2. **Mention parsing reliability**: When Agent-CTO posts "@Builder what do you think?", does OpenClaw's Slack plugin reliably detect this as a mention of the Builder bot and route it to the Builder agent? Or does it require Slack's native mention format (`<@BOT_USER_ID>`)? This needs empirical testing.
+
+3. **Socket Mode connection limits**: With 5-7 separate Slack apps all using Socket Mode, does this create issues with Slack's connection limits or rate limits? The OpenClaw docs recommend HTTP mode for multi-account: "Give each account a distinct `webhookPath` so registrations do not collide."
+
+4. **Session isolation in shared channels**: When CTO and Builder both participate in a thread in `#collab`, they each have their own session (`agent:cto:slack:channel:COLLAB:thread:TS` and `agent:builder:slack:channel:COLLAB:thread:TS`). Do these sessions conflict? Can both write to the same thread without routing issues?
+
+5. **`maxPingPongTurns` applicability**: The existing A2A protocol uses `maxPingPongTurns = 4` for `sessions_send` loops. In the new discussion pattern, is there an equivalent limit for @mention-driven discussions? Without one, an agent-orchestrated discussion could theoretically run indefinitely.
+
+6. **Cost implications**: Each Slack app consumes one Socket Mode connection. With 5-7 apps, the OpenClaw gateway maintains 5-7 persistent WebSocket connections. What is the resource impact? Is HTTP Events API mode more appropriate for this scale?
+
+7. **Discord/Feishu parity**: The Discord plugin had a similar global bot-filter bug (#11199) that was fixed with a sibling bot registry (PRs #11644, #22611, #35479). Has the Slack plugin received an equivalent fix, or does it still use the simpler per-bot-user-ID check? The Slack issue #15836 (agent-to-agent routing) was closed as NOT_PLANNED -- does multi-account mode make that issue moot?
+
+8. **SlackAgents (EMNLP 2025) proactive mode**: The research paper describes agents that listen to threads without being mentioned and proactively contribute. Could this "proactive mode" be adapted for OpenCrew? What relevance filtering would prevent noise?
+
+---
+
+## Appendix A: Key References
+
+- [OpenClaw Slack Plugin Docs](https://docs.openclaw.ai/channels/slack)
+- [Running Multiple AI Agents as Slack Teammates (GitHub Gist)](https://gist.github.com/rafaelquintanilha/9ca5ae6173cd0682026754cfefe26d3f)
+- [OpenClaw Multi-Agent Routing Docs](https://docs.openclaw.ai/concepts/multi-agent)
+- [OpenClaw Issue #15836: Agent-to-agent Slack routing](https://github.com/openclaw/openclaw/issues/15836)
+- [OpenClaw Issue #27080: Slack agent identity fix](https://github.com/openclaw/openclaw/issues/27080)
+- [OpenClaw Issue #11199: Discord multi-bot filtering](https://github.com/openclaw/openclaw/issues/11199)
+- [Anthropic Harness Design Blog Post](https://www.anthropic.com/engineering/harness-design-long-running-apps)
+- [SlackAgents: EMNLP 2025 Demo Paper](https://aclanthology.org/2025.emnlp-demos.76.pdf)
+- [Slack Events API Documentation](https://docs.slack.dev/apis/events-api/)
+- [Slack Message Event Reference](https://docs.slack.dev/reference/events/message/)
+- [OpenClaw Slack Setup Best Practices (Macaron)](https://macaron.im/blog/openclaw-slack-setup)
+- [OpenClaw Multi-Agent Setup Tutorial (LumaDock)](https://lumadock.com/tutorials/openclaw-multi-agent-setup)
+
+## Appendix B: Glossary
+
+- **A2A**: Agent-to-Agent protocol used in OpenCrew for task delegation
+- **allowBots**: OpenClaw config setting controlling whether bot-authored messages are processed
+- **Blackboard pattern**: Communication pattern where agents read/write shared files (used in Anthropic's harness)
+- **Multi-account**: OpenClaw feature allowing multiple Slack apps (each with own bot token) in one gateway
+- **requireMention**: OpenClaw config setting requiring explicit @mention for agent activation
+- **sessions_send**: OpenClaw tool for sending messages to another agent's session (the "real trigger" in A2A v1)
+- **Socket Mode**: Slack connection mode using persistent WebSocket (default for OpenClaw)
+- **Two-step trigger**: Current OpenCrew A2A mechanism: visible anchor message + sessions_send

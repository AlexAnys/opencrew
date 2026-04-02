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

diff --git a/.harness/reports/research_discord_r1.md b/.harness/reports/research_discord_r1.md
new file mode 100644
index 0000000..9467648
--- /dev/null
+++ b/.harness/reports/research_discord_r1.md
@@ -0,0 +1,349 @@
+# Research Report: Discord Multi-Bot Capabilities (U2, Round 1)
+
+**Date**: 2026-03-27
+**Researcher**: Claude (automated research agent)
+**Scope**: Multi-bot routing, channel isolation, thread support, and multi-agent collaboration on Discord for OpenCrew
+
+---
+
+## Executive Summary
+
+Discord fully supports multiple bots coexisting in a single server with distinct identities, and OpenClaw has shipped multi-account Discord support (PR #3672, merged ~Jan 2026). Each bot receives all MESSAGE_CREATE events for channels it can view, enabling cross-bot message visibility at the platform level. However, OpenClaw's internal bot-message filter currently treats all configured bot accounts as "self" and drops their messages (Issue #11199), which blocks visible bot-to-bot collaboration via Discord. The practical workaround is to use OpenClaw's internal `sessions_send` for agent-to-agent communication and restrict Discord to human-to-agent interaction per channel.
+
+For Issue #34 (cos/ops conversation mixing), the root cause is a single-bot configuration where one bot identity serves all channels, combined with missing or incorrect channel-level permission overrides. The fix is either (a) proper Discord channel permission overwrites to restrict Send Messages per-channel on the single bot's role, or (b) migrating to multi-bot with each bot scoped to its designated channel via Discord permission overrides.
+
+---
+
+## 1. Multi-Bot Routing Model
+
+### 1.1 Multiple Bots in One Server
+
+**Confidence: HIGH** (based on Discord API documentation and widespread community practice)
+
+Discord servers support up to 50 bot users. Each bot is a separate Application in the Discord Developer Portal with its own token, avatar, display name, and online status. All bots in a server receive gateway events independently -- when a user posts in a channel, every bot with View Channel permission on that channel receives a `MESSAGE_CREATE` event via its own WebSocket connection.
+
+Key facts:
+- Each bot requires its own Application, Bot Token, and server invite
+- Each bot must independently enable the **Message Content Intent** privileged gateway intent to read message body text
+- Bots appear as distinct members in the server member list with independent online/offline status
+- Each bot can register its own slash commands (no namespace collision if names differ)
+- Rate limits are per-bot, so multiple bots do not share rate limit buckets
+
+### 1.2 Cross-Bot Message Visibility
+
+**Confidence: HIGH** (Discord API behavior) / **MEDIUM** (OpenClaw handling)
+
+At the Discord platform level, when Bot-A posts a message in #build, Bot-B **does** receive the `MESSAGE_CREATE` gateway event for that message, provided:
+1. Bot-B has View Channel permission on #build
+2. Bot-B has the Message Content Intent enabled
+3. Bot-B is connected to the Gateway using API v9 or above
+
+The `message.author` object includes a `bot: true` flag, allowing the receiving bot to identify the source as another bot.
+
+**OpenClaw complication**: OpenClaw's Discord plugin filters out messages authored by bots by default (`allowBots` defaults to `false`). More critically, even when `allowBots` is set to `true` or `"mentions"`, the current implementation (as of Issue [#11199](https://github.com/openclaw/openclaw/issues/11199)) checks the message author ID against **all** configured bot account IDs in the instance, not just the receiving account's own ID. This means Bot-A's message is treated as "own message" by Bot-B's handler and silently dropped.
+
+**Workaround options**:
+1. Set `allowBots: true` with `requireMention: false` and whitelist sibling bot user IDs in per-channel `users` arrays. This works but disables mention gating.
+2. Use OpenClaw's internal `sessions_send` for all agent-to-agent communication (recommended by the A2A protocol). Discord messages then serve only as "visibility anchors" for human observers.
+
+**Related PRs addressing #11199**:
+- PR #11644: "bypass bot filter and mention gate for sibling Discord bots"
+- PR #22611: "allow messages from other instance bots in multi-account setups"
+- PR #35479: "add allowBotIds config to selectively allow bot messages"
+
+(Status of these PRs could not be confirmed in this research round.)
+
+### 1.3 OpenClaw Multi-Account Support Status
+
+**Confidence: HIGH** (confirmed via Issue #3306 comments and documentation)
+
+OpenClaw's Discord plugin now supports multiple bot accounts in a single gateway instance. The feature was introduced via **PR #3672** ("feat: Introduce multi-account support for Discord, ensuring session keys and RPC IDs are account-aware"), which was merged around January 28, 2026. Issue #3306 was the original feature request; a commenter confirmed on February 9, 2026: "Multi-Agent works for current version."
+
+Configuration structure:
+```json
+{
+  "channels": {
+    "discord": {
+      "accounts": {
+        "default": { "token": "BOT_TOKEN_A" },
+        "coding":  { "token": "BOT_TOKEN_B" }
+      }
+    }
+  }
+}
+```
+
+Each account gets its own:
+- Bot token (the `default` account falls back to `DISCORD_BOT_TOKEN` env var)
+- Guild and channel allowlists
+- Session key namespace (session keys are account-aware: `agent:<agentId>:discord:<accountId>:channel:<channelId>`)
+
+Bindings reference accounts via `accountId`:
+```json
+{
+  "bindings": [
+    {
+      "agentId": "cos",
+      "match": {
+        "channel": "discord",
+        "accountId": "default",
+        "guildId": "<GUILD_ID>",
+        "peer": { "kind": "channel", "id": "<CHANNEL_ID_HQ>" }
+      }
+    }
+  ]
+}
+```
+
+**Known issue**: `requireMention: true` is reportedly broken in multi-account configurations (Issue [#45300](https://github.com/openclaw/openclaw/issues/45300)) -- all guild messages are dropped at the preflight stage with reason "no-mention" even when the bot is explicitly @mentioned.
+
+---
+
+## 2. Channel Permission Isolation
+
+### 2.1 Root Cause of Issue #34
+
+**Confidence: HIGH** (confirmed by reporter FRED-DL's own comment)
+
+Issue [#34](https://github.com/AlexAnys/opencrew/issues/34) ("routing bug, cos and ops conversations mixed together") was caused by the **single-bot configuration** where all agents share one Discord bot identity.
+
+The reporter's comment translates to: "The Discord plugin configuration requires each bot to only send in specific channels, so the documentation should not describe them as public channels but rather as manually restricted bot send permissions."
+
+The root cause chain:
+1. A single bot receives `MESSAGE_CREATE` events for **all** channels it has View Channel permission on
+2. OpenClaw's binding system routes messages by channel ID to the correct agent (e.g., #hq -> CoS, #ops -> Ops)
+3. However, when any agent responds, the **same bot identity** sends the message. If the bot has Send Messages permission in channels it should not be active in, or if bindings are misconfigured, responses can leak across channels
+4. Without explicit Discord permission overrides, the single bot can read and write in every channel, creating a surface for context mixing if the OpenClaw routing layer has any edge-case failures
+
+The fix documented in the issue: manually restrict the bot's Send Messages permission so it can only send in its assigned channel(s). With multi-bot, this becomes natural -- each bot only needs permissions in its own channel.
+
+### 2.2 Discord Permission Override Configuration
+
+**Confidence: HIGH** (based on Discord API documentation)
+
+Discord uses a layered permission system:
+
+1. **Server-level role permissions** (base)
+2. **Category-level permission overwrites** (inherited by child channels unless overridden)
+3. **Channel-level permission overwrites** (most specific, wins)
+4. **Member-specific overwrites** (highest priority, per-user/bot)
+
+Permission overwrites use an `allow`/`deny` bitfield model:
+- `allow` explicitly grants a permission at the channel level
+- `deny` explicitly revokes a permission at the channel level
+- Unset bits inherit from the parent level
+
+Key permission bits for bot isolation:
+
+| Permission | Bit | Hex Value |
+|---|---|---|
+| VIEW_CHANNEL | `1 << 10` | `0x0000000000000400` |
+| SEND_MESSAGES | `1 << 11` | `0x0000000000000800` |
+| SEND_MESSAGES_IN_THREADS | `1 << 38` | `0x0000004000000000` |
+| READ_MESSAGE_HISTORY | `1 << 16` | `0x0000000000010000` |
+
+**Critical note**: If a bot's role has the **Administrator** permission, all channel-level overrides are bypassed. Ensure bot roles do NOT have Administrator.
+
+### 2.3 Step-by-Step Isolation Setup
+
+**Confidence: HIGH** (testable in any Discord server)
+
+#### For single-bot setup (restrict one bot to specific channels):
+
+1. **Create a bot-specific role** (e.g., "OpenCrew Bot") -- do NOT use Administrator permission
+2. **At the server level**, grant the role: View Channels, Read Message History
+3. **At the server level**, do NOT grant: Send Messages, Send Messages in Threads
+4. **For each agent channel** (e.g., #hq, #cto, #build):
+   - Right-click the channel -> Edit Channel -> Permissions
+   - Click "+" next to Roles/Members, add the "OpenCrew Bot" role
+   - Set "Send Messages" to **Allow** (green checkmark)
+   - Set "Send Messages in Threads" to **Allow** (green checkmark)
+5. **Verify**: The bot can now only send messages in channels where you explicitly allowed it
+
+#### For multi-bot setup (each bot restricted to its own channel):
+
+1. **Create a role per bot** (e.g., "CoS Bot", "CTO Bot", "Builder Bot")
+2. **At the server level**, grant each role: View Channels, Read Message History -- do NOT grant Send Messages
+3. **For each bot**, add a channel-level overwrite on its designated channel:
+   - #hq: "CoS Bot" role -> Allow Send Messages, Allow Send Messages in Threads
+   - #cto: "CTO Bot" role -> Allow Send Messages, Allow Send Messages in Threads
+   - #build: "Builder Bot" role -> Allow Send Messages, Allow Send Messages in Threads
+4. **Optional hardening**: On channels a bot should NOT access at all, add a channel-level overwrite denying View Channel for that bot's role
+
+#### Programmatic approach (via Discord API):
+
+```
+PUT /channels/{channel_id}/permissions/{role_or_user_id}
+{
+  "allow": "2048",   // SEND_MESSAGES (1 << 11)
+  "deny": "0",
+  "type": 0          // 0 = role overwrite
+}
+```
+
+To deny Send Messages on a channel:
+```
+PUT /channels/{channel_id}/permissions/{role_or_user_id}
+{
+  "allow": "0",
+  "deny": "2048",    // SEND_MESSAGES denied
+  "type": 0
+}
+```
+
+---
+
+## 3. Thread Support
+
+### 3.1 Discord Thread Model
+
+**Confidence: HIGH** (based on Discord API documentation)
+
+Discord threads are lightweight sub-channels that live under a parent text channel. Key properties:
+
+- **Types**: Public threads (visible to anyone who can view the parent channel), Private threads (invite-only, or visible to those with Manage Threads permission)
+- **Auto-archive**: Threads automatically archive after a configurable period of inactivity: 1 hour, 24 hours, 3 days, or 7 days (higher values require server boost level). "Activity" means sending a message, unarchiving, or changing the auto-archive duration
+- **Archived threads**: Can still be viewed and searched, but no new messages can be added until unarchived. Locked threads can only be unarchived by users with Manage Threads permission
+- **Member limit**: Threads support up to 1,000 members
+- **Thread metadata**: Includes `archived`, `archive_timestamp`, `auto_archive_duration`, `locked`, `owner_id`, `parent_id`
+
+### 3.2 Bot Access to Threads
+
+**Confidence: HIGH**
+
+- Bots **must** use API v9 or above to receive thread-related gateway events (MESSAGE_CREATE, THREAD_CREATE, etc.)
+- Threads **inherit** all parent channel permissions. The relevant permission for posting in threads is `SEND_MESSAGES_IN_THREADS` (not `SEND_MESSAGES`)
+- Bots with View Channel on the parent automatically see public threads; private threads require membership or Manage Threads permission
+- The `THREAD_LIST_SYNC` event synchronizes active threads when a bot gains access to a channel
+
+**OpenClaw thread handling**: Discord threads are routed as channel sessions. Thread configuration inherits parent channel config unless a thread-specific entry exists. OpenClaw supports binding threads to specific agents or sessions via `/focus` and `/unfocus` commands. The OpenCrew config document confirms: "Discord threads automatically inherit the configuration of their parent channel (agent binding, requireMention, etc.) unless you configure a specific thread ID separately."
+
+### 3.3 Comparison with Slack Thread Behavior
+
+**Confidence: MEDIUM** (based on documented behavior, not direct testing)
+
+| Aspect | Slack | Discord |
+|---|---|---|
+| **Thread creation** | Any message can become a thread parent by replying to it | Threads are created explicitly from a message or via API; Forum channels auto-create threads |
+| **Persistence** | Threads persist indefinitely (searchable, no expiry) | Threads auto-archive after inactivity (1h to 7d) |
+| **Visibility** | Thread replies can optionally be broadcast to the channel | Thread messages stay in the thread only |
+| **Session key** | `agent:<agentId>:slack:channel:<channelId>:thread:<root_ts>` | `agent:<agentId>:discord:channel:<channelId>` (thread inherits parent; thread-specific session may append thread ID) |
+| **Bot trigger** | Bot-authored messages in other channels don't auto-trigger agents (same single-bot limitation) | Same behavior -- OpenClaw ignores bot-authored inbound by default |
+| **A2A pattern** | Two-step: Slack root message (anchor) + `sessions_send` (trigger) | Same two-step pattern applies to Discord |
+| **OpenClaw session isolation** | `historyScope = "thread"` + `inheritParent=false` isolates thread context | Thread config inherits parent channel unless overridden; `/focus` and `/unfocus` provide explicit binding |
+
+**Key difference**: Discord's auto-archive is the most significant operational difference. Slack threads never expire, so long-running tasks can span days without concern. Discord threads will auto-archive after inactivity, requiring either:
+- The bot to have Manage Threads permission to unarchive
+- A periodic "keep-alive" message (not recommended; adds noise)
+- Accepting that completed task threads will archive naturally (acceptable for most workflows)
+
+---
+
+## 4. Multi-Agent Collaboration Potential
+
+### 4.1 Multiple Bots in Same Thread
+
+**Confidence: HIGH** (Discord platform) / **MEDIUM** (OpenClaw implementation)
+
+At the Discord level, multiple bots can absolutely participate in the same thread with distinct identities -- each bot appears with its own name, avatar, and online status. Any bot with `SEND_MESSAGES_IN_THREADS` permission on the parent channel can post in threads under that channel. Each bot's messages are clearly attributed to its own identity.
+
+**OpenClaw limitation**: The bot-to-bot filtering issue (Issue #11199) means that even if Bot-A and Bot-B are both in the same thread, Bot-B's OpenClaw instance will drop Bot-A's messages as "own-bot" messages. This prevents a pattern where Bot-A mentions Bot-B in a thread to trigger a response.
+
+**Practical pattern today**: Agent-to-agent collaboration in a shared thread must use `sessions_send` internally. The Discord thread serves as a shared audit log where both agents post their outputs for human visibility, but the actual trigger mechanism is internal to OpenClaw.
+
+### 4.2 Discussion/Review/Brainstorm Patterns
+
+**Confidence: MEDIUM** (conceptual; not tested in production)
+
+With the current OpenClaw architecture, several collaboration patterns are achievable:
+
+**Pattern 1: Delegated Execution (works today)**
+- CTO posts a task root message in #build
+- CTO uses `sessions_send` to trigger Builder in that thread
+- Builder executes and posts results in the thread
+- CTO monitors the thread and posts checkpoint summaries in #cto
+- Both agents' messages appear in the #build thread with distinct identities (if multi-bot)
+
+**Pattern 2: Sequential Review (works today with orchestration)**
+- CoS creates a review request thread
+- CoS triggers CTO via `sessions_send` with the review brief
+- CTO posts analysis in the thread, then triggers Builder if implementation needed
+- Each agent's contribution is visible in the thread, attributed to its bot identity
+
+**Pattern 3: Multi-Agent Discussion (partially blocked)**
+- Requires multiple agents to read each other's thread messages and respond
+- Currently blocked by Issue #11199 (bot-to-bot filtering)
+- Workaround: An orchestrator agent uses `sessions_send` to relay context between agents, posting summaries in a shared thread
+- True "round-table" discussion where agents directly read and respond to each other's Discord messages is not yet supported
+
+**Pattern 4: Human-in-the-Loop Brainstorm (works today)**
+- Human posts a question in a channel
+- Bound agent responds
+- Human can @mention a different bot to bring another agent into the conversation (if multi-bot and `requireMention` is configured per-bot)
+- Each agent responds with its own identity
+
+### 4.3 Orchestration Options
+
+**Confidence: MEDIUM**
+
+Three orchestration approaches exist for multi-agent Discord collaboration:
+
+1. **OpenClaw A2A Protocol (recommended)**: Uses `sessions_send` for agent-to-agent triggering. Discord messages are "visibility anchors." This is the documented approach in OpenCrew's `A2A_PROTOCOL.md` and works with both single-bot and multi-bot configurations. It does not depend on Discord's message delivery for inter-agent communication.
+
+2. **Discord-native orchestration (blocked)**: Would rely on bots reading each other's Discord messages and responding. Currently blocked by Issue #11199. If/when fixed, this would enable more natural multi-agent threads where agents directly react to each other's messages. Requires `allowBots` configuration and careful loop prevention.
+
+3. **Hybrid orchestration**: Uses `sessions_send` for triggering but has agents post structured outputs in shared Discord threads. A "coordinator" agent (e.g., CTO) reads thread history via OpenClaw's message history and synthesizes responses. This works today and provides the best human visibility.
+
+---
+
+## 5. Confidence Assessment
+
+| Finding | Confidence | Basis |
+|---|---|---|
+| Multiple bots coexist in one Discord server | HIGH | Discord API docs, widespread practice |
+| Cross-bot MESSAGE_CREATE visibility | HIGH | Discord API v9+ documented behavior |
+| OpenClaw multi-account support shipped (PR #3672) | HIGH | Issue #3306 confirmation, official docs |
+| Bot-to-bot filtering bug (Issue #11199) | HIGH | Issue report with reproduction steps |
+| Channel permission override isolation method | HIGH | Discord API docs, testable |
+| Issue #34 root cause (single-bot + missing permission overrides) | HIGH | Reporter's own comment confirms |
+| Thread auto-archive behavior | HIGH | Discord API docs |
+| Thread permission inheritance from parent | HIGH | Discord API docs |
+| `requireMention` broken in multi-account (Issue #45300) | MEDIUM | Single issue report, not independently verified |
+| Multi-agent discussion pattern feasibility | MEDIUM | Conceptual; depends on #11199 resolution |
+| Session key format for Discord threads | MEDIUM | Partially documented; thread-specific key format not fully confirmed |
+
+---
+
+## 6. Open Questions
+
+1. **Issue #11199 fix status**: What is the merge status of PRs #11644, #22611, and #35479? If any are merged, bot-to-bot Discord messaging would be unblocked, enabling richer collaboration patterns.
+
+2. **`requireMention` in multi-account**: Issue #45300 reports this is broken. Is there a workaround or fix? This is important for noise reduction in multi-bot setups.
+
+3. **Thread session key format**: The exact session key format for Discord threads (as opposed to channels) needs confirmation. Does OpenClaw append a thread ID to the channel session key, or does it use the parent channel key?
+
+4. **Auto-archive impact on long tasks**: If an OpenCrew task thread auto-archives mid-execution (e.g., agent is processing a long task), does the agent's next message automatically unarchive the thread, or does it fail silently?
+
+5. **Rate limits with many bots**: With 7 agents each having their own bot, are there aggregate rate limit concerns at the guild level? Discord's per-guild rate limits may be stricter than per-bot limits for certain operations.
+
+6. **Webhook relay vs. multi-bot trade-offs**: The DISCORD_SETUP.md mentions webhook relay as a middle-ground option. Has anyone in the OpenCrew community tested this approach? Webhooks can send with custom names/avatars but cannot receive messages, which limits their utility for agent routing.
+
+7. **PR #3672 compatibility with current OpenClaw version**: The OpenCrew docs reference PR #3672 as "still in development," but Issue #3306 comments suggest it works. Which OpenClaw version is required for multi-account Discord support?
+
+---
+
+## Sources
+
+- [Discord Threads API Documentation](https://docs.discord.com/developers/topics/threads)
+- [Discord Permissions API Documentation](https://docs.discord.com/developers/topics/permissions)
+- [OpenClaw Discord Channel Documentation](https://docs.openclaw.ai/channels/discord)
+- [OpenClaw Multi-Agent Routing Documentation](https://docs.openclaw.ai/concepts/multi-agent)
+- [OpenClaw Issue #3306: Support multiple Discord accounts](https://github.com/openclaw/openclaw/issues/3306)
+- [OpenClaw Issue #11199: Multiple agent bots filtered when talking to each other](https://github.com/openclaw/openclaw/issues/11199)
+- [OpenClaw Issue #28479: Support Multiple Discord Bot Accounts](https://github.com/openclaw/openclaw/issues/28479)
+- [OpenClaw Issue #45300: requireMention broken in multi-account Discord config](https://github.com/openclaw/openclaw/issues/45300)
+- [OpenCrew Issue #34: Routing bug, cos and ops conversations mixed](https://github.com/AlexAnys/opencrew/issues/34)
+- [OpenCrew DISCORD_SETUP.md](../../docs/en/DISCORD_SETUP.md)
+- [OpenCrew CONFIG_SNIPPET_DISCORD.md](../../docs/en/CONFIG_SNIPPET_DISCORD.md)
+- [OpenCrew A2A_PROTOCOL.md](../../shared/A2A_PROTOCOL.md)
+- [OpenCrew KNOWN_ISSUES.md](../../docs/KNOWN_ISSUES.md)

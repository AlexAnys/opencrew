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

diff --git a/.harness/reports/research_feishu_r1.md b/.harness/reports/research_feishu_r1.md
new file mode 100644
index 0000000..548ab4c
--- /dev/null
+++ b/.harness/reports/research_feishu_r1.md
@@ -0,0 +1,400 @@
+# Research Report: Feishu Multi-Agent Capabilities (U1, Round 1)
+
+## Executive Summary
+
+The Feishu integration for OpenCrew is poised for a significant upgrade. Two independent developments converge to address the project's top limitations:
+
+1. **Per-topic session isolation** is now available via the built-in OpenClaw Feishu plugin's `groupSessionScope: "group_topic"` config (the official replacement for the legacy `topicSessionMode` / the `threadSession` shorthand referenced in Issue #31). This directly solves the P0 session-sharing problem -- each Feishu topic thread gets its own session key, enabling parallel tasks without context intermingling.
+
+2. **Multi-account (multi-bot) routing** is supported by both the built-in plugin and the community plugin, allowing each Agent to run as a distinct Feishu app with its own identity, API quota, and permissions. Combined with `accountId`-based bindings, messages route deterministically to the correct Agent.
+
+However, the A2A two-step trigger **cannot be reduced to one step** via cross-bot messaging alone. Feishu's `im.message.receive_v1` event only fires for user-sent messages; bot-sent messages are invisible to other bots' event subscriptions. The `sessions_send` internal routing mechanism remains necessary for cross-agent triggering.
+
+---
+
+## 1. threadSession Analysis
+
+### 1.1 What It Does
+
+**Confidence: HIGH** (backed by OpenClaw source code analysis via DeepWiki and PR #29791)
+
+The term `threadSession` as used in Issue #31 (`openclaw config set channels.feishu.threadSession true`) refers to enabling per-topic session isolation in Feishu group chats. At the code level, this maps to the `groupSessionScope` configuration in the built-in OpenClaw Feishu extension (`extensions/feishu/`).
+
+The built-in plugin supports four session scope modes, defined in `extensions/feishu/src/config-schema.ts`:
+
+| `groupSessionScope` value | Session key format | Behavior |
+|---|---|---|
+| `"group"` (default) | `chatId` | One session per group chat |
+| `"group_sender"` | `chatId:sender:senderOpenId` | One session per (group + sender) |
+| `"group_topic"` | `chatId:topic:topicId` | One session per topic thread; falls back to `chatId` if no topic |
+| `"group_topic_sender"` | `chatId:topic:topicId:sender:senderOpenId` | One session per (topic + sender); cascading fallback |
+
+The session key is constructed by the `buildFeishuConversationId` function (in `extensions/feishu/src/bot.ts` or related module):
+
+```typescript
+function buildFeishuConversationId(params: {
+  chatId: string;
+  scope: FeishuGroupSessionScope;
+  senderOpenId?: string;
+  topicId?: string;
+}): string {
+  switch (params.scope) {
+    case "group_topic":
+      return topicId ? `${chatId}:topic:${topicId}` : chatId;
+    case "group_topic_sender":
+      if (topicId && senderOpenId)
+        return `${chatId}:topic:${topicId}:sender:${senderOpenId}`;
+      if (topicId) return `${chatId}:topic:${topicId}`;
+      return senderOpenId ? `${chatId}:sender:${senderOpenId}` : chatId;
+    // ...
+  }
+}
+```
+
+The `topicId` is derived from the Feishu message event's `root_id` (preferred) or `thread_id` (fallback). This was implemented in PR #29791 (merged March 2, 2026), which resolved the long-standing feature request for thread-based replies in Feishu.
+
+**Historical note**: The deprecated `topicSessionMode: "enabled"` config is a legacy predecessor that maps internally to `groupSessionScope: "group_topic"`. The `threadSession = true` shorthand referenced in Issue #31 is likely another alias or community documentation shorthand for the same underlying mechanism. The canonical config key in current OpenClaw versions (2026.2+) is `groupSessionScope`.
+
+### 1.2 How It Solves Session Sharing
+
+**Confidence: HIGH**
+
+This directly addresses OpenCrew's P0 issue ("Slack channel root messages share one session -- context pollution"). With `groupSessionScope: "group_topic"`:
+
+- Each Feishu topic thread within a group gets a distinct session key (e.g., `oc_xxx:topic:om_root_123`)
+- Non-topic messages in the group mainline fall back to the group-level session (`oc_xxx`)
+- Different tasks running in different topics within the same group will have **fully isolated conversation context**
+- This mirrors the Slack model where "thread = task = session"
+
+**Practical impact for OpenCrew**: In the CTO group, multiple A2A tasks can now run in parallel as separate topics, each with its own session. No more context intermingling.
+
+### 1.3 Interaction with OpenCrew's Group Chat Model
+
+**Confidence: MEDIUM** (theoretical analysis, not tested)
+
+OpenCrew's model is "group chat = role" (each group is bound to one Agent). Adding topic-level session isolation is additive and non-breaking:
+
+- **Routing**: The Agent binding still matches on `chatId` (group level). The `groupSessionScope` only affects the session key, not routing. Messages in any topic within the CTO group still route to the CTO Agent.
+- **A2A visibility**: Task root messages posted as Feishu topic starters become natural "anchors" (equivalent to Slack root messages). All follow-up conversation stays within the topic.
+- **Session key for A2A**: When using `sessions_send`, the session key format changes from `agent:cto:feishu:group:oc_xxx` to `agent:cto:feishu:group:oc_xxx:topic:om_root_yyy`. Existing A2A protocol session key construction logic will need to account for the topic suffix.
+
+**Config to enable**:
+
+```json
+{
+  "channels": {
+    "feishu": {
+      "groupSessionScope": "group_topic"
+    }
+  }
+}
+```
+
+Or per-group override:
+
+```json
+{
+  "channels": {
+    "feishu": {
+      "groups": {
+        "oc_xxx": {
+          "groupSessionScope": "group_topic"
+        }
+      }
+    }
+  }
+}
+```
+
+---
+
+## 2. Multi-Account A2A Impact
+
+### 2.1 Cross-App Message Routing
+
+**Confidence: HIGH** (backed by OpenClaw source code and Feishu platform documentation)
+
+In multi-account mode, each Feishu app (bot) runs as a separate account under `channels.feishu.accounts`. Each account establishes its own WebSocket connection to Feishu Cloud using its own `appId`/`appSecret`. The `startFeishuProvider` function in the built-in plugin creates a separate provider per enabled account.
+
+When a user sends a message in a group where multiple bots are present, each bot receives an independent `im.message.receive_v1` event. OpenClaw handles this through cross-account broadcast deduplication:
+
+1. The first account to claim the `messageId` in a shared "broadcast" namespace processes the message
+2. Subsequent accounts skip dispatch for that message
+3. The `tryRecordMessagePersistent` function enforces first-claim-wins semantics
+
+With `accountId`-based bindings, the routing priority is:
+1. Exact `peer` match (specific group/DM ID)
+2. `parentPeer` match (thread inheritance)
+3. `accountId` match
+4. Channel-level fallback (`accountId: "*"`)
+5. Default agent fallback
+
+**Recommended setup**: In "one bot per group" mode, add only the corresponding bot to each group. This avoids deduplication contention entirely since only one bot receives events per group.
+
+### 2.2 Self-Loop Filter Bypass
+
+**Confidence: HIGH** (backed by Feishu platform documentation)
+
+**Critical finding**: The Feishu `im.message.receive_v1` event **only fires for user-sent messages**. The official Feishu documentation states:
+
+> "Currently only supports messages sent by users" (`sender_type: "user"`)
+> "In group scenarios, you receive all messages sent by users (not including messages sent by the bot)"
+
+This means:
+- When Bot-CTO posts a message in the Builder group, **Bot-Builder does NOT receive an `im.message.receive_v1` event**
+- This is a Feishu platform constraint, not an OpenClaw filter
+- The "self-loop filter bypass" question is moot -- there is nothing to bypass because bot messages simply do not generate inbound events for other bots
+
+**Implication**: Cross-bot messaging via Feishu API cannot trigger another Agent. The only way to trigger Agent-B from Agent-A remains `sessions_send` (OpenClaw's internal A2A mechanism).
+
+### 2.3 Implications for Two-Step Trigger
+
+**Confidence: HIGH**
+
+The current A2A two-step trigger cannot be simplified to one step via cross-bot messaging:
+
+| Step | Current (single-bot) | Multi-bot mode | Change? |
+|------|---------------------|----------------|---------|
+| Step 1: Post visible root message in target channel | Bot posts in target group | Bot-A posts in Bot-B's group | **Same** (visibility anchor) |
+| Step 2: `sessions_send` to trigger target agent | Required (bot self-messages are ignored) | **Still required** (Feishu does not deliver bot messages to other bots) | **No change** |
+
+However, multi-bot mode does provide these improvements:
+- **Visual clarity**: Each Agent's messages appear under a distinct bot name/avatar, making A2A exchanges easier to follow
+- **API quota independence**: Each bot has its own rate limits, preventing a chatty Agent from starving others
+- **Permission isolation**: Different Agents can have different Feishu permission scopes
+
+The `sessions_send` mechanism works via OpenClaw's `INTERNAL_MESSAGE_CHANNEL` with `deliver: false`, meaning it routes entirely within the OpenClaw runtime without touching Feishu APIs. This is efficient and reliable regardless of bot configuration.
+
+### 2.4 Config Examples
+
+Multi-account Feishu config with topic session isolation:
+
+```json
+{
+  "channels": {
+    "feishu": {
+      "domain": "feishu",
+      "connectionMode": "websocket",
+      "groupSessionScope": "group_topic",
+      "accounts": {
+        "cos-bot": {
+          "name": "CoS Chief of Staff",
+          "appId": "cli_cos_xxxxx",
+          "appSecret": "your-cos-secret",
+          "enabled": true
+        },
+        "cto-bot": {
+          "name": "CTO Tech Partner",
+          "appId": "cli_cto_xxxxx",
+          "appSecret": "your-cto-secret",
+          "enabled": true
+        },
+        "builder-bot": {
+          "name": "Builder Executor",
+          "appId": "cli_build_xxxxx",
+          "appSecret": "your-builder-secret",
+          "enabled": true
+        }
+      }
+    }
+  },
+  "bindings": [
+    {
+      "agentId": "cos",
+      "match": {
+        "channel": "feishu",
+        "accountId": "cos-bot",
+        "peer": { "kind": "group", "id": "<FEISHU_GROUP_ID_HQ>" }
+      }
+    },
+    {
+      "agentId": "cto",
+      "match": {
+        "channel": "feishu",
+        "accountId": "cto-bot",
+        "peer": { "kind": "group", "id": "<FEISHU_GROUP_ID_CTO>" }
+      }
+    },
+    {
+      "agentId": "builder",
+      "match": {
+        "channel": "feishu",
+        "accountId": "builder-bot",
+        "peer": { "kind": "group", "id": "<FEISHU_GROUP_ID_BUILD>" }
+      }
+    }
+  ]
+}
+```
+
+**Important caveat**: A known bug (Issue #47436) in OpenClaw 2026.3.13 causes the Feishu plugin to crash when a second account uses `SecretRef` for `appSecret`. A fix has been submitted in PR #47652 (wraps per-account errors in try-catch). Until this is merged, use plaintext secrets or wait for the patch.
+
+---
+
+## 3. Multi-Agent Collaboration Potential
+
+### 3.1 Multiple Bots in Same Group/Topic
+
+**Confidence: MEDIUM**
+
+Multiple Feishu bots CAN coexist in the same group. The behaviors:
+
+- **User messages**: All bots receive the event. OpenClaw's cross-account dedup ensures only one processes it (first-claim-wins). With `requireMention: true`, bots only respond when explicitly @mentioned, which is the cleanest pattern.
+- **Bot messages**: No bot receives events from other bots (Feishu platform limitation). Cross-bot conversation within a group is therefore not possible via Feishu events alone.
+- **Recommended pattern**: Each Agent's group should contain only its own bot. If multi-Agent collaboration is needed within a single group, use `sessions_send` for triggering and Feishu API messages for visibility only.
+
+### 3.2 Discussion Patterns in Feishu
+
+**Confidence: MEDIUM**
+
+With `groupSessionScope: "group_topic"`, Feishu topics enable a workflow analogous to Slack threads:
+
+1. **Task initiation**: Human or Agent creates a new topic in the Agent's group (this becomes the session root)
+2. **Execution**: Agent works within the topic, maintaining isolated context
+3. **A2A delegation**: Agent-A posts a topic in Agent-B's group (visibility anchor), then uses `sessions_send` to trigger Agent-B in that topic's session
+4. **Parallel tasks**: Multiple topics in the same group run independently
+
+The key difference from Slack: Feishu topics in standard groups are less prominent in the UI than Slack threads. Feishu "topic groups" (话题群) are a special group type where all messages must belong to a topic -- this would be the ideal group type for OpenCrew's use case, as it enforces topic-based organization.
+
+### 3.3 Comparison with Slack Capabilities
+
+| Capability | Slack | Feishu (with groupSessionScope) |
+|---|---|---|
+| Thread/topic isolation | Native (thread = session) | Now available via `group_topic` scope |
+| Bot self-loop filter | Bot ignores own messages (configurable) | Platform-level: bot events only for user messages |
+| Cross-bot triggering | Not possible (single bot identity) | Not possible (bot messages invisible to other bots) |
+| A2A trigger mechanism | `sessions_send` (required) | `sessions_send` (required) |
+| Visual identity | Single bot, shared name | Multi-bot, distinct names/avatars |
+| Thread UI prominence | High (native threading) | Medium (topic groups better than standard groups) |
+
+---
+
+## 4. Migration Path
+
+### 4.1 Single-App to Multi-App
+
+**Confidence: MEDIUM** (logical analysis, not tested end-to-end)
+
+Migration steps:
+
+1. **Create new Feishu apps** for each Agent (follow existing FEISHU_SETUP.md Steps 1-3 for each)
+2. **Update openclaw.json** to use `accounts` format instead of top-level `appId`/`appSecret`:
+
+   Before (single-app):
+   ```json
+   {
+     "channels": {
+       "feishu": {
+         "appId": "cli_original_xxx",
+         "appSecret": "original-secret"
+       }
+     }
+   }
+   ```
+
+   After (multi-app):
+   ```json
+   {
+     "channels": {
+       "feishu": {
+         "accounts": {
+           "legacy": {
+             "appId": "cli_original_xxx",
+             "appSecret": "original-secret",
+             "enabled": true
+           },
+           "cto-bot": {
+             "appId": "cli_cto_xxx",
+             "appSecret": "cto-secret",
+             "enabled": true
+           }
+         }
+       }
+     }
+   }
+   ```
+
+3. **Add `accountId` to bindings** incrementally -- start with one Agent, verify, then expand
+4. **Add each new bot to its group** in Feishu settings
+5. **Enable topic sessions** with `groupSessionScope: "group_topic"` (can be done independently of multi-app migration)
+
+### 4.2 Session Key Compatibility
+
+**Confidence: LOW** (requires testing)
+
+When migrating from single-app to multi-app, session keys may change format:
+
+- **Old format**: `agent:cto:feishu:group:oc_xxx` (no accountId component)
+- **New format**: Potentially `agent:cto:feishu:cto-bot:group:oc_xxx` (with accountId)
+
+If the session key changes, existing conversation history associated with old session keys becomes orphaned. The Agent starts with a fresh session in the new key.
+
+**Mitigation strategies**:
+- Keep the original app as the `legacy` account and migrate agents one at a time
+- Use `session.resetByType` to explicitly reset group sessions during migration (treat it as a clean-slate moment)
+- Back up `~/.openclaw/sessions/` before migration
+
+When adding `groupSessionScope: "group_topic"`:
+- Messages in the group mainline (no topic) continue using the base `chatId` key -- unchanged
+- Only messages within topics get the new `chatId:topic:topicId` key
+- This is backward-compatible: existing mainline sessions are unaffected
+
+### 4.3 Rollback Strategy
+
+1. **Config rollback**: Restore from backup (`openclaw.json.bak.<timestamp>`)
+2. **Bot rollback**: Remove new bots from groups; the original bot remains functional
+3. **Session rollback**: Session data for the old key format is preserved -- reverting config restores old routing
+4. **Gateway restart**: `openclaw gateway restart` applies all changes
+
+The migration is designed to be incremental and reversible at each step.
+
+---
+
+## 5. Confidence Assessment
+
+| Finding | Confidence | Source |
+|---|---|---|
+| `groupSessionScope: "group_topic"` creates per-topic sessions | **HIGH** | OpenClaw source code (`buildFeishuConversationId`), PR #29791, DeepWiki analysis |
+| `threadSession` is a shorthand/alias for topic session isolation | **MEDIUM** | Issue #31 comment + correlation with `topicSessionMode` legacy config; exact alias mechanism not found in source |
+| Feishu `im.message.receive_v1` only fires for user messages | **HIGH** | Official Feishu Open Platform documentation |
+| Bot-to-bot messages do NOT trigger other bots | **HIGH** | Feishu platform documentation: "sender_type currently only supports user" |
+| A2A two-step trigger cannot become one-step | **HIGH** | Combination of Feishu platform constraint + OpenClaw `sessions_send` architecture |
+| Multi-account config format with `accounts` block | **HIGH** | OpenClaw source code, config schema, DeepWiki analysis |
+| Cross-account dedup via broadcast namespace | **HIGH** | OpenClaw source code, test cases documented in DeepWiki |
+| Multi-account SecretRef crash bug (Issue #47436) | **HIGH** | GitHub issue with reproduction steps and submitted fix |
+| Session key format change during migration | **LOW** | Theoretical analysis; needs empirical testing |
+| `groupSessionScope` can be set per-group | **MEDIUM** | Config schema supports it; not tested in practice |
+
+---
+
+## 6. Open Questions
+
+1. **Exact `threadSession` config path**: The Issue #31 comment references `openclaw config set channels.feishu.threadSession true`, but the canonical config key found in OpenClaw source is `groupSessionScope`. Is `threadSession` a CLI shorthand that resolves to `groupSessionScope: "group_topic"`? Or is it specific to the community plugin (`AlexAnys/feishu-openclaw`)? This needs verification against the actual CLI behavior.
+
+2. **Session key migration**: When adding `accountId` to bindings, does the session key incorporate the accountId? If so, what happens to existing sessions? This needs empirical testing.
+
+3. **Topic group type**: Feishu distinguishes between standard groups (topics optional) and "topic groups" (话题群, topics mandatory). Which type works better with OpenCrew? Does `groupSessionScope` work identically in both?
+
+4. **Announce step behavior**: When Agent-A uses `sessions_send` to trigger Agent-B, the "announce step" posts a summary to the target channel. With multi-bot mode, which bot identity is used for the announce post -- Agent-B's bot (correct) or a shared bot? This affects visual clarity of A2A exchanges.
+
+5. **Rate limiting with many accounts**: Each Feishu app has independent API quotas. However, the health check ping interval (noted in `docs/api-quota-fix.md`) consumes API calls per account. With 7 agents = 7 apps, health check overhead may be significant. What is the optimal ping interval?
+
+6. **Community plugin vs built-in**: The `AlexAnys/feishu-openclaw` community plugin does NOT support `groupSessionScope` (it uses a simpler `chatId`-only session key with `threading.resolveReplyToMode: "off"`). OpenCrew's current setup guide references this community plugin. Is the project already using the built-in plugin (OpenClaw >= 2026.2), or does it need to migrate?
+
+7. **Cross-account broadcast in shared groups**: If a "shared collaboration group" with multiple bots is desired (e.g., a "war room"), how should the broadcast dedup be configured? Should one bot be designated as the "listener" with others set to `requireMention: true`?
+
+---
+
+## Sources
+
+- [OpenClaw Feishu documentation](https://docs.openclaw.ai/channels/feishu)
+- [OpenClaw GitHub - Feishu docs](https://github.com/openclaw/openclaw/blob/main/docs/channels/feishu.md)
+- [AlexAnys/openclaw-feishu (community plugin)](https://github.com/AlexAnys/openclaw-feishu)
+- [AlexAnys/feishu-openclaw (bridge)](https://github.com/AlexAnys/feishu-openclaw)
+- [Issue #29791: Thread-based replies in Feishu](https://github.com/openclaw/openclaw/issues/29791) -- closed, resolved via PR #29788
+- [Issue #8692: Multi-bot routing issues](https://github.com/openclaw/openclaw/issues/8692)
+- [Issue #47436: Multi-account SecretRef crash](https://github.com/openclaw/openclaw/issues/47436)
+- [Feishu Open Platform - Receive message event](https://open.feishu.cn/document/server-docs/im-v1/message/events/receive)
+- [DeepWiki - OpenClaw Session Management](https://deepwiki.com/openclaw/openclaw/2.4-session-management)
+- [DeepWiki - AlexAnys/openclaw-feishu](https://deepwiki.com/AlexAnys/openclaw-feishu)
+- [OpenCrew Issue #31: Feishu multi-agent bot routing](https://github.com/AlexAnys/opencrew/issues/31)

# QA Report: A2A Research Verification

**QA Agent**: Claude Opus 4.6 (1M context)
**Date**: 2026-03-27
**Scope**: Verify 6 critical claims from research reports against official docs and source evidence
**Method**: Web search, WebFetch of official docs, GitHub CLI issue/PR inspection

## Overall: NEEDS-WORK

Four of six claims verified or partially verified. Two claims have significant accuracy issues that could mislead implementation decisions. The Slack self-loop filter claim (Claim 1) has an important nuance the reports gloss over, and the Discord #11199 status (Claim 3) is stale -- the issue was auto-closed, not fixed.

---

## Claim 1: Slack multi-account enables true cross-bot communication

**Report says**: `allowBots: true` + `requireMention: true` + multi-account = Bot-A's messages visible to Bot-B. Self-loop filter is per-bot-user-ID, so multi-account naturally bypasses it.

### Verified: PARTIALLY

### Evidence

**What IS confirmed (HIGH confidence)**:

1. **Slack Events API delivers cross-bot messages**: Confirmed via [Slack message.channels event docs](https://docs.slack.dev/reference/events/message.channels/) and [Slack Events API docs](https://docs.slack.dev/apis/events-api/). All apps subscribed to `message.channels` receive events for all messages in channels they've joined, including messages from other bots.

2. **OpenClaw multi-account Slack support exists**: Confirmed via [OpenClaw Slack docs](https://docs.openclaw.ai/channels/slack) and [community gist](https://gist.github.com/rafaelquintanilha/9ca5ae6173cd0682026754cfefe26d3f). The `channels.slack.accounts` configuration with per-account `botToken`/`appToken` is documented.

3. **`allowBots` exists as a per-channel config**: Confirmed in official Slack docs as a per-channel control under `channels.slack.channels.<id>`.

4. **`requireMention: true` exists**: Confirmed. Official docs say "Channel messages are mention-gated by default."

5. **`initialHistoryLimit` exists and defaults to 20**: Confirmed. Official docs: "controls how many existing thread messages are fetched when a new thread session starts (default 20; set 0 to disable)."

6. **`thread.historyScope` defaults to `"thread"`**: Confirmed in official docs.

7. **`thread.inheritParent` defaults to `false`**: Confirmed in official docs.

**What is UNCERTAIN (MEDIUM confidence)**:

8. **Self-loop filter is per-bot-user-ID on Slack**: The report states this with HIGH confidence, but the evidence is indirect. Issue [#15836](https://github.com/openclaw/openclaw/issues/15836) shows the Slack filter code as `if (message.user === botUserId)`, which IS per-bot-user-ID. However, this issue was about single-bot mode. In multi-account mode, each account has its own `botUserId` fetched via `client.fetchUser("@me")`, so the filter SHOULD be per-account. But there is NO confirmed end-to-end test of multi-account Slack bot-to-bot communication in the evidence. The gist author's "verification checklist" describes human-mediated `@mention` workflows, not autonomous bot-to-bot. A user in the gist comments reported duplicate reply issues that required "deleted all slack apps and reset configs" to resolve.

9. **`allowBots: "mentions"` as a Slack value**: The report (Slack research, Section 1.2) lists three modes for `allowBots`: `false`, `true`, and `"mentions"`. The `"mentions"` value is confirmed for **Discord** via [OpenClaw configuration reference](https://github.com/openclaw/openclaw/blob/main/docs/gateway/configuration-reference.md): "use `allowBots: "mentions"` to only accept bot messages that mention the bot." However, the Slack docs do NOT document `allowBots: "mentions"` -- only `allowBots` appears as a listed per-channel control without value specification. The report itself rates this as MEDIUM confidence and notes it was found via "DeepWiki source-level documentation" -- but it may only be a Discord feature.

**What is UNVERIFIED**:

10. **End-to-end Slack multi-account cross-bot messaging**: No first-party evidence of a successful test where Bot-A posts a message, Bot-B's OpenClaw handler receives it via `allowBots: true`, and Bot-B responds. The community gist describes the setup pattern but does not demonstrate confirmed autonomous bot-to-bot message delivery. Issue #15836 (Slack agent-to-agent routing) was closed as NOT_PLANNED, and the two fix PRs (#15863, #15946) were CLOSED without merging.

### Issues

- **RISK**: The report presents Slack multi-account cross-bot communication as "technically feasible today" and "NOW" achievable, but no one has demonstrated it working end-to-end. The architecture report builds five collaboration patterns on this assumption.
- **INACCURACY**: `allowBots: "mentions"` may not exist for Slack. The report should use `allowBots: true` + `requireMention: true` as the recommended Slack config (which is what the config snippets actually show).
- **MISSING CAVEAT**: Issue #15836 was closed NOT_PLANNED, suggesting the OpenClaw maintainers may consider `sessions_send` the canonical A2A mechanism, with channel messages reserved for human-agent interaction only.

### Implementation Recommendation

Before implementing multi-account Discussion mode, the team MUST run a proof-of-concept test:
1. Create 2 Slack apps with separate tokens
2. Configure OpenClaw multi-account with `allowBots: true` + `requireMention: true`
3. Have Bot-A post a message @mentioning Bot-B in a shared channel
4. Verify Bot-B's OpenClaw session receives and responds to the message

---

## Claim 2: Feishu bot message invisibility

**Report says**: `im.message.receive_v1` only fires for user messages. Bot messages are invisible to other bots. This is a Feishu platform limitation.

### Verified: YES

### Evidence

**Feishu official documentation** at [open.feishu.cn/document/server-docs/im-v1/message/events/receive](https://open.feishu.cn/document/server-docs/im-v1/message/events/receive) explicitly states:

1. `sender_type` field: "目前只支持用户(user)发送的消息" -- **"Currently only supports messages sent by users"**

2. Group chat behavior: "可接收与机器人所在群聊会话中用户发送的所有消息（不包含机器人发送的消息）" -- **"Can receive all messages sent by users in group chats where the bot participates, excluding messages sent by the bot"**

This confirms the report's claim with direct official documentation. The limitation is at the Feishu platform level and cannot be worked around by any OpenClaw configuration.

### Issues

None. The report accurately characterizes this limitation and correctly concludes that `sessions_send` remains necessary for Feishu cross-agent triggering.

---

## Claim 3: Discord OpenClaw Issue #11199 blocks cross-bot messaging

**Report says**: OpenClaw's bot filter treats ALL configured bots as "self." Related fix PRs: #11644, #22611, #35479.

### Verified: PARTIALLY -- Status is STALE, not actively blocked

### Evidence

**Issue #11199 confirmed**: The [issue](https://github.com/openclaw/openclaw/issues/11199) exists and accurately describes the problem. The bug report includes detailed reproduction steps and code analysis showing the mention detection failure.

**However, the report's characterization is incomplete**:

1. **Issue was auto-closed on 2026-03-08** due to inactivity (stale bot), NOT because it was fixed. The closure message: "Closing due to inactivity. If this is still an issue, please retry on the latest OpenClaw release."

2. **All three fix PRs were CLOSED without merging**:
   - PR #11644 ("fix: bypass bot filter and mention gate for sibling Discord bots") -- CLOSED, not merged
   - PR #22611 ("fix(discord): allow messages from other instance bots in multi-account setups") -- CLOSED, not merged
   - PR #35479 ("fix(discord): add allowBotIds config to selectively allow bot messages") -- CLOSED, not merged

3. **A community workaround exists**: A [comment by @garibong-labs](https://github.com/openclaw/openclaw/issues/11199#issuecomment-3904716720) provides a working config using `allowBots: true` + `requireMention: false` + per-channel `users` whitelist. However, this requires disabling mention gating entirely.

4. **Additional blocker**: Issue [#45300](https://github.com/openclaw/openclaw/issues/45300) -- `requireMention: true` is broken in multi-account Discord config (still OPEN). This means even if #11199 were fixed, mention-gated bot-to-bot communication still would not work.

### Issues

- **STALE DATA**: The report says "status of these PRs could not be confirmed." I can confirm: all three PRs are CLOSED without merge. The issue itself is closed-as-stale, not closed-as-fixed.
- **WORKAROUND NOT MENTIONED**: The `requireMention: false` + `users` whitelist workaround exists and is confirmed working by multiple users, but the report does not mention it.
- **DOUBLE BLOCKER**: Even if #11199 is reopened and fixed, #45300 (`requireMention` broken in multi-account) is an independent blocker for the recommended `allowBots: true` + `requireMention: true` pattern.

### Implementation Recommendation

Discord Discussion mode should be classified as **BLOCKED (two independent issues)** rather than "BLOCKED (one issue)." The architecture report should document the `requireMention: false` workaround as an interim option with appropriate warnings about loop risk.

---

## Claim 4: groupSessionScope: "group_topic" creates per-topic sessions

### Verified: YES (previously verified in qa_docs_official_r1.md)

The previous QA round confirmed this against OpenClaw v2026.3.1 release notes. The version requirement was corrected from "2026.2" to "2026.3.1."

No contradicting information found in this verification round.

---

## Claim 5: A2A v2 Protocol design is backward compatible

**Report says**: Delegation (v1) + Discussion (v2) coexist. Single-bot users are unaffected. The `allowBots` + `requireMention` config on shared channels does not conflict with existing single-bot config.

### Verified: YES

### Evidence

1. **Current A2A_PROTOCOL.md** (`shared/A2A_PROTOCOL.md`) uses only Delegation mode: anchor message + `sessions_send`. It explicitly notes: "Slack 中所有 Agent 共用同一个 bot 身份" and "bot 自己发到别的频道的消息，默认不会触发对方 Agent 自动运行."

2. **v2 protocol design** adds Discussion mode as a NEW capability alongside Delegation. Key design decisions that preserve compatibility:
   - Agent-dedicated channels (e.g., #hq, #cto, #build) keep `allowBots: false` and `requireMention: false` -- identical to current behavior
   - Only the NEW `#collab` channel uses `allowBots: true` + `requireMention: true`
   - All Delegation workflows (two-step anchor + `sessions_send`) remain unchanged
   - Multi-account is additive: the `default` account can map to the existing single bot

3. **No config conflicts**: The v2 config snippets show dedicated channels retaining their current settings. The `accounts` block is an extension of the existing `channels.slack` structure, not a replacement.

4. **Permission matrix unchanged**: v2 adds "Discussion 中的 @mention 也必须遵守权限矩阵" as a supplement, not a modification.

### Issues

- **Minor**: The v2 protocol references `maxDiscussionTurns` as an AGENTS.md-level instruction, not a system config key. This should be clearly documented as a convention, not a config parameter, to avoid confusion.
- **Minor**: The v2 `thread.inheritParent: true` recommendation for shared channels differs from the current default of `false`. Implementers should be warned this changes behavior for ALL threads in configured channels, not just Discussion threads.

---

## Claim 6: Collaboration patterns are mechanically feasible

**Report says**: 5 patterns (Architecture Review, Strategic Alignment, Code Review, Incident Response, Knowledge Synthesis) work via @mention -> thread history loading -> response.

### Verified: PARTIALLY

### What is mechanically sound

1. **@mention triggers agent response**: With `requireMention: true`, a bot only processes messages where it is @mentioned. This is confirmed behavior in OpenClaw for both Slack and Discord.

2. **Thread history loading via `initialHistoryLimit`**: Confirmed. When an agent starts a new session in a thread, it loads the last N messages (default 20, configurable). This is the mechanism by which Agent-B would "see" Agent-A's earlier messages.

3. **`initialHistoryLimit` exists and is configurable**: Confirmed at `channels.slack.thread.initialHistoryLimit`. The architecture report's recommendations of 50-100 depending on pattern are reasonable.

4. **Visual identity**: With multi-account, each bot app has its own profile (name, avatar). Issue [#27080](https://github.com/openclaw/openclaw/issues/27080) (Slack agent identity fix) is CLOSED (resolved on 2026-03-01).

5. **Turn management via @mention**: The Level 1 (human-orchestrated) pattern is mechanically straightforward -- human @mentions agents in sequence, each agent loads thread history and responds.

### What is uncertain

6. **Agent generating @mentions**: Level 2 (agent-orchestrated) requires the orchestrator agent to produce `<@BOT_USER_ID>` in its messages. The report acknowledges this as an open question (#2 in Slack Open Questions): "When Agent-CTO posts '@Builder what do you think?', does OpenClaw's Slack plugin reliably detect this as a mention?" This is unverified.

7. **Bot-to-bot message delivery** (the foundation of all patterns): As noted in Claim 1, there is no confirmed end-to-end test of multi-account Slack bot-to-bot message delivery via `allowBots: true`. All five patterns depend on this working.

8. **Thread history completeness**: With `initialHistoryLimit: 50`, an agent joining a long discussion late will only see the last 50 messages. The architecture report addresses this with "context anchor" and "orchestrator summary" strategies, which is sound design but adds implementation complexity.

### Issues

- **CRITICAL DEPENDENCY**: All 5 patterns depend on Claim 1 (Slack multi-account cross-bot messaging) being true. If bot-to-bot message delivery fails in practice, all Discussion-mode patterns are blocked.
- **Level 2 feasibility uncertain**: Agent-generated @mentions have not been validated. If agents produce `@CTO` as plain text rather than `<@U123BOT>` in Slack's mention format, the mention will not be detected.
- **Pattern descriptions are thorough and well-designed**: The step-by-step mechanics, guard rails (maxDiscussionTurns, context anchors, escalation), and degradation strategies (Feishu/Discord fallback to Delegation chains) are architecturally sound regardless of implementation verification.

---

## Implementation Recommendations

### Must-Do Before Implementation

1. **RUN A PROOF OF CONCEPT**: Set up 2 Slack apps, configure multi-account OpenClaw with `allowBots: true` + `requireMention: true`, and verify bot-to-bot message delivery end-to-end. This is the single most important validation step. Everything else depends on this.

2. **Verify `allowBots: "mentions"` for Slack**: The config reference confirms this value exists for Discord. Confirm whether it also works for Slack, or if the Slack implementation only accepts `true`/`false`. If Slack does not support `"mentions"`, remove all references to it from Slack-specific documentation.

3. **Test agent-generated @mentions**: Have an agent produce a message containing `<@BOT_USER_ID>` and verify the receiving bot's OpenClaw instance recognizes it as a mention.

### Implementation Cautions

4. **Discord has TWO blockers, not one**: Issue #11199 (closed-stale, unfixed) AND Issue #45300 (`requireMention` broken in multi-account). Both must be resolved for Discussion mode on Discord.

5. **Feishu SecretRef crash (Issue #47436)**: Still OPEN. PR #47652 (fix) is OPEN but not merged. Use plaintext secrets for multi-account Feishu until this is resolved.

6. **`thread.inheritParent: true`**: The v2 config changes this from the default `false`. This affects all threads in configured channels, not just Discussion threads. Test for regressions in existing Delegation workflows.

7. **Issue #15836 closure**: The OpenClaw maintainers closed the Slack agent-to-agent routing issue as NOT_PLANNED, which may signal that channel-based A2A is not an officially supported pattern. The `sessions_send` approach should remain the primary A2A mechanism, with Discussion mode as an enhancement for Slack-capable deployments.

---

## Blocking Issues

1. **NO CONFIRMED END-TO-END TEST** of Slack multi-account bot-to-bot communication via `allowBots: true`. The entire Discussion mode architecture rests on this assumption. A proof-of-concept MUST succeed before any implementation work begins.

2. **Discord Discussion mode has two independent blockers** (Issues #11199 and #45300), both unresolved. Implementation for Discord should be deferred.

---

*Report generated: 2026-03-27*
*Verification method: WebSearch, WebFetch of official documentation (docs.openclaw.ai, open.feishu.cn, docs.slack.dev), GitHub CLI (gh issue view, gh pr view), OpenCrew repository inspection*

Sources:
- [OpenClaw Slack Documentation](https://docs.openclaw.ai/channels/slack)
- [OpenClaw Multi-Agent Routing](https://docs.openclaw.ai/concepts/multi-agent)
- [OpenClaw Configuration Reference](https://github.com/openclaw/openclaw/blob/main/docs/gateway/configuration-reference.md)
- [Feishu Receive Message Event](https://open.feishu.cn/document/server-docs/im-v1/message/events/receive)
- [Slack Events API](https://docs.slack.dev/apis/events-api/)
- [Slack message.channels Event](https://docs.slack.dev/reference/events/message.channels/)
- [Issue #11199: Discord bot-to-bot filter](https://github.com/openclaw/openclaw/issues/11199)
- [Issue #15836: Slack agent-to-agent routing](https://github.com/openclaw/openclaw/issues/15836)
- [Issue #45300: requireMention broken in multi-account Discord](https://github.com/openclaw/openclaw/issues/45300)
- [Issue #27080: Slack agent identity fix](https://github.com/openclaw/openclaw/issues/27080)
- [Issue #47436: Feishu SecretRef crash](https://github.com/openclaw/openclaw/issues/47436)
- [Community Gist: Multi-Agent Slack Setup](https://gist.github.com/rafaelquintanilha/9ca5ae6173cd0682026754cfefe26d3f)

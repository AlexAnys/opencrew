# Why Discord and Feishu Cannot Match Slack's Cross-Bot Collaboration

**Date**: 2026-03-27
**Purpose**: Definitive answer to why Slack supports cross-bot collaboration but Discord and Feishu do not.

---

## How Slack Works (the baseline)

Slack's architecture enables cross-bot collaboration through five properties working together:

1. **Independent bot identities**: Each agent gets its own Slack App with a unique bot user ID.
2. **Per-bot self-loop filter**: OpenClaw checks `message.user === ctx.botUserId` per-account. Bot-CTO (user ID `U_CTO`) is NOT filtered by Bot-Builder's handler (which only filters `U_BUILDER`).
3. **`allowBots: true`**: Enables processing messages authored by other bots.
4. **Per-account channel config**: Each account can have different `requireMention` settings, preventing uncontrolled loops while allowing targeted @mention-based triggering.
5. **Platform-level event delivery**: Slack's Events API delivers all channel messages to all subscribed apps, including messages from other bots.

The result: Bot-CTO can @mention Bot-Builder in a thread, Bot-Builder's OpenClaw handler receives it as a legitimate inbound message, processes it, and responds -- all visible to humans as a natural conversation between distinct identities.

---

## Discord: Blocked by TWO OpenClaw Code Bugs

### The blocker is NOT a Discord platform limitation.

Discord's platform fully supports cross-bot messaging. When Bot-A posts in a channel, Bot-B receives the `MESSAGE_CREATE` gateway event (provided Bot-B has View Channel permission and Message Content Intent enabled). The `message.author.bot` flag identifies it as a bot message. This is identical to Slack's behavior.

### Bug 1: Issue #11199 -- Bot filter treats all configured bots as "self"

**What happens at the code level**: OpenClaw's Discord plugin checks the message author ID against ALL configured bot account IDs in the instance, not just the receiving account's own ID. When Bot-A posts a message, Bot-B's handler sees Bot-A's user ID in its "known bot IDs" list and drops the message as if it were a self-loop.

**Contrast with Slack**: The Slack plugin checks `message.user === ctx.botUserId` where `ctx.botUserId` is the specific bot user ID of THAT account. Different accounts have different `botUserId` values, so cross-bot messages pass through. The Discord plugin lacks this per-account scoping.

**Fix status**: Three PRs were submitted to fix this (#11644, #22611, #35479). All three were CLOSED without merging. The issue itself was auto-closed on 2026-03-08 by a stale bot due to inactivity -- it was NOT fixed.

**Workaround**: A community workaround exists: set `allowBots: true` + `requireMention: false` + per-channel `users` whitelist. This works but requires disabling mention gating entirely, which removes the primary loop-prevention mechanism.

### Bug 2: Issue #45300 -- `requireMention` broken in multi-account Discord

**What happens**: When multiple Discord bot accounts are configured, the `requireMention: true` check drops ALL guild messages at the preflight stage with reason "no-mention" -- even when the bot IS explicitly @mentioned. The mention detection logic fails to correctly resolve mentions against the receiving bot's user ID in multi-account configurations.

**Why this matters**: Even if #11199 were fixed, the recommended safe pattern (`allowBots: true` + `requireMention: true`) would still not work. Without `requireMention`, every bot message in the channel triggers every other bot, creating infinite loops.

**Status**: Issue is still OPEN. No fix PR identified.

### What would need to change

1. Fix the self-loop filter to be per-account (check author ID against only the receiving account's bot user ID, not all configured bot IDs).
2. Fix mention detection in multi-account mode to correctly identify @mentions of the receiving bot.
3. Both fixes are straightforward code changes -- they align Discord's behavior with Slack's existing implementation.

### Timeline

**Uncertain.** All three fix PRs for #11199 were closed without merge, and the issue was auto-closed as stale. The OpenClaw maintainers have not signaled intent to prioritize this. Given that `sessions_send` (internal A2A routing) is the officially recommended pattern, channel-based cross-bot communication may not be considered a priority.

---

## Feishu: Blocked by a Platform-Level API Limitation

### The blocker IS a Feishu platform limitation. It cannot be fixed by OpenClaw.

### The technical constraint

Feishu's `im.message.receive_v1` event -- the only event type for receiving chat messages -- explicitly delivers ONLY user-sent messages. The official documentation states:

> "目前只支持用户(user)发送的消息"
> ("Currently only supports messages sent by users")

> "可接收与机器人所在群聊会话中用户发送的所有消息（不包含机器人发送的消息）"
> ("Can receive all messages sent by users in group chats where the bot participates, excluding messages sent by the bot")

When Bot-CTO posts a message in a group, Bot-Builder does NOT receive any event. The message is simply invisible to other bots at the API level. There is no `allowBots` flag or configuration that can change this -- the events are never generated by Feishu's servers.

### Are there alternative APIs?

No viable alternative exists:

- **`im.message.receive_v1`** is the only message reception event. There is no `im.message.receive_bot_v1` or equivalent.
- **Message list API** (`GET /im/v1/messages`): Could theoretically poll for messages, but this is a REST endpoint, not a real-time event. Polling introduces latency, complexity, and API quota consumption. It also cannot distinguish which messages have already been processed.
- **Feishu's event system** has no event type for "bot message posted in group." The platform was designed with a user-to-bot interaction model, not a bot-to-bot model.
- Searching for alternative approaches (e.g., "飞书 机器人消息 其他机器人接收") confirms this is a well-known and accepted limitation of the Feishu platform with no documented workaround.

### What would need to change

Feishu (ByteDance/Lark) would need to add a new event type or extend `im.message.receive_v1` to include bot-sent messages with an opt-in flag. There is no public indication this is planned.

---

## Summary Table

| Dimension | Slack | Discord | Feishu |
|-----------|-------|---------|--------|
| Platform delivers cross-bot messages? | YES | YES | **NO** |
| OpenClaw processes cross-bot messages? | YES (per-account self-loop filter) | **NO** (global bot filter bug #11199) | N/A (no events to process) |
| Mention gating works in multi-account? | YES | **NO** (broken, #45300) | N/A |
| Blocker type | None | **Code bugs** (fixable) | **Platform limitation** (unfixable by us) |
| Fix complexity | N/A | Low (align with Slack's implementation) | Requires Feishu platform change |
| Fix timeline | N/A | Uncertain (PRs closed, issue stale) | No indication from Feishu |
| Current workaround | N/A | `allowBots: true` + `requireMention: false` + `users` whitelist (loop risk) | `sessions_send` only |

### The bottom line

- **Discord** could work exactly like Slack if two code bugs in OpenClaw were fixed. The Discord platform itself is fully capable. The fixes are straightforward but have not been prioritized by OpenClaw maintainers.
- **Feishu** cannot work like Slack regardless of any code changes. The limitation is baked into Feishu's event delivery architecture. Only `sessions_send` (OpenClaw's internal routing) can achieve cross-agent triggering on Feishu.
- **Both platforms** fully support the Delegation pattern (anchor message + `sessions_send`). Only the Discussion pattern (autonomous cross-bot conversation visible in chat) is blocked.

---

*Sources: OpenClaw Issues #11199, #45300, #15836; PRs #11644, #22611, #35479; Feishu Open Platform docs (open.feishu.cn); OpenClaw source code verification (verify_source_code_r1.md); QA verification (qa_a2a_research_r1.md)*

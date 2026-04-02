# Source Code Verification: Cross-Bot Message Routing

**Repo**: `openclaw/openclaw` (GitHub, accessed 2026-03-27)
**Method**: Direct source code reads via `gh api` against the `openclaw/openclaw` repository.

---

## 1. allowBots Filter

### Source Files
- **Config type definition**: `src/config/types.slack.ts` (lines 41, 115)
- **Channel-level config resolution**: `extensions/slack/src/monitor/channel-config.ts`
- **Actual filter logic**: `extensions/slack/src/monitor/message-handler/prepare.ts`

### Code Snippet (from `prepare.ts`, `resolveSlackConversationContext`)

```typescript
const allowBots =
  channelConfig?.allowBots ??
  account.config?.allowBots ??
  cfg.channels?.slack?.allowBots ??
  false;
```

### Behavior

The `allowBots` flag is resolved with a **three-tier fallback**:

1. **Per-channel config** (`channels.slack.channels.<channelId>.allowBots`) -- highest priority
2. **Per-account config** (`channels.slack.accounts.<accountId>.allowBots`) -- middle priority
3. **Global Slack config** (`channels.slack.allowBots`) -- lowest priority
4. **Default**: `false`

When `allowBots` is `false` (the default), all messages with a `bot_id` field are silently dropped. The check occurs in `authorizeSlackInboundMessage`:

```typescript
if (isBotMessage) {
  if (message.user && ctx.botUserId && message.user === ctx.botUserId) {
    return null;  // self-loop filter (always blocks own messages)
  }
  if (!allowBots) {
    logVerbose(`slack: drop bot message ${message.bot_id ?? "unknown"} (allowBots=false)`);
    return null;
  }
}
```

---

## 2. Self-Loop Filter

### Source File
- `extensions/slack/src/monitor/message-handler/prepare.ts`, function `authorizeSlackInboundMessage`

### Code Snippet

```typescript
if (isBotMessage) {
  if (message.user && ctx.botUserId && message.user === ctx.botUserId) {
    return null;
  }
  if (!allowBots) {
    logVerbose(`slack: drop bot message ${message.bot_id ?? "unknown"} (allowBots=false)`);
    return null;
  }
}
```

Where `isBotMessage` is defined as:

```typescript
isBotMessage: Boolean(message.bot_id),
```

And `ctx.botUserId` is set per-account from `auth.test`:

```typescript
const auth = await app.client.auth.test({ token: botToken });
botUserId = auth.user_id ?? "";
```

### Per-Account or Global?

**Per-account.** Each Slack account (`monitorSlackProvider`) creates its own `SlackMonitorContext` with its own `botUserId`. The self-loop check compares `message.user === ctx.botUserId`, which is the bot user ID **of that specific Slack App/account**.

This means:
- **Default-Bot** (account `default`, botUserId = `U_DEFAULT`) will only drop messages where `message.user === "U_DEFAULT"`
- **CoS-Bot** (account `cos`, botUserId = `U_COS`) will only drop messages where `message.user === "U_COS"`

When CoS-Bot posts a message, Default-Bot's self-loop check (`message.user === U_COS`) does NOT match `U_DEFAULT`, so it passes through (assuming `allowBots=true`).

---

## 3. Multi-Account Event Dispatch

### Source Files
- **Gateway orchestration**: `src/gateway/server-channels.ts`
- **Per-account provider boot**: `extensions/slack/src/monitor/provider.ts`
- **Channel plugin gateway hook**: `extensions/slack/src/channel.ts` (`gateway.startAccount`)
- **Event registration**: `extensions/slack/src/monitor/events/messages.ts`

### How Events Are Routed

Each Slack account gets **its own independent Bolt `App` instance** with its own socket connection or HTTP receiver:

From `provider.ts`:
```typescript
const app = new App(
  slackMode === "socket"
    ? { token: botToken, appToken, socketMode: true, clientOptions }
    : { token: botToken, receiver: receiver ?? undefined, clientOptions },
);
```

From `channel.ts` (`gateway.startAccount`):
```typescript
startAccount: async (ctx) => {
  const account = ctx.account;
  const botToken = account.botToken?.trim();
  const appToken = account.appToken?.trim();
  ctx.log?.info(`[${account.accountId}] starting provider`);
  return getSlackRuntime().channel.slack.monitorSlackProvider({
    botToken: botToken ?? "",
    appToken: appToken ?? "",
    accountId: account.accountId,
    config: ctx.cfg,
    // ...
  });
},
```

From `server-channels.ts` (`startChannelInternal`):
```typescript
const accountIds = accountId ? [accountId] : plugin.config.listAccountIds(cfg);
// ...
await Promise.all(
  accountIds.map(async (id) => {
    // each account gets its own startAccount call
  }),
);
```

**Each account runs a completely separate Slack Bolt App** with its own WebSocket connection to Slack. Events from Slack are delivered directly to the Bolt App that owns that bot token.

### Critical Architectural Point: No Cross-Account Event Delivery

Unlike Feishu (where all bots in a group receive every message from every member, including other bots), **Slack delivers events only to the App that owns the relevant subscription**. Each Slack App gets its own events stream.

### Event Isolation via `shouldDropMismatchedSlackEvent`

Each account's context also includes `shouldDropMismatchedSlackEvent`, which checks `api_app_id` and `team_id`:

```typescript
const shouldDropMismatchedSlackEvent = (body: unknown) => {
  // ...
  if (params.apiAppId && incomingApiAppId && incomingApiAppId !== params.apiAppId) {
    logVerbose(`slack: drop event with api_app_id=${incomingApiAppId} (expected ${params.apiAppId})`);
    return true;
  }
  if (params.teamId && incomingTeamId && incomingTeamId !== params.teamId) {
    logVerbose(`slack: drop event with team_id=${incomingTeamId} (expected ${params.teamId})`);
    return true;
  }
  return false;
};
```

This is a safety net for HTTP mode where requests might be shared, but in socket mode each App has its own connection so this rarely fires.

### Dedup Behavior

**Slack has NO cross-account broadcast deduplication** like Feishu does. The reason is architectural:

- **Feishu**: All bots in a group receive the same event via a shared webhook. Feishu explicitly deduplicates with `tryRecordMessagePersistent(ctx.messageId, "broadcast")` using a shared namespace.
- **Slack**: Each bot App has its own event subscription stream. There is no shared event delivery mechanism, so no cross-account dedup is needed.

Within a single account, there is a `markMessageSeen` dedup to handle the `message` vs `app_mention` race:

```typescript
const seenMessages = createDedupeCache({ ttlMs: 60_000, maxSize: 500 });
const markMessageSeen = (channelId: string | undefined, ts?: string) => {
  if (!channelId || !ts) { return false; }
  return seenMessages.check(`${channelId}:${ts}`);
};
```

This dedup is **per-account** (each `SlackMonitorContext` has its own `seenMessages` cache). It exists to prevent the same message from being processed twice within ONE account (e.g., when both `message` and `app_mention` events fire for the same message).

There is also a global `inbound-dedupe.ts` that runs at the agent dispatch layer (`shouldSkipDuplicateInbound`), but its key includes `AccountId`:

```typescript
return [provider, accountId, sessionScope, peerId, threadId, messageId].filter(Boolean).join("|");
```

Since `accountId` is part of the key, the same physical message delivered to two different accounts generates **different dedup keys** and is processed independently by both.

---

## 4. Binding Resolution with Two Bots in Same Channel

### Source File
- `src/routing/resolve-route.ts`

### How It Works

When a message arrives at a specific account, `resolveAgentRoute` is called with:
```typescript
const route = resolveAgentRoute({
  cfg: ctx.cfg,
  channel: "slack",
  accountId: account.accountId,  // <-- per-account
  teamId: ctx.teamId || undefined,
  peer: {
    kind: isDirectMessage ? "direct" : isRoom ? "channel" : "group",
    id: isDirectMessage ? (message.user ?? "unknown") : message.channel,
  },
});
```

The binding resolution uses a tiered priority system:
1. `binding.peer` -- exact channel/peer match
2. `binding.peer.parent` -- parent thread match
3. `binding.guild+roles` -- Discord-specific
4. `binding.guild` -- Discord-specific
5. `binding.team` -- team-level binding
6. `binding.account` -- account-level binding
7. `binding.channel` -- channel-level (wildcard account) binding
8. `default` -- uses `resolveDefaultAgentId(cfg)`

Bindings are filtered by both `channel` AND `accountId`:

```typescript
function getEvaluatedBindingsForChannelAccount(
  cfg: OpenClawConfig,
  channel: string,
  accountId: string,
): EvaluatedBinding[] {
```

### Which Binding Wins?

Each account resolves its **own** route independently. There is no conflict because:

- Default-Bot (account `default`) + binding `{match: {channel: "slack", accountId: "default", peer: {kind: "channel", id: "C_CTO"}}, agentId: "cto"}` resolves to agent `cto`
- CoS-Bot (account `cos`) + binding `{match: {channel: "slack", accountId: "cos"}, agentId: "cos"}` resolves to agent `cos`

The two accounts process events in parallel; each resolves its own agentId based on its own bindings.

---

## 5. requireMention Scope

### Source Files
- `extensions/slack/src/monitor/channel-config.ts`
- `extensions/slack/src/monitor/message-handler/prepare.ts`

### Code Snippet

```typescript
const shouldRequireMention = isRoom
  ? (channelConfig?.requireMention ?? ctx.defaultRequireMention)
  : false;
```

Where `channelConfig` is resolved per-channel:
```typescript
const channelConfig = isRoom
  ? resolveSlackChannelConfig({
      channelId: message.channel,
      channelName,
      channels: ctx.channelsConfig,
      channelKeys: ctx.channelsConfigKeys,
      defaultRequireMention: ctx.defaultRequireMention,
      allowNameMatching: ctx.allowNameMatching,
    })
  : null;
```

And `ctx.channelsConfig` comes from the **per-account merged config**:

```typescript
channelsConfig: slackCfg.channels,
```

Where `slackCfg = account.config` (merged from account-specific + global config).

### Per-Account or Global?

**Per-account.** Each account's `SlackMonitorContext` has its own `channelsConfig` and `defaultRequireMention` derived from its merged config. However, the channel config entries themselves (`channels.slack.channels.*`) are typically shared globally in the config file unless explicitly overridden in `channels.slack.accounts.<id>.channels.*`.

In practice:
- If `channels.slack.channels.C_CTO.requireMention: true` is set globally, **both** Default-Bot and CoS-Bot accounts will see the same `requireMention: true` for channel `C_CTO`
- To give CoS-Bot different mention requirements, you would need `channels.slack.accounts.cos.channels.C_CTO.requireMention: false` (if supported by the merge logic in `resolveMergedAccountConfig`)

The `mergeSlackAccountConfig` function in `accounts.ts` does merge account-level config over global:

```typescript
return resolveMergedAccountConfig<SlackAccountConfig>({
  channelConfig: cfg.channels?.slack as SlackAccountConfig | undefined,
  accounts: cfg.channels?.slack?.accounts as Record<string, Partial<SlackAccountConfig>> | undefined,
  accountId,
});
```

So **per-account channel config overrides are supported** via the `accounts.<id>.channels` namespace.

---

## 6. Verdict

**Can CoS-Bot and CTO (via Default-Bot) have a conversation in #cto?**

### PARTIALLY -- with important caveats

### Evidence For (YES, it can work):

1. **Self-loop filter is per-account**: Each account only filters out messages from its own `botUserId`. CoS-Bot's messages won't be filtered by Default-Bot's self-loop check, and vice versa.

2. **allowBots enables cross-bot reception**: Setting `allowBots: true` on the `#cto` channel config (or per-account) will allow each bot to receive messages from the other bot.

3. **Bindings route correctly**: Account-scoped bindings ensure Default-Bot's events route to the CTO agent and CoS-Bot's events route to the CoS agent.

4. **No cross-account dedup**: Unlike Feishu, Slack accounts have fully independent event streams. Both accounts will process events independently without interfering with each other.

5. **Independent Bolt Apps**: Each account runs its own Slack Bolt App with its own WebSocket connection, so there's no event contention.

### Evidence For Caveats (PARTIALLY):

1. **Both bots see ALL messages in #cto**: When a human user posts in #cto, BOTH Default-Bot and CoS-Bot receive the event independently (from their own Slack event streams). This means both CTO agent AND CoS agent will process the message and potentially respond, unless properly gated. The inbound dedup at `inbound-dedupe.ts` includes `accountId` in its key, so the same physical message will NOT be deduped across accounts.

2. **requireMention is the primary gating mechanism**: To prevent both agents from responding to every message, `requireMention` must be configured. But if CoS-Bot specifically @mentions Default-Bot's agent name, that mention is resolved by Default-Bot's context using its own `botUserId` and `mentionRegexes`. The cross-bot mention resolution works correctly because `explicitlyMentioned` checks `message.text?.includes(<@${ctx.botUserId}>)` using each account's own bot user ID.

3. **Infinite loop risk**: If `allowBots: true` is set and `requireMention` is not configured, the CTO agent responding will trigger CoS agent to respond (because CoS-Bot sees the CTO agent's reply as a bot message in #cto), and vice versa. The code has NO built-in loop-breaker beyond requireMention and behavioral instructions. The docs explicitly warn: "if you allow replying to other bots (allowBots=true), use requireMention, users allowlist, and/or explicit guardrails in AGENTS.md and SOUL.md to prevent bot reply loops."

4. **Thread behavior**: When CoS-Bot posts in #cto, and CTO agent replies (via Default-Bot), the reply goes to the channel or thread. If CTO agent responds in-thread, CoS-Bot will receive the thread reply event, and the thread participation check (`hasSlackThreadParticipation`) means CoS agent may get an **implicit mention** for subsequent thread messages, bypassing `requireMention`.

5. **Session isolation**: Each agent's conversation is tracked in separate sessions (because `accountId` and `agentId` differ). This means neither agent sees the other's conversation history natively -- they only see the raw Slack messages. Cross-agent context must be inferred from the Slack message text.

### Required Configuration for the Claimed Scenario:

```yaml
channels:
  slack:
    accounts:
      default:
        botToken: xoxb-DEFAULT-BOT-TOKEN
        appToken: xapp-DEFAULT-APP-TOKEN
        channels:
          C_CTO:
            allowBots: true       # Required: accept messages from CoS-Bot
            requireMention: true  # Recommended: prevent responding to everything
      cos:
        botToken: xoxb-COS-BOT-TOKEN
        appToken: xapp-COS-APP-TOKEN
        channels:
          C_CTO:
            allowBots: true       # Required: accept messages from Default-Bot
            requireMention: true  # Recommended: prevent responding to everything

bindings:
  - match: { channel: slack, accountId: default, peer: { kind: channel, id: C_CTO } }
    agentId: cto
  - match: { channel: slack, accountId: cos }
    agentId: cos
```

### Summary

The original claim is **technically accurate** -- the code supports it -- but the claim omits critical operational details:

| Claim | Verified? | Notes |
|-------|-----------|-------|
| "CoS-Bot posts in #cto, CTO agent receives it" | YES | Requires `allowBots: true` on Default-Bot's channel config |
| "CTO responds, CoS agent sees the response" | YES | Requires `allowBots: true` on CoS-Bot's channel config |
| "They can have a back-and-forth conversation" | PARTIALLY | Works but requires careful loop prevention; no built-in cross-bot conversation termination |

---

## 7. What I Could NOT Find

1. **Explicit cross-account dedup for Slack**: I confirmed Feishu has `tryRecordMessagePersistent(ctx.messageId, "broadcast")` for cross-account dedup. Slack has NO equivalent. I could not find any code that deduplicates the same physical human message across two Slack accounts. This means when a human posts in #cto, both CTO agent and CoS agent WILL process it independently.

2. **Loop detection/circuit-breaker**: I found no automatic bot-to-bot loop detection beyond the self-loop filter. The protection is entirely behavioral (requireMention + AGENTS.md guardrails).

3. **Thread participation cross-account behavior**: I found `hasSlackThreadParticipation` which tracks sent messages per `accountId + channel + threadTs`, but I could not find whether this tracking affects the OTHER account's implicit mention resolution. Each account has its own `sent-thread-cache`, so if Default-Bot posts in a thread, CoS-Bot's `hasSlackThreadParticipation` for that thread would be `false` (unless CoS-Bot has also posted there). This means **implicit mention via thread participation does NOT cross account boundaries**, which is good for loop prevention but means CoS agent won't automatically follow thread conversations started by CTO agent unless explicitly @mentioned.

4. **`resolveMergedAccountConfig` deep merge behavior**: I read the function signature but did not retrieve its full implementation to confirm whether nested `channels.*` config in `accounts.<id>` truly deep-merges or shallow-replaces. The merge behavior affects whether per-account channel config overrides work as expected.

5. **Rate limiting or throttling between bot accounts**: I found no evidence of cross-account rate limiting that would prevent rapid back-and-forth between two bots.
